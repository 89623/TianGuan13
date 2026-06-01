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
use std::collections::HashMap;
use std::path::{Path, PathBuf};

use dm::ast::{AssignOp, BinaryOp, Expression, Follow, Spanned, Statement, Term};

use crate::extract::{build_template, placeholder_count};
use crate::keys::{make_key, namespace_for};

/// 核心文件（非 modular_nova）被 codemod 改写时插入的文件级 NOVA EDIT 标记。
const CORE_MARKER: &str =
    "// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md";

/// 汇聚点 proc 名 -> 消息参数下标（与 extract.rs 保持一致）。
fn sink_message_args(name: &str) -> Option<&'static [usize]> {
    match name {
        "to_chat" => Some(&[1]),
        "balloon_alert" => Some(&[1]),
        "visible_message" => Some(&[0, 1]),
        "audible_message" => Some(&[0, 1, 3]),
        "say" => Some(&[0]),
        "manual_emote" => Some(&[0]),
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

    for ty in tree.iter_types() {
        let ns = namespace_for(&ty.path);
        for (_proc_name, type_proc) in ty.procs.iter() {
            for proc_value in type_proc.value.iter() {
                if let Some(block) = &proc_value.code {
                    rw.visit_block(block, &ns);
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
            Statement::Switch { input, default, .. } => {
                self.visit_expr(input, ns);
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
            self.recurse_term(&term.elem, ns);
            for f in follow.iter() {
                self.recurse_follow(&f.elem, ns);
            }
            return;
        }
        match expr {
            Expression::AssignOp { op, lhs, rhs } => {
                // examine 文本：`. += <text>`（AddAssign，左侧是裸 `.`）。
                if matches!(op, AssignOp::AddAssign) {
                    if let Expression::Base { term, follow } = lhs.as_ref() {
                        if follow.is_empty() {
                            if let Term::Ident(id) = &term.elem {
                                if id == "." {
                                    self.try_rewrite_examine(rhs, ns);
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

        // 3) 对每个目标实参，找到其中唯一的字符串字面量并替换。
        let mut new_edits: Vec<Edit> = Vec::new();
        for (i, key, placeholders) in targets {
            let Some(&(astart, aend)) = arg_ranges.get(i) else { continue };
            let Some(qpos) = find_first_quote(src, astart, aend) else { continue };
            let Some((qend, interp_args)) = scan_dm_string(src, qpos) else { continue };
            if qend > aend || interp_args.len() != placeholders {
                continue; // 越界 / 内插数不符 → 跳过
            }
            if in_preprocessor_directive(src, qpos) {
                continue; // 字符串在 #define 等预处理指令里（宏体）→ 跳过，避免破坏宏
            }
            let replacement = if interp_args.is_empty() {
                format!("LANG(\"{key}\", null)")
            } else {
                format!("LANG(\"{key}\", list({}))", interp_args.join(", "))
            };
            new_edits.push(Edit {
                start: qpos,
                end: qend,
                replacement,
            });
        }
        if !new_edits.is_empty() {
            self.edits.entry(path).or_default().extend(new_edits);
        }
    }

    /// 改写 examine 的 `. += <text>`。以「文本节点自身的 Location」为锚（校验该处确为 `"`）：
    /// 裸字符串 `. += "..."` / `. += "[interp]"` 的节点位置可靠 → 改写；span_*() 包裹的内层串
    /// 位置指向宏定义（不是 `"`）→ 自动跳过（留待后续）。零损坏风险。
    fn try_rewrite_examine(&mut self, rhs: &Expression, ns: &str) {
        let mut nodes: Vec<&Spanned<Term>> = Vec::new();
        collect_text_nodes(rhs, &mut nodes);
        if nodes.len() != 1 {
            return;
        }
        let node = nodes[0];
        let Some(template) = build_template(rhs) else {
            return;
        };
        let key = make_key(ns, &template);
        let placeholders = placeholder_count(&template);

        let loc = node.location;
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
        if src.as_bytes().get(start) != Some(&b'"') {
            return; // 节点位置非开引号（span_* 宏展开等）→ 跳过
        }
        let Some((end, interp_args)) = scan_dm_string(src, start) else {
            return;
        };
        if interp_args.len() != placeholders || in_preprocessor_directive(src, start) {
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
            .push(Edit { start, end, replacement });
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

/// 去掉 `<...>` 标签后的文本（判断片段是否只是标签）。
fn strip_tags(s: &str) -> String {
    let mut result = String::new();
    let mut in_tag = false;
    for c in s.chars() {
        match c {
            '<' => in_tag = true,
            '>' => in_tag = false,
            _ if !in_tag => result.push(c),
            _ => {}
        }
    }
    result
}

/// (行, 列) -> 字节偏移。行列均 1-based，列按字符计（与 dreammaker 一致；制表符算 1 列）。
fn line_col_to_byte(src: &str, line: u32, column: u16) -> Option<usize> {
    let mut line_start = 0usize;
    if line > 1 {
        let mut seen = 1u32;
        for (i, b) in src.bytes().enumerate() {
            if b == b'\n' {
                seen += 1;
                if seen == line {
                    line_start = i + 1;
                    break;
                }
            }
        }
        if seen < line {
            return None;
        }
    }
    let rest = &src[line_start..];
    let mut col = 1u16;
    for (i, _) in rest.char_indices() {
        if col == column {
            return Some(line_start + i);
        }
        col += 1;
    }
    None
}

/// 从函数名起点找到其后的 `(` 位置（跳过标识符与空白）。
fn find_open_paren(src: &str, name_start: usize) -> Option<usize> {
    let b = src.as_bytes();
    let mut i = name_start;
    while i < b.len() && (b[i].is_ascii_alphanumeric() || b[i] == b'_') {
        i += 1;
    }
    while i < b.len() && (b[i] == b' ' || b[i] == b'\t') {
        i += 1;
    }
    if b.get(i) == Some(&b'(') {
        Some(i)
    } else {
        None
    }
}

/// 给定调用的 `(` 位置，按顶层逗号切出各实参的字节范围（不含外层括号）。
/// 正确跳过字符串（含 `[...]` 内插）、注释、以及嵌套的 () [] {}。
fn split_call_args(src: &str, lparen: usize) -> Option<Vec<(usize, usize)>> {
    let b = src.as_bytes();
    let mut ranges: Vec<(usize, usize)> = Vec::new();
    let mut depth = 1usize;
    let mut i = lparen + 1;
    let mut arg_start = i;
    while i < b.len() {
        match b[i] {
            b'"' => {
                let (end, _) = scan_dm_string(src, i)?;
                i = end;
            }
            b'/' if b.get(i + 1) == Some(&b'/') => {
                while i < b.len() && b[i] != b'\n' {
                    i += 1;
                }
            }
            b'/' if b.get(i + 1) == Some(&b'*') => {
                i += 2;
                while i + 1 < b.len() && !(b[i] == b'*' && b[i + 1] == b'/') {
                    i += 1;
                }
                i += 2;
            }
            b'(' | b'[' | b'{' => {
                depth += 1;
                i += 1;
            }
            b')' | b']' | b'}' => {
                depth -= 1;
                if depth == 0 {
                    ranges.push((arg_start, i));
                    return Some(ranges);
                }
                i += 1;
            }
            b',' if depth == 1 => {
                ranges.push((arg_start, i));
                i += 1;
                arg_start = i;
            }
            _ => i += 1,
        }
    }
    None
}

/// 判断 byte 位置是否处于预处理指令（`#define` 等，含 `\` 续行的宏体）内。
/// 改写宏体里的字符串会破坏宏（其展开上下文不定），故一律跳过。
fn in_preprocessor_directive(src: &str, pos: usize) -> bool {
    let b = src.as_bytes();
    // 定位 pos 所在物理行的行首。
    let mut line_start = pos;
    while line_start > 0 && b[line_start - 1] != b'\n' {
        line_start -= 1;
    }
    // 若上一行以 `\` 续行，则继续上溯到指令首行。
    loop {
        if line_start == 0 {
            break;
        }
        let prev_nl = line_start - 1; // 上一行末尾的 '\n'
        let mut e = prev_nl;
        if e > 0 && b[e - 1] == b'\r' {
            e -= 1;
        }
        if e > 0 && b[e - 1] == b'\\' {
            let mut ps = prev_nl;
            while ps > 0 && b[ps - 1] != b'\n' {
                ps -= 1;
            }
            line_start = ps;
        } else {
            break;
        }
    }
    // 首行去前导空白后是否以 `#` 开头。
    let mut i = line_start;
    while i < b.len() && (b[i] == b' ' || b[i] == b'\t') {
        i += 1;
    }
    b.get(i) == Some(&b'#')
}

/// 在 [start, end) 区间里找第一个 `"` 的字节位置。
fn find_first_quote(src: &str, start: usize, end: usize) -> Option<usize> {
    let b = src.as_bytes();
    let mut i = start;
    while i < end {
        if b[i] == b'"' {
            return Some(i);
        }
        i += 1;
    }
    None
}

/// 从开引号位置扫描一个 DM 字符串字面量。
/// 返回 (闭引号之后的字节位置, 各 `[...]` 内插表达式源码)。未闭合/不平衡返回 None。
/// 仅 ASCII 定界符参与判定（`"` `[` `]` `\`），中文等多字节字符按字节跳过，切片边界恒在 ASCII 处。
fn scan_dm_string(src: &str, start: usize) -> Option<(usize, Vec<String>)> {
    let b = src.as_bytes();
    if b.get(start) != Some(&b'"') {
        return None;
    }
    let mut args: Vec<String> = Vec::new();
    let mut i = start + 1;
    while i < b.len() {
        match b[i] {
            b'\\' => i += 2, // 转义（含行末续行 \<newline>）
            b'"' => return Some((i + 1, args)),
            b'[' => {
                let inner_start = i + 1;
                let mut depth = 1usize;
                let mut j = inner_start;
                while j < b.len() && depth > 0 {
                    match b[j] {
                        b'\\' => j += 2,
                        b'[' => {
                            depth += 1;
                            j += 1;
                        }
                        b']' => {
                            depth -= 1;
                            if depth == 0 {
                                break;
                            }
                            j += 1;
                        }
                        b'"' => {
                            // 跳过内插里的嵌套字符串
                            j += 1;
                            while j < b.len() {
                                match b[j] {
                                    b'\\' => j += 2,
                                    b'"' => {
                                        j += 1;
                                        break;
                                    }
                                    _ => j += 1,
                                }
                            }
                        }
                        _ => j += 1,
                    }
                }
                if depth != 0 {
                    return None;
                }
                args.push(src[inner_start..j].trim().to_string());
                i = j + 1;
            }
            _ => i += 1,
        }
    }
    None
}
