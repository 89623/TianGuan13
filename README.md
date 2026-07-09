# 天关源码（Nova Sector 下游）

本仓库是“天关”的服务端源码，基于 [Nova Sector](https://github.com/NovaSector/NovaSector) 继续开发；Nova Sector 本身是 [/tg/station](https://github.com/tgstation/tgstation) 的下游分支，使用 BYOND 引擎运行。
> 🇨🇳 简体中文说明（汉化分支）见 [README.zh-Hans.md](./README.zh-Hans.md)。

[![CI Suite](https://github.com/NovaSector/NovaSector/workflows/CI%20Suite/badge.svg)](https://github.com/NovaSector/NovaSector/actions?query=workflow%3A%22CI+Suite%22)
[![Percentage of issues still open](https://isitmaintained.com/badge/open/NovaSector/NovaSector.svg)](https://isitmaintained.com/project/NovaSector/NovaSector "Percentage of issues still open")
[![Average time to resolve an issue](https://isitmaintained.com/badge/resolution/NovaSector/NovaSector.svg)](https://isitmaintained.com/project/NovaSector/NovaSector "Average time to resolve an issue")
![Coverage](https://img.shields.io/codecov/c/github/NovaSector/NovaSector)

请注意：本仓库继承自 Nova Sector，可能包含成人向内容，不适合 18 岁以下用户浏览或使用。

Space Station 13 是一款回合制多人角色扮演游戏，背景设定在一座危险、混乱且经常失控的太空站中。玩家将在不同岗位、事件与突发状况中合作、对抗，并尝试活到回合结束。
| Website                   | Link                                                                                                                                   |
| -----------------------   | -------------------------------------------------------------------------------------------------------------------------------------- |
| How to Write a Design Doc |  [https://hackmd.io/@tgstation/BkzmU9EyK](https://hackmd.io/@tgstation/BkzmU9EyK)                                                      |
| Git / GitHub cheatsheet   | [https://www.notion.so/Git-GitHub-61bc81766b2e4c7d9a346db3078ce833](https://www.notion.so/Git-GitHub-61bc81766b2e4c7d9a346db3078ce833) |
| Guide to Modularization   | [./modular_nova/readme.md](./modular_nova/readme.md)                                                                                   |
| Guide to Mirroring        | [./modular_nova/mirroring_guide.md](./modular_nova/mirroring_guide.md)                                                                 |
| Code                      | [https://github.com/NovaSector/NovaSector](https://github.com/NovaSector/NovaSector)                                                   |
| Wiki                      | [https://wiki.novasector13.com](https://wiki.novasector13.com)                                                                         |
| Codedocs                  | [https://NovaSector.github.io/NovaSector/](https://NovaSector.github.io/NovaSector/)                                                   |
| Nova Sector's Discord     | [https://discord.gg/novasector](https://discord.gg/novasector)                                                                         |
| Coderbus Discord          | [https://discord.gg/Vh8TJp9](https://discord.gg/Vh8TJp9)                                                                               |

## 项目关系

- 天关：本仓库，对 Nova Sector 进行下游修改与维护。
- Nova Sector：/tg/station 的下游代码库，提供主要玩法、系统与 Nova 扩展内容。
- /tg/station：SS13 社区的重要上游代码库之一。

## 常用链接

| 内容             | 链接                                                                                     |
| ---------------- | ---------------------------------------------------------------------------------------- |
| Nova Sector 源码 | [https://github.com/NovaSector/NovaSector](https://github.com/NovaSector/NovaSector)     |
| /tg/station 源码 | [https://github.com/tgstation/tgstation](https://github.com/tgstation/tgstation)         |
| 天关模块化开发说明 | [./modular_tianguan/readme.md](./modular_tianguan/readme.md)                             |
| 天关镜像与同步说明 | [./modular_tianguan/mirroring_guide.md](./modular_tianguan/mirroring_guide.md)           |
| 下载说明         | [./.github/guides/DOWNLOADING.md](./.github/guides/DOWNLOADING.md)                       |
| 开服说明         | [./.github/guides/RUNNING_A_SERVER.md](./.github/guides/RUNNING_A_SERVER.md)             |
| 地图与远征       | [./.github/guides/MAPS_AND_AWAY_MISSIONS.md](./.github/guides/MAPS_AND_AWAY_MISSIONS.md) |
| 构建工具说明     | [./tools/build/README.md](./tools/build/README.md)                                       |

## 开发说明

如果你要向本仓库提交修改，请先在本地完成测试。不要在没有实际测试的情况下把改动标记为可合并状态。

如果修改的是天关下游内容，优先遵循 [天关模块化开发说明](./modular_tianguan/readme.md)，把新增内容放在 `modular_tianguan/`；只有同步、修复或整理 Nova 上游内容时，才优先参考 `modular_nova/` 的约定。如果不得不修改核心代码，请尽量保持修改范围清晰，方便后续从 Nova 上游同步。

## 编译方法

在仓库根目录运行或双击 `BUILD.bat` 即可开始构建。构建过程通常需要 1 到 5 分钟。

也可以运行 `bin/build.cmd` 进行构建。构建完成后，可以按照 [开服说明](./.github/guides/RUNNING_A_SERVER.md) 使用 DreamDaemon 启动生成的 `tgstation.dmb`。

不推荐直接使用 DreamMaker 打开工程并编译，这种方式可能导致资源缺失或构建错误，例如找不到 `tgui.bundle.js`。

更多构建方式可以参考 [构建工具说明](./tools/build/README.md)。

## 贡献指南

贡献流程和代码规范可以参考 [贡献者指南](./.github/CONTRIBUTING.md)。

如果你是第一次搭建开发环境，也可以参考 /tg/station 的开发文档：

- [tgstation Development Guide](https://hackmd.io/@tgstation/HJ8OdjNBc#tgstation-Development-Guide)
- [tgstation HackMD 文档](https://hackmd.io/@tgstation)

## 许可证

2014 年 12 月 31 日 16:38 PST 之后的代码，以 [tgstation commit 333c566b88108de218d882840e61928a9b759d8f](https://github.com/tgstation/tgstation/commit/333c566b88108de218d882840e61928a9b759d8f) 为分界，使用 [GNU AGPL v3](https://www.gnu.org/licenses/agpl-3.0.html) 授权。

该提交之前的代码使用 [GNU GPL v3](https://www.gnu.org/licenses/gpl-3.0.html) 授权，工具目录除非其 README 另有说明，也遵循对应许可证。

更多信息请查看 `LICENSE` 与 `GPLv3.txt`。

TGS DMAPI 作为子项目使用 MIT 许可证。详情见 [code/\_\_DEFINES/tgs.dm](./code/__DEFINES/tgs.dm) 文件底部，以及 [code/modules/tgs/LICENSE](./code/modules/tgs/LICENSE)。

除非另有说明，所有图标、音效等资源使用 [Creative Commons 3.0 BY-SA](https://creativecommons.org/licenses/by-sa/3.0/) 授权。
