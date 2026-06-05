//! 源码层面的 DM 字符串/调用扫描助手（纯字节定位，不依赖 AST）。
//!
//! 改写阶段用「调用点 Location」在源码里切片定位，再用这里的函数找开括号、切实参、
//! 扫描字符串字面量（含 `{"..."}` 块串与 `[...]` 内插）、跳过预处理指令/续行等。

/// 把 (1-based 行, 1-based 字符列) 转成字节偏移。超出文件返回 None。
pub(crate) fn line_col_to_byte(src: &str, line: u32, column: u16) -> Option<usize> {
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
pub(crate) fn find_open_paren(src: &str, name_start: usize) -> Option<usize> {
    let b = src.as_bytes();
    let mut i = name_start;
    // 方法调用 `X.method(...)` 的 Follow Location 指向属性访问标点（. : ?. ?:）而非方法名；
    // 先跳过这些前导标点与空白。裸调用 Location 指向标识符首字符、无前导标点 → 对其为 no-op。
    while i < b.len() && matches!(b[i], b'.' | b':' | b'?' | b' ' | b'\t') {
        i += 1;
    }
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
pub(crate) fn split_call_args(src: &str, lparen: usize) -> Option<Vec<(usize, usize)>> {
    let b = src.as_bytes();
    let mut ranges: Vec<(usize, usize)> = Vec::new();
    let mut depth = 1usize;
    let mut i = lparen + 1;
    let mut arg_start = i;
    while i < b.len() {
        match b[i] {
            b'{' if b.get(i + 1) == Some(&b'"') => {
                // 块串 {"..."}：整体跳过（包含闭合 "}）。
                let (_, end, _) = scan_dm_string(src, i + 1)?;
                i = end;
            }
            b'"' => {
                let (_, end, _) = scan_dm_string(src, i)?;
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
pub(crate) fn in_preprocessor_directive(src: &str, pos: usize) -> bool {
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

/// 从 `from` 所在位置找逻辑行结尾的字节位置（跳过 `\` 续行）。
pub(crate) fn logical_line_end(src: &str, from: usize) -> usize {
    let b = src.as_bytes();
    let mut i = from;
    while i < b.len() {
        if b[i] == b'\n' {
            let mut e = i;
            if e > 0 && b[e - 1] == b'\r' {
                e -= 1;
            }
            if e > 0 && b[e - 1] == b'\\' {
                i += 1; // 续行，继续
                continue;
            }
            return i;
        }
        i += 1;
    }
    b.len()
}

/// 在 [start, end) 区间里找第一个 `"` 的字节位置。
pub(crate) fn find_first_quote(src: &str, start: usize, end: usize) -> Option<usize> {
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

/// 从开引号位置扫描一个 DM 字符串字面量。支持普通串 `"..."` 与块串 `{"..."}`
/// （块串可含未转义的 `"` 与换行，闭合为 `"}`；块串的字面量起点是 `{`）。
/// 返回 (字面量起点字节位置, 结束后字节位置, 各 `[...]` 内插表达式源码)。未闭合返回 None。
/// 仅 ASCII 定界符参与判定，多字节字符按字节跳过，切片边界恒在 ASCII 处。
pub(crate) fn scan_dm_string(src: &str, quote_pos: usize) -> Option<(usize, usize, Vec<String>)> {
    let b = src.as_bytes();
    if b.get(quote_pos) != Some(&b'"') {
        return None;
    }
    let block = quote_pos > 0 && b[quote_pos - 1] == b'{'; // {"..."} 块串
    let start = if block { quote_pos - 1 } else { quote_pos };
    let mut args: Vec<String> = Vec::new();
    let mut i = quote_pos + 1;
    while i < b.len() {
        match b[i] {
            b'\\' => i += 2, // 转义（含行末续行 \<newline>）
            b'"' => {
                if block {
                    if b.get(i + 1) == Some(&b'}') {
                        return Some((start, i + 2, args)); // 闭合 "}
                    }
                    i += 1; // 块串内的字面量 "
                } else {
                    return Some((start, i + 1, args));
                }
            }
            b'\n' => {
                if block {
                    i += 1; // 块串可跨行
                } else {
                    return None;
                }
            }
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
