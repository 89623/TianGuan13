//! DM 调用点改写（阶段2，v1：保守子集）。
//!
//! 把汇聚点调用里「单个纯字符串字面量」的消息参数原地替换为 `LANG("key", null)`，
//! key 与抽取阶段一致（同一 AST 节点 → 同一 namespace+内容哈希），故目录已含该 key。
//!
//! 安全约束（面向 CI 自动化，杜绝源码损坏）：
//!   - 仅处理 Term::String（无内插 `[...]`、无 `+` 拼接、无 follow）的消息参数；
//!   - 仅按 AST 的 Location(行,列) 定位到源码中的开引号，并断言该处确为 `"`，否则跳过；
//!   - 含 `[` 的字符串（内插）一律跳过（留待 v2）；
//!   - 幂等：已是 LANG(...) 调用的参数不是字符串字面量，不会被再次改写。
//!
//! 改写用全服 locale 的 `LANG`（广播/定向皆可，无需接收者源码）；按接收者 locale 的
//! `LANGU` 改写留待 v2（需切出接收者参数源码）。

use anyhow::{Context as _, Result};
use std::collections::HashMap;
use std::path::{Path, PathBuf};

use dm::ast::{Expression, Follow, Statement, Term};

use crate::extract::build_template;
use crate::keys::{make_key, namespace_for};

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

/// 核心文件（非 modular_nova）被 codemod 改写时插入的文件级 NOVA EDIT 标记。
const CORE_MARKER: &str =
    "// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md";

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
        // 核心文件（非 modular_nova）需加 NOVA EDIT 标记；在 span 替换之后再插入，避免位移。
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

    fn visit_block(&mut self, block: &[dm::ast::Spanned<Statement>], ns: &str) {
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
                    for &i in indices {
                        if let Some(arg) = args.get(i) {
                            self.try_rewrite_message(arg, ns);
                        }
                    }
                }
            }
            self.recurse_term(&term.elem, ns);
            for f in follow.iter() {
                self.recurse_follow(&f.elem, ns);
            }
            return;
        }
        match expr {
            Expression::BinaryOp { lhs, rhs, .. } | Expression::AssignOp { lhs, rhs, .. } => {
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

    /// 只改写「单个纯字符串字面量」的消息参数。
    fn try_rewrite_message(&mut self, arg: &Expression, ns: &str) {
        let Expression::Base { term, follow } = arg else {
            return;
        };
        if !follow.is_empty() {
            return;
        }
        let Term::String(_) = &term.elem else {
            return;
        };
        let Some(template) = build_template(arg) else {
            return; // 纯标签/无字母等不可翻译
        };
        let key = make_key(ns, &template);

        let loc = term.location;
        let path = self.context.file_path(loc.file).to_path_buf();
        if let Some(filter) = self.filter {
            if !path.to_string_lossy().contains(filter) {
                return;
            }
        }
        let Some(src) = self.source(&path) else {
            return;
        };
        let Some(start) = line_col_to_byte(src, loc.line, loc.column) else {
            return;
        };
        // 防御：该处必须是开引号，否则定位有误，跳过（绝不损坏源码）。
        if src.as_bytes().get(start) != Some(&b'"') {
            return;
        }
        let Some(end) = plain_string_end(src, start) else {
            return; // 含内插 `[` / 跨行 / 未闭合 → 跳过
        };
        let replacement = format!("LANG(\"{key}\", null)");
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

/// 给定开引号位置，返回闭引号之后的字节位置；含内插 `[`/跨行/未闭合则返回 None。
fn plain_string_end(src: &str, start: usize) -> Option<usize> {
    let bytes = src.as_bytes();
    if bytes.get(start) != Some(&b'"') {
        return None;
    }
    let mut i = start + 1;
    while i < bytes.len() {
        match bytes[i] {
            b'\\' => i += 2,
            b'[' => return None, // 内插字符串，v1 跳过
            b'"' => return Some(i + 1),
            b'\n' => return None,
            _ => i += 1,
        }
    }
    None
}
