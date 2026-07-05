//! nova-i18n pseudo —— 伪 locale 生成器（qps-ploc 风格）。
//!
//! 从英文主目录 strings/i18n/en/ 生成一份「伪翻译」目录：每个值都被**可见地包裹**，
//! 但保留占位符 `{0}/{1}`、HTML 标签 `<...>` 与 BYOND 文本宏 `\the` 等结构。
//!
//! 两大用途（都**不需要任何真实译文存在**，纯靠 en 目录就能跑）：
//!
//!   1. **捕获「标识符被反查表变异」的 gameplay 回归**（根因 #1/#2 的动态出口）：
//!      伪 locale 下任何被反查/P1/边界引擎翻译的串都会变成 `⟦…⟧` 包裹形态。若某处把
//!      `name`/枚举值当标识符比较（`== "Captain"`、`switch`、`name2reagent` 建键），变异后
//!      比较 miss → 现有 DM 单元测试 / 启动流程直接挂掉 → CI 捕获，无需等中文译文。
//!      这与 `nova-i18n lint` 的**静态**标识符扫描互补：lint 挡新增、伪 locale 抓运行期实际变异。
//!
//!   2. **查漏未接通的输出路径**：伪 locale 下游戏跑一圈，凡是**没被** `⟦⟧` 包裹的英文
//!      = 没接进任何翻译通道的串（聊天/UI/statpanel…）。把「selected 中文/选项英文」这类
//!      从「玩家截图上报」变成「爬取输出 grep `[A-Za-z]{4,}` 不在括号内」工具化发现。
//!
//! 设计要点：
//!   - 包裹符用可打印的 U+27E6/U+27E7（⟦⟧），不用控制字符（rustg acreplace 的 replacement
//!     禁控制字符，见 AGENTS.md 模板引擎坑），也便于人眼/正则识别。
//!   - 占位符 `{N}` 原样保留在包裹**内部**，使插值/边界引擎仍能工作、占位符 lint 仍通过。
//!   - 不改 key、不动 tgui.json（前端有独立 auto-localize；如需前端伪化另行同步）。

use anyhow::{Context as _, Result};
use std::collections::BTreeMap;
use std::path::Path;

const OPEN: char = '\u{27E6}'; // ⟦
const CLOSE: char = '\u{27E7}'; // ⟧

/// 包裹一个英文模板：⟦ 原文 ⟧。原文整体（含占位符/标签）保留在内，结构不破坏。
/// 已是伪化形态（含 ⟦）的串幂等跳过——重跑生成器不会层层嵌套。
fn pseudo_value(en: &str) -> String {
    if en.contains(OPEN) {
        return en.to_string();
    }
    format!("{OPEN}{en}{CLOSE}")
}

pub fn run(catalog_root: &Path, locale: &str) -> Result<()> {
    let en_dir = catalog_root.join("en");
    let out_dir = catalog_root.join(locale);
    std::fs::create_dir_all(&out_dir)
        .with_context(|| format!("无法创建伪 locale 目录：{}", out_dir.display()))?;

    let entries = std::fs::read_dir(&en_dir)
        .with_context(|| format!("英文目录不存在：{}", en_dir.display()))?;

    let mut files = 0usize;
    let mut total = 0usize;
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) != Some("json") {
            continue;
        }
        let Some(fname) = path.file_name().and_then(|s| s.to_str()) else {
            continue;
        };
        let text = std::fs::read_to_string(&path)
            .with_context(|| format!("读取失败：{}", path.display()))?;
        let map: BTreeMap<String, String> = serde_json::from_str(&text)
            .with_context(|| format!("JSON 解析失败：{}", path.display()))?;

        let pseudo: BTreeMap<String, String> = map
            .into_iter()
            .map(|(k, v)| {
                total += 1;
                (k, pseudo_value(&v))
            })
            .collect();

        let json = serde_json::to_string_pretty(&pseudo)?;
        std::fs::write(out_dir.join(fname), json + "\n")?;
        files += 1;
    }

    eprintln!(
        "生成伪 locale {} → {}（{} 个命名空间，{} 条）。\n\
         用法：config 设 I18N_SERVER_LOCALE {}，启动后未被 ⟦⟧ 包裹的英文 = 未接通路径。",
        locale,
        out_dir.display(),
        files,
        total,
        locale
    );
    Ok(())
}
