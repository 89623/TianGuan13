//! 占位符模板构建（抽取与改写共用的「唯一真相来源」）。
//!
//! 把一个表达式（字符串/内插串/字符串拼接）转为带 `{0}/{1}` 占位符的模板，
//! 以适配中文语序。抽取算 key 与改写算 key 都调用 [`build_template`]，二者必须
//! 用同一函数才能保证目录命中。

use dm::ast::{BinaryOp, Expression, Term};

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
