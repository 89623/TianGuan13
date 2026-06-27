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
            let Ok(text) = std::fs::read_to_string(&path) else {
                continue;
            };
            let Ok(map) = serde_json::from_str::<BTreeMap<String, String>>(&text) else {
                continue;
            };
            for (key, value) in map {
                self.namespaces
                    .entry(namespace.to_string())
                    .or_default()
                    .entry(key)
                    .or_insert(value);
            }
        }
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
            let json = serde_json::to_string_pretty(map)?;
            std::fs::write(&path, json + "\n")?;
        }
        Ok(())
    }
}
