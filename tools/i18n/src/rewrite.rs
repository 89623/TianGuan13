//! DM 调用点改写（阶段2，v2：纯字符串 + 内插字符串，统一 LANG）。
//!
//! 把汇聚点调用里「恰好含一个可翻译文本节点」的消息参数原地改写为：
//!   - 无内插：`LANG("key", null)`
//!   - 有内插：`LANG("key", list(<内插表达式源码>...))`
//! key 与抽取阶段一致（同一文本节点 → 同一 namespace+模板内容哈希），故目录已含该 key。
//!
//! 定位与切片：用 AST 文本节点的 Location（指向源码里的开引号——宏展开后 token 位置仍保留）
//! 定位字符串字面量，再用 DM 源码扫描器切出整段字面量与各 `[...]` 内插表达式源码。
//!
//! 统一用全服 locale 的 `LANG`（单语言服与按人 locale 等价，免去切出接收者源码）；定向
//! 的 `LANGU(接收者, …)` 留作手工/后续。
//!
//! 安全约束（面向 CI 自动化，杜绝源码损坏）：
//!   - 仅当消息参数里「可翻译文本节点」恰好 1 个时改写（拼接多段文本一律跳过）；
//!   - 断言 Location 处确为 `"`，否则跳过；字符串扫描不平衡/未闭合则跳过；
//!   - 源码切出的内插数必须与 AST 模板占位符数一致，否则跳过；
//!   - 幂等：已是 LANG(...) 的参数不是字符串字面量，不会被再次改写。

use anyhow::{Context as _, Result};
use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};

use dm::ast::{AssignOp, BinaryOp, Expression, Follow, Spanned, Statement, Term};

use crate::dm_string::{
    find_first_quote, find_open_paren, in_preprocessor_directive, line_col_to_byte,
    logical_line_end, scan_dm_string, split_call_args,
};
use crate::template::{build_template, placeholder_count, strip_tags};
use crate::keys::{make_key, namespace_for};

/// 核心文件（非 modular_nova）被 codemod 改写时插入的文件级 NOVA EDIT 标记。
const CORE_MARKER: &str =
    "// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md";

/// 汇聚点 proc 名 -> 消息参数下标（与 extract.rs 保持一致）。
fn sink_message_args(name: &str) -> Option<&'static [usize]> {
    match name {
        "to_chat" => Some(&[1]),
        "balloon_alert" => Some(&[1]),
        "visible_message" => Some(&[0, 1, 2]), // [2]=blind_message（盲人可见）。
        "audible_message" => Some(&[0, 1, 3]),
        "say" => Some(&[0]),
        "manual_emote" => Some(&[0]),
        // 提示/对话框（玩家可见）。只取消息+标题；按钮/选项列表/返回值不动，
        // 以免破坏 `if(alert(...) == "Yes")` 之类的比较。alert 取 [0,1,2] 同时覆盖
        // `alert("msg")` 与 `alert(user, msg, title)` 两种写法（非字符串实参会被安全跳过）。
        // 原生 alert/input 的按钮/默认值是位置实参（无 usr 时 [2]=按钮），故只取 [0,1]=消息+标题
        // （含 usr 写法 alert(usr,msg,..) 则 [1]=消息；标题在 [2] 会漏译，但绝不误改按钮）。
        "alert" => Some(&[0, 1]),
        "input" => Some(&[0, 1]),
        "tgui_alert" => Some(&[1, 2]),
        "tgui_input_list" => Some(&[1, 2]),
        "tgui_input_text" => Some(&[1, 2]),
        "tgui_input_number" => Some(&[1, 2]),
        _ => None,
    }
}

struct Edit {
    start: usize,
    end: usize,
    replacement: String,
}

pub fn run(dme: &Path, filter: Option<&str>, dry_run: bool) -> Result<()> {
    let mut context = dm::Context::default();
    context.set_print_severity(Some(dm::Severity::Error));
    let pp = dm::preprocessor::Preprocessor::new(&context, dme.to_path_buf())
        .with_context(|| format!("无法打开 .dme: {}", dme.display()))?;
    let indents = dm::indents::IndentProcessor::new(&context, pp);
    let mut parser = dm::parser::Parser::new(&context, indents);
    parser.enable_procs();
    let (fatal, tree) = parser.parse_object_tree_2();
    if fatal {
        anyhow::bail!("DM 解析出现致命错误");
    }

    let mut rw = Rewriter {
        context: &context,
        filter,
        edits: HashMap::new(),
        cache: HashMap::new(),
    };

    // pass 1：收集所有「纯函数」proc 名（SpacemanDMM_should_be_pure）。纯度沿继承传播，
    // 子类型覆盖实现不会重复声明，故按 proc 名跳过（examine_hints 等本就应处处为纯）。
    let mut pure_procs: HashSet<String> = HashSet::new();
    for ty in tree.iter_types() {
        for (proc_name, type_proc) in ty.procs.iter() {
            for proc_value in type_proc.value.iter() {
                if let Some(block) = &proc_value.code {
                    if block_is_pure(block) {
                        pure_procs.insert(proc_name.clone());
                    }
                }
            }
        }
    }
    // pass 2：改写（跳过纯函数名的 proc）。
    for ty in tree.iter_types() {
        let ns = namespace_for(&ty.path);
        for (proc_name, type_proc) in ty.procs.iter() {
            if pure_procs.contains(proc_name) {
                continue;
            }
            for proc_value in type_proc.value.iter() {
                if let Some(block) = &proc_value.code {
                    rw.visit_block(block, &ns);
                    // 物种特征(perk) proc：额外把 list 里 SPECIES_PERK_NAME/DESC 的字符串值改写为 LANG，
                    // 让插值描述（[name] livers are…[pct]%）的模板可译（占位符运行时填值；与抽取同名门槛）。
                    if proc_name.contains("perk") {
                        rw.rewrite_perk_block(block, &ns);
                    }
                }
            }
        }
    }

    let mut total = 0usize;
    let mut files = 0usize;
    for (path, mut edits) in rw.edits {
        if edits.is_empty() {
            continue;
        }
        files += 1;
        total += edits.len();
        if dry_run {
            continue;
        }
        let Some(Some(mut src)) = rw.cache.remove(&path) else {
            continue;
        };
        // 按起点降序应用，避免前面的替换使后面的偏移失效。
        edits.sort_by(|a, b| b.start.cmp(&a.start));
        for e in &edits {
            src.replace_range(e.start..e.end, &e.replacement);
        }
        let is_core = !path.to_string_lossy().replace('\\', "/").contains("modular_nova/");
        if is_core && !src.starts_with(CORE_MARKER) {
            src.insert_str(0, &format!("{CORE_MARKER}\n"));
        }
        std::fs::write(&path, src).with_context(|| format!("写回失败: {}", path.display()))?;
    }

    eprintln!(
        "改写 {total} 处，{files} 个文件{}",
        if dry_run { "（dry-run，未落盘）" } else { "" }
    );
    Ok(())
}

/// 该 proc 是否标了 `set SpacemanDMM_should_be_pure`（纯函数，读全局会被 DreamChecker 判为破坏纯度）。
fn block_is_pure(block: &[Spanned<Statement>]) -> bool {
    block.iter().any(|s| {
        matches!(&s.elem, Statement::Setting { name, .. } if name.as_str() == "SpacemanDMM_should_be_pure")
    })
}

struct Rewriter<'a> {
    context: &'a dm::Context,
    filter: Option<&'a str>,
    edits: HashMap<PathBuf, Vec<Edit>>,
    cache: HashMap<PathBuf, Option<String>>,
}

impl<'a> Rewriter<'a> {
    fn source(&mut self, path: &Path) -> Option<&str> {
        let entry = self
            .cache
            .entry(path.to_path_buf())
            .or_insert_with(|| std::fs::read_to_string(path).ok());
        entry.as_deref()
    }

    fn visit_block(&mut self, block: &[Spanned<Statement>], ns: &str) {
        for stmt in block.iter() {
            self.visit_stmt(&stmt.elem, ns);
        }
    }

    fn visit_stmt(&mut self, stmt: &Statement, ns: &str) {
        match stmt {
            Statement::Expr(e) => self.visit_expr(e, ns),
            Statement::Return(Some(e)) => self.visit_expr(e, ns),
            Statement::While { condition, block } => {
                self.visit_expr(condition, ns);
                self.visit_block(block, ns);
            }
            Statement::If { arms, else_arm } => {
                for (cond, blk) in arms.iter() {
                    self.visit_expr(&cond.elem, ns);
                    self.visit_block(blk, ns);
                }
                if let Some(blk) = else_arm {
                    self.visit_block(blk, ns);
                }
            }
            Statement::ForInfinite { block } => self.visit_block(block, ns),
            Statement::ForLoop {
                init,
                test,
                inc,
                block,
            } => {
                if let Some(s) = init {
                    self.visit_stmt(s, ns);
                }
                if let Some(e) = test {
                    self.visit_expr(e, ns);
                }
                if let Some(s) = inc {
                    self.visit_stmt(s, ns);
                }
                self.visit_block(block, ns);
            }
            Statement::Switch {
                input,
                cases,
                default,
            } => {
                self.visit_expr(input, ns);
                // 修复：之前 `..` 漏掉了 cases —— switch 各 case 分支体里的语句全部没被改写。
                for (_case_conditions, blk) in cases.iter() {
                    self.visit_block(blk, ns);
                }
                if let Some(blk) = default {
                    self.visit_block(blk, ns);
                }
            }
            Statement::Spawn { delay, block } => {
                if let Some(e) = delay {
                    self.visit_expr(e, ns);
                }
                self.visit_block(block, ns);
            }
            Statement::Var(v) => {
                if let Some(e) = &v.value {
                    self.visit_expr(e, ns);
                }
            }
            Statement::Vars(vs) => {
                for v in vs.iter() {
                    if let Some(e) = &v.value {
                        self.visit_expr(e, ns);
                    }
                }
            }
            Statement::Setting { value, .. } => self.visit_expr(value, ns),
            _ => {}
        }
    }

    fn visit_expr(&mut self, expr: &Expression, ns: &str) {
        if let Expression::Base { term, follow } = expr {
            if let Term::Call(name, args) = &term.elem {
                if let Some(indices) = sink_message_args(name.as_str()) {
                    self.try_rewrite_call(term.location, args, indices, ns);
                }
            }
            // input() 是 dreammaker 的专用 Term::Input（因 `as type in list` 语法），不是 Call。
            // 复用同一套实参定位（term.location 指向 input 关键字，find_open_paren 找其 `(`）。
            if let Term::Input { args, .. } = &term.elem {
                if let Some(indices) = sink_message_args("input") {
                    self.try_rewrite_call(term.location, args, indices, ns);
                }
            }
            self.recurse_term(&term.elem, ns);
            for f in follow.iter() {
                // 方法调用形式的汇聚点（`X.visible_message(...)` 等）：用 follow 自身的 Location 定位、
                // 改写消息参数。裸调用走上面的 Term::Call 分支；方法调用是 Follow::Call，此前完全漏改。
                if let Follow::Call(_, name, fargs) = &f.elem {
                    if let Some(indices) = sink_message_args(name.as_str()) {
                        self.try_rewrite_call(f.location, fargs, indices, ns);
                    }
                }
                self.recurse_follow(&f.elem, ns);
            }
            return;
        }
        match expr {
            Expression::AssignOp { op, lhs, rhs } => {
                // examine 文本：裸 `.`，以及 examine 信号处理器的累加器（examine_list/text/strings +=，
                // COMSIG_ATOM_EXAMINE 的输出参数，必玩家可见）。
                if matches!(op, AssignOp::AddAssign) {
                    if let Expression::Base { term, follow } = lhs.as_ref() {
                        if follow.is_empty() {
                            if let Term::Ident(id) = &term.elem {
                                if id == "." || crate::extract::is_examine_accumulator(id) {
                                    self.try_rewrite_examine(term.location, id, rhs, ns);
                                }
                            }
                        }
                    }
                }
                self.visit_expr(lhs, ns);
                self.visit_expr(rhs, ns);
            }
            Expression::BinaryOp { lhs, rhs, .. } => {
                self.visit_expr(lhs, ns);
                self.visit_expr(rhs, ns);
            }
            Expression::TernaryOp {
                cond, if_, else_, ..
            } => {
                self.visit_expr(cond, ns);
                self.visit_expr(if_, ns);
                self.visit_expr(else_, ns);
            }
            _ => {}
        }
    }

    /// 改写一个汇聚点调用的各消息参数。
    ///
    /// 关键：用「调用」的 Location（调用点，可靠）定位，再从源码切出实参、找到其中的字符串
    /// 字面量并替换。这样对 span_*() 这类「宏展开后内层串位置指向宏定义」的情形也能正确改写
    /// （宏展开后内层文本节点的 Location 不可用于回写）。
    fn try_rewrite_call(
        &mut self,
        call_loc: dm::Location,
        args: &[Expression],
        indices: &[usize],
        ns: &str,
    ) {
        // 1) 用 AST 判定每个消息参数是否「恰好一个可翻译文本节点」，并取其模板/占位符数/key。
        let mut targets: Vec<(usize, String, usize)> = Vec::new();
        for &i in indices {
            let Some(arg) = args.get(i) else { continue };
            // 门槛：源码里恰好一个可翻译字符串字面量（保证后面切片定位无歧义）。
            let mut nodes: Vec<&Spanned<Term>> = Vec::new();
            collect_text_nodes(arg, &mut nodes);
            if nodes.len() != 1 {
                continue;
            }
            // key 用与抽取**同一**函数计算，保证目录命中。
            let Some(template) = build_template(arg) else {
                continue;
            };
            // 对话框按钮（Yes/No/Cancel…）绝不改写——它们是 `if(alert(...)=="Yes")` 的比较值，
            // 改成 LANG 会破坏比较逻辑（且 alert 空标题时按钮易被错位套用，见下方空实参对齐）。
            if is_dialog_button(&template) {
                continue;
            }
            targets.push((i, make_key(ns, &template), placeholder_count(&template)));
        }
        if targets.is_empty() {
            return;
        }

        // 2) 用调用点 Location 在源码里切出实参范围。
        let path = self.context.file_path(call_loc.file).to_path_buf();
        if let Some(filter) = self.filter {
            if !path.to_string_lossy().contains(filter) {
                return;
            }
        }
        let Some(src) = self.source(&path) else { return };
        let Some(name_start) = line_col_to_byte(src, call_loc.line, call_loc.column) else {
            return;
        };
        let Some(lparen) = find_open_paren(src, name_start) else { return };
        let Some(arg_ranges) = split_call_args(src, lparen) else { return };
        // 空实参守卫：dreammaker 的 AST **丢弃** `f(a,,b)` 里的空实参，但按源码逗号切分会**保留**空范围
        // → AST 下标与源码范围下标错位，目标会套用到相邻的错误实参（典型：alert 空标题 `,,` 致按钮被当
        // 消息改写，重跑还层层套 LANG）。有空实参即整调用跳过——宁可不译也不改坏（这类多为 admin alert）。
        if arg_ranges.iter().any(|&(s, e)| src[s..e].trim().is_empty()) {
            return;
        }

        // 3) 对每个目标实参，找到其中唯一的字符串字面量并替换。
        let mut new_edits: Vec<Edit> = Vec::new();
        for (i, key, placeholders) in targets {
            let Some(&(astart, aend)) = arg_ranges.get(i) else { continue };
            let Some(qpos) = find_first_quote(src, astart, aend) else { continue };
            let Some((lstart, qend, interp_args)) = scan_dm_string(src, qpos) else { continue };
            if qend > aend || interp_args.len() != placeholders {
                continue; // 越界 / 内插数不符 → 跳过
            }
            if in_preprocessor_directive(src, lstart) {
                continue; // 字符串在 #define 等预处理指令里（宏体）→ 跳过，避免破坏宏
            }
            let replacement = if interp_args.is_empty() {
                format!("LANG(\"{key}\", null)")
            } else {
                format!("LANG(\"{key}\", list({}))", interp_args.join(", "))
            };
            new_edits.push(Edit {
                start: lstart,
                end: qend,
                replacement,
            });
        }
        if !new_edits.is_empty() {
            self.edits.entry(path).or_default().extend(new_edits);
        }
    }

    /// 改写 examine 的 `. += <text>`。以「裸 `.` 的 Location」为锚（调用点级、可靠），在 rhs
    /// 源码里查找字符串字面量。覆盖裸串与 span_*() 包裹两种（span 包裹后内层串自身 Location
    /// 指向宏定义、不可用，故必须从 `.` 锚 + 源码扫描）。
    ///
    /// 安全：要求 rhs 源码里**恰好一个**顶层字符串字面量（span_notice("x") 满足；
    /// 形如 `foo("x") + "y"` 的有两个 → 跳过，避免改错那一个）。
    fn try_rewrite_examine(&mut self, dot_loc: dm::Location, anchor: &str, rhs: &Expression, ns: &str) {
        let mut nodes: Vec<&Spanned<Term>> = Vec::new();
        collect_text_nodes(rhs, &mut nodes);
        if nodes.len() != 1 {
            return;
        }
        let Some(template) = build_template(rhs) else {
            return;
        };
        let key = make_key(ns, &template);
        let placeholders = placeholder_count(&template);

        let path = self.context.file_path(dot_loc.file).to_path_buf();
        if let Some(filter) = self.filter {
            if !path.to_string_lossy().contains(filter) {
                return;
            }
        }
        let Some(src) = self.source(&path) else { return };
        let Some(dot_start) = line_col_to_byte(src, dot_loc.line, dot_loc.column) else {
            return;
        };
        if !src.as_bytes()[dot_start..].starts_with(anchor.as_bytes()) {
            return; // 锚与 LHS 标识符（`.` 或 examine_list 等）不符 → 定位有误，跳过
        }
        let line_end = logical_line_end(src, dot_start);

        // 在标识符之后、line_end 内找顶层字符串字面量；要求恰好一个。
        let bytes = src.as_bytes();
        let mut first: Option<(usize, usize, Vec<String>)> = None;
        let mut count = 0usize;
        let mut i = dot_start + anchor.len();
        while i < line_end {
            if bytes[i] == b'"' {
                let Some((lstart, end, args)) = scan_dm_string(src, i) else {
                    return; // 畸形字符串 → 跳过
                };
                count += 1;
                if first.is_none() {
                    first = Some((lstart, end, args));
                }
                i = end;
            } else {
                i += 1;
            }
        }
        if count != 1 {
            return; // 0 个或多个（有歧义）→ 跳过
        }
        let (qpos, qend, interp_args) = first.unwrap();
        if interp_args.len() != placeholders || in_preprocessor_directive(src, qpos) {
            return;
        }
        let replacement = if interp_args.is_empty() {
            format!("LANG(\"{key}\", null)")
        } else {
            format!("LANG(\"{key}\", list({}))", interp_args.join(", "))
        };
        self.edits
            .entry(path)
            .or_default()
            .push(Edit {
                start: qpos,
                end: qend,
                replacement,
            });
    }

    /// 物种特征(perk)：走 list 字面量，把 key 为 name/description（SPECIES_PERK_NAME/DESC 宏）的
    /// 字符串值改写为 LANG。穿过嵌套 list / `+=` / 赋值。仅改**单一字符串字面量**值
    /// （collect_text_nodes==1）；变量/拼接名（如 `perk_name` 变量、`"A " + b`）安全跳过。
    fn rewrite_perk_block(&mut self, block: &[Spanned<Statement>], ns: &str) {
        for stmt in block.iter() {
            match &stmt.elem {
                Statement::Expr(e) | Statement::Return(Some(e)) => self.rewrite_perk_expr(e, ns),
                Statement::Var(v) => {
                    if let Some(e) = &v.value {
                        self.rewrite_perk_expr(e, ns);
                    }
                }
                Statement::Vars(vs) => {
                    for v in vs.iter() {
                        if let Some(e) = &v.value {
                            self.rewrite_perk_expr(e, ns);
                        }
                    }
                }
                Statement::If { arms, else_arm } => {
                    for (_c, blk) in arms.iter() {
                        self.rewrite_perk_block(blk, ns);
                    }
                    if let Some(blk) = else_arm {
                        self.rewrite_perk_block(blk, ns);
                    }
                }
                Statement::Switch { cases, default, .. } => {
                    for (_c, blk) in cases.iter() {
                        self.rewrite_perk_block(blk, ns);
                    }
                    if let Some(blk) = default {
                        self.rewrite_perk_block(blk, ns);
                    }
                }
                Statement::While { block, .. }
                | Statement::ForInfinite { block }
                | Statement::ForLoop { block, .. }
                | Statement::Spawn { block, .. } => self.rewrite_perk_block(block, ns),
                _ => {}
            }
        }
    }

    fn rewrite_perk_expr(&mut self, expr: &Expression, ns: &str) {
        match expr {
            Expression::Base { term, follow } if follow.is_empty() => {
                let args = match &term.elem {
                    Term::List(args) => args,
                    Term::Call(name, args) if name == "list" => args,
                    _ => return,
                };
                for arg in args.iter() {
                    if let Expression::AssignOp { lhs, rhs, .. } = arg {
                        if matches!(build_template(lhs).as_deref(), Some("name") | Some("description")) {
                            self.try_rewrite_perk(rhs, ns);
                        }
                        self.rewrite_perk_expr(rhs, ns);
                    } else {
                        self.rewrite_perk_expr(arg, ns);
                    }
                }
            }
            Expression::AssignOp { rhs, .. } => self.rewrite_perk_expr(rhs, ns),
            Expression::BinaryOp { lhs, rhs, .. } => {
                self.rewrite_perk_expr(lhs, ns);
                self.rewrite_perk_expr(rhs, ns);
            }
            _ => {}
        }
    }

    /// 用 rhs 字符串字面量自身的 Location 定位、改写为 LANG（perk 值非 sink 调用、key 又是宏，
    /// 不能用 call/anchor 定位）。仅当 rhs 恰好一个文本节点（裸串/插值串）时改。
    fn try_rewrite_perk(&mut self, rhs: &Expression, ns: &str) {
        let mut nodes: Vec<&Spanned<Term>> = Vec::new();
        collect_text_nodes(rhs, &mut nodes);
        if nodes.len() != 1 {
            return;
        }
        let Some(template) = build_template(rhs) else {
            return;
        };
        let key = make_key(ns, &template);
        let placeholders = placeholder_count(&template);
        let loc = match rhs {
            Expression::Base { term, follow } if follow.is_empty() => term.location,
            _ => return,
        };
        let path = self.context.file_path(loc.file).to_path_buf();
        if let Some(filter) = self.filter {
            if !path.to_string_lossy().contains(filter) {
                return;
            }
        }
        let Some(src) = self.source(&path) else { return };
        let Some(start) = line_col_to_byte(src, loc.line, loc.column) else {
            return;
        };
        // 从 rhs 起点起、本逻辑行内找第一个字符串字面量的开引号。
        let line_end = logical_line_end(src, start);
        let bytes = src.as_bytes();
        let mut i = start;
        while i < line_end && bytes[i] != b'"' {
            i += 1;
        }
        if i >= line_end {
            return;
        }
        let Some((qpos, qend, interp_args)) = scan_dm_string(src, i) else {
            return;
        };
        if interp_args.len() != placeholders || in_preprocessor_directive(src, qpos) {
            return;
        }
        let replacement = if interp_args.is_empty() {
            format!("LANG(\"{key}\", null)")
        } else {
            format!("LANG(\"{key}\", list({}))", interp_args.join(", "))
        };
        self.edits.entry(path).or_default().push(Edit {
            start: qpos,
            end: qend,
            replacement,
        });
    }

    fn recurse_term(&mut self, term: &Term, ns: &str) {
        match term {
            Term::Expr(e) => self.visit_expr(e, ns),
            Term::InterpString(_, parts) => {
                for (opt, _) in parts.iter() {
                    if let Some(e) = opt {
                        self.visit_expr(e, ns);
                    }
                }
            }
            Term::Call(_, args)
            | Term::SelfCall(args)
            | Term::ParentCall(args)
            | Term::List(args)
            | Term::GlobalCall(_, args) => {
                for a in args.iter() {
                    self.visit_expr(a, ns);
                }
            }
            Term::DynamicCall(a, b) => {
                for e in a.iter() {
                    self.visit_expr(e, ns);
                }
                for e in b.iter() {
                    self.visit_expr(e, ns);
                }
            }
            Term::NewImplicit { args }
            | Term::NewPrefab { args, .. }
            | Term::NewMiniExpr { args, .. } => {
                if let Some(args) = args {
                    for e in args.iter() {
                        self.visit_expr(e, ns);
                    }
                }
            }
            Term::Input { args, in_list, .. } => {
                for e in args.iter() {
                    self.visit_expr(e, ns);
                }
                if let Some(e) = in_list {
                    self.visit_expr(e, ns);
                }
            }
            Term::Locate { args, in_list } => {
                for e in args.iter() {
                    self.visit_expr(e, ns);
                }
                if let Some(e) = in_list {
                    self.visit_expr(e, ns);
                }
            }
            Term::ExternalCall {
                library,
                function,
                args,
            } => {
                if let Some(e) = library {
                    self.visit_expr(e, ns);
                }
                self.visit_expr(function, ns);
                for e in args.iter() {
                    self.visit_expr(e, ns);
                }
            }
            _ => {}
        }
    }

    fn recurse_follow(&mut self, follow: &Follow, ns: &str) {
        match follow {
            Follow::Index(_, e) => self.visit_expr(e, ns),
            Follow::Call(_, _, args) => {
                for a in args.iter() {
                    self.visit_expr(a, ns);
                }
            }
            _ => {}
        }
    }
}

/// 收集消息参数里的「可翻译文本节点」（String / InterpString，过滤纯标签），降序穿过 `+` 拼接。
/// 无歧义的对话框按钮/比较值字面量——绝不改写为 LANG（否则破坏 `if(alert(...)=="Yes")` 之类比较，
/// 且无 usr 的 alert `alert(msg,title,"Yes")` 的 [2] 按钮易被当标题改写）。仅取**几乎只做按钮**的词；
/// 像 Confirm/Apply/Save 等常作标题/表头，**不**列入（应可译）。仅匹配整串恰好等于这些词的实参。
fn is_dialog_button(template: &str) -> bool {
    matches!(
        template.trim(),
        "Yes" | "No" | "Cancel" | "Ok" | "OK" | "Okay" | "Yes!" | "Nope" | "No!"
    )
}

fn collect_text_nodes<'b>(expr: &'b Expression, out: &mut Vec<&'b Spanned<Term>>) {
    match expr {
        Expression::Base { term, follow } if follow.is_empty() => match &term.elem {
            Term::String(_) | Term::InterpString(_, _) => {
                if node_template(&term.elem).is_some() {
                    out.push(term.as_ref());
                }
            }
            // 括号包裹（如 span_* 宏展开为 ("<span>" + str + "</span>")）：穿透进去。
            Term::Expr(inner) => collect_text_nodes(inner, out),
            _ => {}
        },
        Expression::BinaryOp {
            op: BinaryOp::Add,
            lhs,
            rhs,
        } => {
            collect_text_nodes(lhs, out);
            collect_text_nodes(rhs, out);
        }
        _ => {}
    }
}

/// 单个文本节点的模板（{0}/{1}…）与占位符个数；纯标签/无字母返回 None。
/// 与 extract.rs 的 build_template 对单节点结果一致（保证 key 匹配）。
fn node_template(term: &Term) -> Option<(String, usize)> {
    match term {
        Term::String(s) => {
            if !strip_tags(s).chars().any(|c| c.is_alphabetic()) {
                return None;
            }
            Some((s.clone(), 0))
        }
        Term::InterpString(lead, parts) => {
            let mut out = String::new();
            let mut count = 0usize;
            out.push_str(lead.as_str());
            for (opt, lit) in parts.iter() {
                if opt.is_some() {
                    out.push_str(&format!("{{{}}}", count));
                    count += 1;
                }
                out.push_str(lit);
            }
            if !strip_tags(&out).chars().any(|c| c.is_alphabetic()) {
                return None;
            }
            Some((out, count))
        }
        _ => None,
    }
}

