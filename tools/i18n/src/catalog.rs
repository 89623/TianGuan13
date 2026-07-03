//! 英文主目录的内存模型与落盘。
//!
//! 文件格式与运行时 (modular_nova/modules/i18n/code/runtime.dm) 读取的一致：
//! 每个命名空间一个 JSON，内容为扁平的 {"key": "模板"}。BTreeMap 保证 key 有序，
//! 便于 diff 与 Tolgee 同步。

use anyhow::Result;
use std::collections::BTreeMap;
use std::path::Path;

#[derive(Default)]
pub struct Catalog {
    namespaces: BTreeMap<String, BTreeMap<String, String>>,
}

impl Catalog {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn insert(&mut self, namespace: &str, key: &str, template: &str) {
        self.namespaces
            .entry(namespace.to_string())
            .or_default()
            .insert(key.to_string(), template.to_string());
    }

    /// 合并已存在目录里的条目（保留已被 rewrite 改写、源码中已不再是字面量的 key）。
    /// 重同步（合并上游后重跑）时必需：否则已改写字符串的 key 会从目录里消失。
    ///
    /// 只合并**本次抽取已产出的命名空间**：其它文件（tgui.json 归 tgui-catalog.mjs 管、
    /// 手维护 `_state_words.json` 等）不归 extract 所有，吸进来再写回会因排序/缩进
    /// 约定不同造成上万行伪 churn。
    pub fn load_dir(&mut self, dir: &Path) {
        let Ok(entries) = std::fs::read_dir(dir) else {
            return;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) != Some("json") {
                continue;
            }
            let Some(namespace) = path.file_stem().and_then(|s| s.to_str()) else {
                continue;
            };
            let Some(existing) = self.namespaces.get_mut(namespace) else {
                continue; // 非 extract 自产命名空间：不接管
            };
            let Ok(text) = std::fs::read_to_string(&path) else {
                continue;
            };
            let Ok(map) = serde_json::from_str::<BTreeMap<String, String>>(&text) else {
                continue;
            };
            for (key, value) in map {
                existing.entry(key).or_insert(value);
            }
        }
    }

    pub fn namespaces(&self) -> &BTreeMap<String, BTreeMap<String, String>> {
        &self.namespaces
    }

    pub fn namespace_count(&self) -> usize {
        self.namespaces.len()
    }

    pub fn entry_count(&self) -> usize {
        self.namespaces.values().map(|m| m.len()).sum()
    }

    pub fn write(&self, out: &Path) -> Result<()> {
        std::fs::create_dir_all(out)?;
        for (namespace, map) in &self.namespaces {
            let path = out.join(format!("{namespace}.json"));
            write_preserving_indent(&path, map)?;
        }
        Ok(())
    }
}

/// 按文件既有缩进（第二行前导空白，缺省 2 空格）序列化扁平 map 写回。
/// tgui.json（tgui-catalog.mjs）等文件是 tab 缩进，统一 pretty 会造成上万行伪 churn，
/// 与 mt 工具的「preserve each catalog's existing indentation」同款约定。
pub fn write_preserving_indent(path: &Path, map: &BTreeMap<String, String>) -> Result<()> {
    let indent: Vec<u8> = std::fs::read_to_string(path)
        .ok()
        .and_then(|text| {
            text.lines().nth(1).map(|line| {
                line.bytes()
                    .take_while(|b| *b == b' ' || *b == b'\t')
                    .collect::<Vec<u8>>()
            })
        })
        .filter(|v| !v.is_empty())
        .unwrap_or_else(|| b"  ".to_vec());
    let indent = String::from_utf8_lossy(&indent).to_string();
    let mut buf = String::from("{\n");
    let last = map.len().saturating_sub(1);
    for (i, (key, value)) in map.iter().enumerate() {
        buf.push_str(&indent);
        buf.push_str(&serde_json::to_string(key)?);
        buf.push_str(": ");
        buf.push_str(&serde_json::to_string(value)?);
        if i != last {
            buf.push(',');
        }
        buf.push('\n');
    }
    buf.push_str("}\n");
    std::fs::write(path, buf)?;
    Ok(())
}
