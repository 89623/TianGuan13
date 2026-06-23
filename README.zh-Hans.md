## Nova Sector（/tg/station 下游汉化分支）

> English: see [README.md](./README.md).

本仓库是 [NovaSector](https://github.com/NovaSector/NovaSector)（/tg/station 的下游 fork，基于 BYOND 引擎）的**简体中文汉化分支**，在上游内容之上叠加了一套全量本地化系统，并定期合并上游保持同步。

**请注意：本仓库包含成人/露骨内容，不适合未满 18 周岁者。**

## 汉化 / 本地化（i18n）

绝大多数玩家可见文本——聊天、检视（examine）、TGUI 界面、公告、命令面板等——都已接入本地化系统。通过全服配置项即可切换语言：

```
# config 中设置（默认 en）
I18N_SERVER_LOCALE zh-Hans
```

`en`（默认）时整条翻译层 **no-op**，零开销、零行为变化；设为 `zh-Hans` 后服务端与 TGUI 前端统一显示中文。

- **译文目录**：`strings/i18n/<locale>/*.json`（扁平 JSON，可导入 Crowdin / Weblate / Lokalise 等在线本地化平台校对、再导回）。
- **架构与工具链**：抽取（extract）/ 改写（rewrite）/ 重同步（resync）/ 机器翻译均为仓库自带工具，命令手册见 [`tools/i18n/README.md`](./tools/i18n/README.md)。
- **模块手册与文件地图**：[`modular_nova/modules/i18n/readme.md`](./modular_nova/modules/i18n/readme.md)。
- **覆盖状态、排查规律与已知陷阱**：仓库根的 [`AGENTS.md`](./AGENTS.md) 的 i18n 章节（每发现一条新规律即追加）。

> 实际中文覆盖仍需人工校对；机器翻译产物请以在线平台或 PR 复核为准。

## 开发与构建

构建、运行、模块化规范等通用文档（英文）见：

- [模块化指南](./modular_nova/readme.md) / [镜像指南](./modular_nova/mirroring_guide.md)
- [下载](.github/guides/DOWNLOADING.md) / [运行服务器](.github/guides/RUNNING_A_SERVER.md)

## 许可

与上游一致：见 [LICENSE](./LICENSE) 等许可文件；详见英文 [README.md](./README.md) 的 License 段。
