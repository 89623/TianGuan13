# 回合日志打包下载 (Round Logs Archive)

模块 ID：ROUND_LOGS_ARCHIVE

### 说明：

管理员下载日志时，原来的「Download Folder」会对文件夹里每个文件各发一次 `ftp()`，客户端需要为每一个文件点一次保存确认——下载一整局日志要反复确认十几次。本模块新增：

1. **「Download Folder (Archive)」选项**：在日志浏览对话框原「Download Folder」旁新增，用系统 tar 把整个文件夹（递归含子目录）打包成单个压缩包，只发一次 `ftp()`，客户端只需保存一次。原有「Download Folder」行为保持不变（逐个文件下载）。
2. **「Download Current Round Logs」管理 verb**：管理员面板一键下载当前回合的全部日志，无需进入文件浏览界面。

选项名用「Archive」而不是「ZIP」：Linux 分支产出的是 `.tar.gz`，只有 Windows 分支才是 `.zip`。

### 实现要点：

- 打包通过 `world.shelleo()` 调用系统 tar，因此要求 DreamDaemon 以 **Trusted 模式**运行（TGS 部署默认即 Trusted，见 `.tgs.yml` 的 `security: Trusted`）。用 `shelleo()` 而非裸 `shell()` 是为了拿到退出码和 stderr，失败时能给出真实原因。
  - Linux：GNU tar `-czf` 生成 `.tar.gz`
  - Windows：bsdtar `tar -a -c -f` 生成 `.zip`（Win10 1803+ 自带 `System32\tar.exe`，走 PATH 解析，不写死绝对路径）
- **tar 退出码 1 不当作失败**：当前回合的日志正在被写入，GNU/bsd tar 都会以 1 退出并提示 "file changed as we read it"，但归档本身有效。只有产物不存在才算失败。
- 打包在服务器端同步执行，超大日志文件夹会令服务器短暂卡顿，确认弹窗已注明。
- **拒绝对日志根目录 `data/logs/` 打包**：那会把有史以来每一局都打进去，服务器全程冻结。
- **归档写在 `data/log_archives/`，不在日志树内**：否则会出现在下次浏览列表里（`gz` 在 `valid_extensions` 内）、被父目录的归档递归吞进去、并被日志收集一起带走。
- 归档文件名 = 扁平化的源路径 + UTC 时间戳，不同文件夹与重复下载互不覆盖。
- **清理有两道**：发送后 30 分钟定时删除；定时器不跨重启，所以每回合首次使用时会清空整个 `data/log_archives/`。
- **路径白名单**：日志路径虽由服务器生成，但日志根可由 DreamDaemon 命令行参数 `-params` 覆盖（见 `world.dm` 的 `OVERRIDE_LOG_DIRECTORY_PARAMETER`），而 sh 的双引号并不阻止 `$()` / 反引号 / `$VAR` 展开。因此交给 shell 前先过 `^[A-Za-z0-9_./ -]+$`。
- `download_folder_as_archive()` 自己做 `check_rights_for(src, R_ADMIN)` 与 `file_spam_check()`，不依赖调用方；确认框返回后会重新校验目录仍然存在（input-stalling）。

### 核心文件 / Proc 改动：

- `code/__HELPERS/files.dm`：`proc/browse_files` —— 两处 `TIANGUAN EDIT` 标记钩子：
  - 选项列表行（`TIANGUAN EDIT CHANGE`）：追加 `"Download Folder (Archive)"` 选项；
  - switch 分支（`TIANGUAN EDIT ADDITION`）：调用模块 proc `download_folder_as_archive()`，返回 FALSE（管理员取消）时 `continue` 回到浏览界面。
  - 为什么不能完全模块化：选项列表与分支在 core 的 `browse_files()` 函数体内，DM 无运行时反射/函数体注入，必须留最小触点；逻辑本身全部在模块内。
  - 同步上游时注意：钩子按 `TIANGUAN EDIT` 标记包裹，冲突时保留标记块即可。

### 模块化覆盖：

- `modular_tianguan/modules/round_logs_archive/code/round_logs_archive.dm`：
  - `proc/prepare_log_archive_dir`（新，全局）
  - `proc/delete_log_archive`（新，全局）
  - `proc/download_folder_as_archive`（新，/client）
  - `ADMIN_VERB(download_current_round_logs)`（新）

### Defines：

- `LOG_ARCHIVE_DIR` / `LOG_ARCHIVE_LIFETIME` / `LOG_ARCHIVE_FORBIDDEN_ROOT`：单文件使用，已在文件末尾 `#undef`。

### 本模块目录外的依赖文件：

- 无（仅使用内置 proc / `world.shelleo()` / 系统 tar）

### 测试方式：

- DreamMaker 编译通过（0 errors）。
- Windows bsdtar `tar -a -c -f` 实测生成有效 .zip（递归含子目录）；GNU tar `tar -czf` 实测生成有效 .tar.gz。
- 本地起服实测：两个入口（verb / Archive 选项）均成功下载，归档内容完整（含 attack/game/debug 等实数据）；原有「Download Folder」逐文件下载行为保持正常。
- 实现前提：`shelleo()` 需要 DreamDaemon Trusted 模式（TGS 部署默认，见 `.tgs.yml`）。
- 已知注意点：Windows 资源管理器直接双击预览 bsdtar 生成的 zip 可能显示为空（bsdtar zip 与 Explorer 内置解压器的兼容性问题，zip 本身有效，解压后内容完整，7-Zip/WinRAR 预览正常）。

### 致谢：

- mohu19（作者）
