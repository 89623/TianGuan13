# nova-i18n —— NovaSector 全量汉化工具链

DM 字符串抽取/改写工具（Rust，基于 SpacemanDMM 的 `dreammaker` 解析器）+ 机翻流水线。
配套运行时见 `modular_nova/modules/i18n/`，平台见 `modular_nova/tools/i18n/`（Tolgee）。

## 端到端流程

```
                          tools/i18n (Rust)
  DM 源码 ──parse(dreammaker)──▶ 抽取玩家可见字符串 ──▶ strings/i18n/en/<ns>.json (英文主目录)
                                       │                          │
                            (后续) 改写调用点为 LANG/LANGU         │ push
                                                                   ▼
   tools/i18n/mt/translate.ts ◀── 机翻预填(配 glossary) ◀──── Tolgee 平台 (modular_nova/tools/i18n)
        │                                                          │ 人工校对
        ▼                                                          │ pull
  strings/i18n/zh-Hans/<ns>.json  ◀───────────────────────────────┘
        │
        ▼
  运行时 modular_nova/modules/i18n/code/runtime.dm 按 locale 查表 + {0}/{1} 填充
```

## 常用命令（在 `nix develop` 内）

```sh
# 抽取英文主目录（首版：类型 name/desc 等变量初始化里的玩家可见文本）
cargo run --release --manifest-path tools/i18n/Cargo.toml -- \
  extract --dme tgstation.dme --out strings/i18n/en

# 机翻预填 zh-Hans 草稿（需 TOLGEE_MT_API_KEY）
TOLGEE_MT_API_KEY=... bun tools/i18n/mt/translate.ts \
  --source strings/i18n/en --target strings/i18n/zh-Hans --lang zh-Hans

# 启动 Tolgee 平台并同步（详见 ../../modular_nova/tools/i18n/docker-compose.yml 与根目录 tolgee.config.ts）
docker compose -f modular_nova/tools/i18n/docker-compose.yml up -d
bunx @tolgee/cli push    # 上传英文源串
bunx @tolgee/cli pull    # 取回校对后的译文
```

## 路线图（对应已批准计划的阶段）

- **阶段 0（当前）**：基建打通。抽取器可解析全树（实测 ~52,986 条 name/desc 类字符串）；
  运行时库 + `ui_language` 偏好 + TGUI locale 注入就绪；`ammo_workbench` 端到端汉化作样例。
- **阶段 1**：扩展抽取到 proc 体内 `to_chat` / `visible_message` / `balloon_alert` 等汇聚点；
  把内插字符串 (`Term::InterpString`) 转 `{0}/{1}` 占位符模板。
- **阶段 2**：`rewrite` 子命令——幂等批量改写调用点为 `LANG/LANGU`（分域合入，每域编译/单测）。
- **阶段 3**：运行时 AC 兜底（`fallback.dm`）+ TGUI 前端静态文本全量抽取。
- **阶段 4**：CI 持续抽取/同步；人工校对推进覆盖率至 100%；合并上游后重跑工具。

## 注意

- 目录文件放 `strings/i18n/`（`strings/` 已被 git 跟踪；`data/` 被 .gitignore 忽略）。
- 占位符 `{0}/{1}` 在机翻时会被掩码保护；HTML 标签需保留。
- `dreammaker` 为 GPL-3.0，作为独立构建工具链接可接受（本项目已 GPLv3）。
