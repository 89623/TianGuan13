//! `strings/` flavor 数据文件抽取（与 sink/SINK_VARS 走同一主目录）。
//!
//! 只纳入**展示型 flavor**（整句/整段，玩家直接看到）。**不纳入**关键词表 / 文本变换表 /
//! 名字生成器（如 phobia 触发词、heckacious 替换表、pirates/exodrone/arcade 名字片段、口音表、
//! names/、词频表）——它们要么是功能性匹配会被翻译破坏，要么是会因语序错乱的生成器片段。
//! 运行时**不需要白名单**：load 处对所有 strings 文件跑反查，但只有这里抽进目录的串才会命中改写，
//! 其余天然 no-op（再加多词门槛防单词误伤）。逐字保留（含前导 @/% 与 @pick(...) 宏、HTML），
//! 与运行时 file2list/json_load 拿到的串一致，反查才命中；译者须保留这些 token。

use std::path::Path;

use crate::catalog::Catalog;
use crate::extract::emit;

const FLAVOR_FILES: &[&str] = &[
    "tips.txt",
    "sillytips.txt",
    "chemistrytips.txt",
    "fishing_tips.txt",
    "junkmail.txt",
    "abductee_objectives.txt",
    "bane.json",
    "boomer.json",
    "eigenstasium.json",
    "mother.json",
    "ninja.json",
    "flavor_reports.json",
    "memories.json",
];

/// 递归纳入其下所有 .json 的 flavor 子目录。
const FLAVOR_DIRS: &[&str] = &["antagonist_flavor", "wounds"];

pub(crate) fn extract_flavor(strings_root: &Path, catalog: &mut Catalog) {
    for name in FLAVOR_FILES {
        extract_flavor_file(&strings_root.join(name), catalog);
    }
    for dir in FLAVOR_DIRS {
        if let Ok(entries) = std::fs::read_dir(strings_root.join(dir)) {
            for entry in entries.flatten() {
                extract_flavor_file(&entry.path(), catalog);
            }
        }
    }
}

fn extract_flavor_file(path: &Path, catalog: &mut Catalog) {
    let Ok(text) = std::fs::read_to_string(path) else {
        return;
    };
    match path.extension().and_then(|s| s.to_str()) {
        Some("txt") => {
            // 逐非空行（trim，与 file2list 默认 trim=TRUE 一致）。
            for line in text.lines() {
                let line = line.trim();
                if !line.is_empty() {
                    emit(catalog, "strings", line);
                }
            }
        }
        Some("json") => {
            if let Ok(value) = serde_json::from_str::<serde_json::Value>(&text) {
                collect_json_strings(&value, catalog);
            }
        }
        _ => {}
    }
}

/// 递归取 JSON 的字符串叶子（数组元素 / 关联值）；key 不取（程序标识）。
fn collect_json_strings(value: &serde_json::Value, catalog: &mut Catalog) {
    match value {
        serde_json::Value::String(s) => {
            let s = s.trim();
            if !s.is_empty() {
                emit(catalog, "strings", s);
            }
        }
        serde_json::Value::Array(arr) => {
            for v in arr {
                collect_json_strings(v, catalog);
            }
        }
        serde_json::Value::Object(map) => {
            for v in map.values() {
                collect_json_strings(v, catalog);
            }
        }
        _ => {}
    }
}
