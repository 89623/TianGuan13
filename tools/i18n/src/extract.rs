//! DM 字符串抽取。
//!
//! 解析复用 SpacemanDMM 的 dreammaker 解析器（API 与 DreamChecker 一致）。
//! 抽取来源：
//!   1. 类型变量初始化里的玩家可见文本（SINK_VARS：name/desc 等，动态渲染文本主要来源）。
//!   2. proc 体内的汇聚点调用（SINK_CALLS：to_chat / visible_message / balloon_alert 等）。
//! 内插字符串 (Term::InterpString) 与字符串 `+` 拼接被转为 {0}/{1} 占位符模板，
//! 以适配中文语序；span_* 等宏在预处理期已展开为 HTML 包裹 + 内层文本的拼接，
//! 其纯标签片段（如 "<span class='notice'>"）会被过滤掉，只留可翻译文本。
//!
//! 本阶段只做抽取（产出英文主目录）；改写调用点为 LANG/LANGU 是后续阶段。

use anyhow::{Context as _, Result};
use std::collections::HashSet;
use std::path::Path;

use dm::ast::{AssignOp, BinaryOp, Expression, Follow, Statement, Term};

use crate::catalog::Catalog;
use crate::keys::{make_key, namespace_for};

/// 视为玩家可见的变量名。
/// message_* 系列是 /datum/emote 的各形态表情模板（人形/默剧/外星/AI/机器人等），玩家在聊天
/// 高频可见；它们是 var 赋值而非 sink 调用，靠抽取进目录 + /datum/emote/New() 整串反查落地。
const SINK_VARS: &[&str] = &[
    "name",
    "desc",
    "message",
    "flavor_text",
    "title",
    // /datum/emote 表情模板变体。
    "message_mime",
    "message_alien",
    "message_larva",
    "message_robot",
    "message_AI",
    "message_monkey",
    "message_animal_or_basic",
    "message_param",
];

/// 汇聚点 proc 名 -> 其消息参数下标。
fn sink_message_args(name: &str) -> Option<&'static [usize]> {
    match name {
        "to_chat" => Some(&[1]),
        "balloon_alert" => Some(&[1]),
        "visible_message" => Some(&[0, 1]),
        "audible_message" => Some(&[0, 1, 3]),
        "say" => Some(&[0]),
        "manual_emote" => Some(&[0]),
        // 提示/对话框（玩家可见）。只取消息+标题；按钮/选项列表/返回值不动，
        // 以免破坏 `if(alert(...) == "Yes")` 之类的比较。alert 取 [0,1,2] 同时覆盖
        // `alert("msg")` 与 `alert(user, msg, title)` 两种写法（非字符串实参会被安全跳过）。
        "alert" => Some(&[0, 1, 2]),
        "input" => Some(&[0, 1, 2]),
        "tgui_alert" => Some(&[1, 2]),
        "tgui_input_list" => Some(&[1, 2]),
        "tgui_input_text" => Some(&[1, 2]),
        "tgui_input_number" => Some(&[1, 2]),
        _ => None,
    }
}

pub fn run(dme: &Path, out: &Path, dry_run: bool) -> Result<()> {
    let mut context = dm::Context::default();
    context.set_print_severity(Some(dm::Severity::Error));

    let pp = dm::preprocessor::Preprocessor::new(&context, dme.to_path_buf())
        .with_context(|| format!("无法打开 .dme: {}", dme.display()))?;
    let indents = dm::indents::IndentProcessor::new(&context, pp);
    let mut parser = dm::parser::Parser::new(&context, indents);
    parser.enable_procs();
    let (fatal, tree) = parser.parse_object_tree_2();
    if fatal {
        anyhow::bail!("DM 解析出现致命错误，无法继续抽取");
    }

    // pass 1：收集纯函数 proc 名（与 rewrite 一致，按名跳过以覆盖继承纯度的子类型实现）。
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

    let mut catalog = Catalog::new();
    for ty in tree.iter_types() {
        let namespace = namespace_for(&ty.path);

        // 1) 变量初始化（name/desc 等）。
        for (var_name, type_var) in ty.vars.iter() {
            if !SINK_VARS.contains(&var_name.as_str()) {
                continue;
            }
            if let Some(expr) = &type_var.value.expression {
                if let Some(template) = build_template(expr) {
                    emit(&mut catalog, &namespace, &template);
                }
            }
        }

        // 2) proc 体内的汇聚点调用（跳过纯函数名的 proc）。
        for (proc_name, type_proc) in ty.procs.iter() {
            if pure_procs.contains(proc_name) {
                continue;
            }
            for proc_value in type_proc.value.iter() {
                if let Some(block) = &proc_value.code {
                    visit_block(block, &namespace, &mut catalog);
                }
            }
        }
    }

    eprintln!(
        "抽取 {} 条字符串，{} 个命名空间",
        catalog.entry_count(),
        catalog.namespace_count()
    );
    if !dry_run {
        // 合并已存在目录：保留已被 rewrite 改写（源码里已不是字面量）的 key（重同步必需）。
        catalog.load_dir(out);
        catalog.write(out)?;
        eprintln!(
            "已写入英文主目录: {}（合并后 {} 条）",
            out.display(),
            catalog.entry_count()
        );
    }
    Ok(())
}

/// 该 proc 是否标了 `set SpacemanDMM_should_be_pure`（与 rewrite.rs 一致，跳过不抽取）。
fn block_is_pure(block: &[dm::ast::Spanned<Statement>]) -> bool {
    block.iter().any(|s| {
        matches!(&s.elem, Statement::Setting { name, .. } if name.as_str() == "SpacemanDMM_should_be_pure")
    })
}

fn emit(catalog: &mut Catalog, namespace: &str, template: &str) {
    if !template.chars().any(|c| c.is_alphabetic()) {
        return;
    }
    let key = make_key(namespace, template);
    catalog.insert(namespace, &key, template);
}

// ---- 语句/表达式遍历：找到汇聚点调用 ----

fn visit_block(block: &[dm::ast::Spanned<Statement>], ns: &str, catalog: &mut Catalog) {
    for stmt in block.iter() {
        visit_stmt(&stmt.elem, ns, catalog);
    }
}

fn visit_stmt(stmt: &Statement, ns: &str, catalog: &mut Catalog) {
    match stmt {
        Statement::Expr(e) => visit_expr(e, ns, catalog),
        Statement::Return(Some(e)) => visit_expr(e, ns, catalog),
        Statement::While { condition, block } => {
            visit_expr(condition, ns, catalog);
            visit_block(block, ns, catalog);
        }
        Statement::If { arms, else_arm } => {
            for (cond, blk) in arms.iter() {
                visit_expr(&cond.elem, ns, catalog);
                visit_block(blk, ns, catalog);
            }
            if let Some(blk) = else_arm {
                visit_block(blk, ns, catalog);
            }
        }
        Statement::ForInfinite { block } => visit_block(block, ns, catalog),
        Statement::ForLoop {
            init,
            test,
            inc,
            block,
        } => {
            if let Some(s) = init {
                visit_stmt(s, ns, catalog);
            }
            if let Some(e) = test {
                visit_expr(e, ns, catalog);
            }
            if let Some(s) = inc {
                visit_stmt(s, ns, catalog);
            }
            visit_block(block, ns, catalog);
        }
        Statement::Switch { input, default, .. } => {
            visit_expr(input, ns, catalog);
            if let Some(blk) = default {
                visit_block(blk, ns, catalog);
            }
        }
        Statement::Spawn { delay, block } => {
            if let Some(e) = delay {
                visit_expr(e, ns, catalog);
            }
            visit_block(block, ns, catalog);
        }
        Statement::Var(v) => {
            if let Some(e) = &v.value {
                visit_expr(e, ns, catalog);
            }
        }
        Statement::Vars(vs) => {
            for v in vs.iter() {
                if let Some(e) = &v.value {
                    visit_expr(e, ns, catalog);
                }
            }
        }
        Statement::Setting { value, .. } => visit_expr(value, ns, catalog),
        _ => {}
    }
}

fn visit_expr(expr: &Expression, ns: &str, catalog: &mut Catalog) {
    match expr {
        Expression::Base { term, follow } => {
            // 汇聚点调用检测。
            if let Term::Call(name, args) = &term.elem {
                if let Some(indices) = sink_message_args(name.as_str()) {
                    for &i in indices {
                        if let Some(arg) = args.get(i) {
                            if let Some(template) = build_template(arg) {
                                emit(catalog, ns, &template);
                            }
                        }
                    }
                }
            }
            // input() 是专用 Term::Input（非 Call），与 rewrite 保持一致地抽取其消息/标题。
            if let Term::Input { args, .. } = &term.elem {
                if let Some(indices) = sink_message_args("input") {
                    for &i in indices {
                        if let Some(arg) = args.get(i) {
                            if let Some(template) = build_template(arg) {
                                emit(catalog, ns, &template);
                            }
                        }
                    }
                }
            }
            recurse_term(&term.elem, ns, catalog);
            for f in follow.iter() {
                recurse_follow(&f.elem, ns, catalog);
            }
        }
        Expression::BinaryOp { lhs, rhs, .. } => {
            visit_expr(lhs, ns, catalog);
            visit_expr(rhs, ns, catalog);
        }
        Expression::AssignOp { op, lhs, rhs } => {
            // examine 文本：`. += <text>`（AddAssign，左侧裸 `.`）。
            if matches!(op, AssignOp::AddAssign) {
                if let Expression::Base { term, follow } = lhs.as_ref() {
                    if follow.is_empty() {
                        if let Term::Ident(id) = &term.elem {
                            if id == "." {
                                if let Some(template) = build_template(rhs) {
                                    emit(catalog, ns, &template);
                                }
                            }
                        }
                    }
                }
            }
            visit_expr(lhs, ns, catalog);
            visit_expr(rhs, ns, catalog);
        }
        Expression::TernaryOp {
            cond, if_, else_, ..
        } => {
            visit_expr(cond, ns, catalog);
            visit_expr(if_, ns, catalog);
            visit_expr(else_, ns, catalog);
        }
    }
}

fn recurse_term(term: &Term, ns: &str, catalog: &mut Catalog) {
    match term {
        Term::Expr(e) => visit_expr(e, ns, catalog),
        Term::InterpString(_, parts) => {
            for (opt, _) in parts.iter() {
                if let Some(e) = opt {
                    visit_expr(e, ns, catalog);
                }
            }
        }
        Term::Call(_, args)
        | Term::SelfCall(args)
        | Term::ParentCall(args)
        | Term::List(args)
        | Term::GlobalCall(_, args) => {
            for a in args.iter() {
                visit_expr(a, ns, catalog);
            }
        }
        Term::DynamicCall(a, b) => {
            for e in a.iter() {
                visit_expr(e, ns, catalog);
            }
            for e in b.iter() {
                visit_expr(e, ns, catalog);
            }
        }
        Term::NewImplicit { args } | Term::NewPrefab { args, .. } | Term::NewMiniExpr { args, .. } => {
            if let Some(args) = args {
                for e in args.iter() {
                    visit_expr(e, ns, catalog);
                }
            }
        }
        Term::Input { args, in_list, .. } => {
            for e in args.iter() {
                visit_expr(e, ns, catalog);
            }
            if let Some(e) = in_list {
                visit_expr(e, ns, catalog);
            }
        }
        Term::Locate { args, in_list } => {
            for e in args.iter() {
                visit_expr(e, ns, catalog);
            }
            if let Some(e) = in_list {
                visit_expr(e, ns, catalog);
            }
        }
        Term::ExternalCall {
            library,
            function,
            args,
        } => {
            if let Some(e) = library {
                visit_expr(e, ns, catalog);
            }
            visit_expr(function, ns, catalog);
            for e in args.iter() {
                visit_expr(e, ns, catalog);
            }
        }
        _ => {}
    }
}

fn recurse_follow(follow: &Follow, ns: &str, catalog: &mut Catalog) {
    match follow {
        Follow::Index(_, e) => visit_expr(e, ns, catalog),
        Follow::Call(_, _, args) => {
            for a in args.iter() {
                visit_expr(a, ns, catalog);
            }
        }
        _ => {}
    }
}

// ---- 占位符模板构建 ----

/// 把一个表达式（字符串/内插串/字符串拼接）转为带 {0}/{1} 占位符的模板。
/// 非文本（纯变量/调用）返回 None。整体无字母（纯标签/标点）也返回 None。
///
/// 注意：本函数是「抽取 key」与「改写 key」的**唯一真相来源**（rewrite.rs 也调用它），
/// 二者必须用同一函数算 key 才能保证目录命中。
pub(crate) fn build_template(expr: &Expression) -> Option<String> {
    let mut out = String::new();
    let mut idx = 0usize;
    let is_text = render(expr, &mut out, &mut idx);
    // 整体去标签后需含字母，避免把纯标签/纯占位符当作可翻译文本。
    if is_text && strip_tags(&out).chars().any(|c| c.is_alphabetic()) {
        Some(out)
    } else {
        None
    }
}

/// 模板里的占位符个数（{0}/{1}… 顺序生成，这里数 `{` 紧跟数字的出现次数）。
pub(crate) fn placeholder_count(template: &str) -> usize {
    let b = template.as_bytes();
    let mut n = 0usize;
    let mut i = 0usize;
    while i + 1 < b.len() {
        if b[i] == b'{' && b[i + 1].is_ascii_digit() {
            n += 1;
        }
        i += 1;
    }
    n
}

/// 返回该表达式是否为「文本节点」（字符串/内插/字符串相加，含括号包裹）。
/// - 独立字符串字面量：纯标签/纯标点（去标签后无字母）丢弃（如 span 包裹），否则原样写入；
/// - 内插串：lead 与各段字面量**原样**写入（保留 "!" 等标点），内插表达式写成 {N}；
/// - 其余（变量、调用、带 follow 取值等）：在拼接语境里写成 {N} 占位符并返回 false。
fn render(expr: &Expression, out: &mut String, idx: &mut usize) -> bool {
    match expr {
        Expression::Base { term, follow } if follow.is_empty() => match &term.elem {
            Term::String(s) => {
                // 独立字符串：仅当去标签后含字母才保留（丢弃 span 包裹、纯标点独立串）。
                if strip_tags(s).chars().any(|c| c.is_alphabetic()) {
                    out.push_str(s);
                }
                true
            }
            Term::InterpString(lead, parts) => {
                out.push_str(lead.as_str());
                for (opt, lit) in parts.iter() {
                    if opt.is_some() {
                        out.push_str(&format!("{{{}}}", *idx));
                        *idx += 1;
                    }
                    out.push_str(lit);
                }
                true
            }
            // 括号包裹（如 span_* 宏展开为 ("<span>" + str + "</span>")）：穿透进去。
            Term::Expr(inner) => render(inner, out, idx),
            _ => {
                out.push_str(&format!("{{{}}}", *idx));
                *idx += 1;
                false
            }
        },
        Expression::BinaryOp {
            op: BinaryOp::Add,
            lhs,
            rhs,
        } => {
            let l = render(lhs, out, idx);
            let r = render(rhs, out, idx);
            l || r
        }
        _ => {
            out.push_str(&format!("{{{}}}", *idx));
            *idx += 1;
            false
        }
    }
}

/// 去掉 `<...>` 标签后的文本（用于判断片段是否只是标签）。
pub(crate) fn strip_tags(s: &str) -> String {
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
