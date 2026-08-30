# 回合日志打包下载 (Round Logs Archive)

模块 ID：ROUND_LOGS_ARCHIVE

### 说明：

管理员下载日志时，原来的「Download Folder」会对文件夹里每个文件各发一次 `ftp()`，客户端需要为每一个文件点一次保存确认——下载一整局日志要反复确认十几次。本模块新增：

1. **「Download Folder (ZIP)」选项**：在日志浏览对话框原「Download Folder」旁新增，用系统 tar 把整个文件夹（递归含子目录）打包成单个压缩包，只发一次 `ftp()`，客户端只需保存一次。原有「Download Folder」行为保持不变（逐个文件下载）。
2. **「Download Current Round Logs」管理 verb**：管理员面板一键下载当前回合的全部日志，无需进入文件浏览界面。

### 核心文件 / Proc 改动：

- `code/__HELPERS/files.dm`：`proc/browse_files` —— 两处 `TIANGUAN EDIT` 标记钩子：
  - 选项列表行（`TIANGUAN EDIT CHANGE`）：追加 `"Download Folder (ZIP)"` 选项；
  - switch 分支（`TIANGUAN EDIT ADDITION`）：新增 ZIP 分支调用模块 proc `download_folder_as_archive()`。
  - 为什么不能完全模块化：选项列表与分支在 core 的 `browse_files()` 函数体内，DM 无运行时反射/函数体注入，必须留最小触点；逻辑本身全部在模块内。
  - 同步上游时注意：钩子按 `TIANGUAN EDIT` 标记包裹，冲突时保留标记块即可。

### 模块化覆盖：

- `modular_nova/modules/round_logs_archive/code/round_logs_archive.dm`（位置说明：本模块按维护者要求置于 `modular_nova/modules/`，见 PR 评论；core 钩子按天关规范统一使用 `TIANGUAN EDIT` 标记）：
  - `proc/download_folder_as_archive`（新，/client）
  - `proc/cleanup_download_archive`（新，全局）
  - `ADMIN_VERB(download_current_round_logs)`（新）

### Defines：

- 无

### 本模块目录外的依赖文件：

- 无（仅使用内置 proc / 系统 tar）

### 测试方式：

- DreamMaker 516.1659 编译通过（0 errors）。
- Windows bsdtar `tar -a -c -f` 实测生成有效 .zip（递归含子目录）；GNU tar `tar -czf` 实测生成有效 .tar.gz。
- 本地起服实测：三个入口（verb / ZIP 选项）均成功下载，zip 内容完整（含 attack/game/debug 等实数据）；原有「Download Folder」逐文件下载行为保持正常。
- 实现前提：`shell()` 需要 DreamDaemon Trusted 模式（TGS 部署默认，见 `.tgs.yml`）。
- 已知注意点：Windows 资源管理器直接双击预览 bsdtar 生成的 zip 可能显示为空（bsdtar zip 与 Explorer 内置解压器的兼容性问题，zip 本身有效，解压后内容完整，7-Zip/WinRAR 预览正常）。

### 致谢：

- mohu19（作者）
