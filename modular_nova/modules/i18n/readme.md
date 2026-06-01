## NovaSector 全量汉化 (i18n)

Module ID: I18N

### Description:

为 NovaSector 提供全量本地化（首发简体中文 zh-Hans）的运行时基础设施。架构分四层：

1. **编译期（Rust）** `tools/i18n/`：基于 SpacemanDMM 的 `dreammaker` 解析器，把玩家可见
   字符串抽取为带位置占位符（`{0}`/`{1}`…）的英文模板，改写调用点为 `LANG/LANGU(...)`，
   产出主英文目录 `strings/i18n/en/*.json`。
2. **运行时（DM + rust_g）** 本模块 `code/`：
   - `runtime.dm`：`lang_format` / `lang_format_for` 查表与占位符填充，惰性加载并缓存整个
     locale；复用 `code/__HELPERS/_string_lists.dm` 的 json/file2text 思路。
   - `fallback.dm`：基于 `rustg_acreplace`（Aho-Corasick）的英→中兜底，接住未抽取/无法
     静态抽取的残留英文。
3. **TGUI（TypeScript）**：`packages/tgui` 的 JSX 静态文本与常见文本 props 自动查前端目录；
   源翻译放在 `strings/i18n/<locale>/tgui.json`，构建前同步到 TGUI 包内；动态内容由 DM 端预本地化后经 props 传来。
4. **平台**：Tolgee 自托管（`modular_nova/tools/i18n/`）+ 机翻预填 + 人工校对。

locale 解析：
- `LANG(key, args)` —— 全服 locale（`GLOB.i18n_server_locale`），用于广播类文本
  （`visible_message` 等：一条字符串展示给多名观察者，无法按单人区分）。
- `LANGU(user, key, args)` —— 兼容旧调用的入口；当前部署模式同样使用全服 locale。
- TGUI 的 `config.locale` 也由 `GLOB.i18n_server_locale` 注入。

目录文件位于 `strings/i18n/<locale>/<namespace>.json`（`strings/` 已被 git 跟踪；不可用
`data/`，其被 .gitignore 忽略）。TGUI 使用同一目录下的 `tgui.json` 命名空间作为源。

### TG Proc/File Changes:

- `code/modules/tgui/tgui.dm`: `/datum/tgui/proc/get_payload` —— 在 config 负载注入 `"locale"`，
  供 TGUI 读取全服 `config.locale`（NOVA EDIT ADDITION）。
- `tgui/packages/tgui/events/types.ts`: `Config` 类型新增 `locale: string`（NOVA EDIT ADDITION）。
- `tgui/rspack.config.ts`: `packages/tgui` 使用 `tgui/i18n` JSX runtime，自动本地化静态 JSX 文本；
  `tgui-panel` / `tgui-say` 保持 React 原生 runtime。
- `tools/i18n/tgui-catalog.mjs`: 抽取 TGUI 静态文本到 `strings/i18n/en/tgui.json`，复用中文目录/术语，
  并同步 `tgui/packages/tgui/i18n/*.json`（构建脚本会自动执行 sync）。
- 大量 `code/**/*.dm`：由 `tools/i18n` 幂等改写工具批量将字符串字面量替换为 `LANG/LANGU`
  （分阶段进行，每个被改写文件顶部带统一标记注释）。

### Defines:

- `code/__DEFINES/~nova_defines/i18n.dm`: `LANGUAGE_LOCALE_EN`、`LANGUAGE_LOCALE_ZH_HANS`、
  `DEFAULT_UI_LOCALE`、`I18N_SUBDIRECTORY`、`LANG(key, args)`、`LANGU(user, key, args)`。

### Included files that are not contained in this module:

- `strings/i18n/<locale>/*.json` —— 翻译目录（由 Rust/TGUI 工具生成 / Tolgee 同步）。
- `tools/i18n/` —— Rust 抽取/改写工具与机翻流水线。
- `tgui/packages/tgui/i18n/*.json` —— 前端打包目录，由 `strings/i18n/<locale>/tgui.json` 同步生成运行时子集；
  英文原文作 key，缺失时回退英文，未译静态英文不会打进 bundle。
- `tgui/packages/tgui/i18n/jsx-runtime.ts` —— TGUI JSX 自动本地化入口。

### 运行服务器 / 已知问题:

- **完整命令手册**：见 `tools/i18n/README.md` 的「命令速查」。常用入口：
  - 进入环境：`nix develop`
  - 游戏/TGUI 重同步：`bash tools/i18n/resync.sh`
  - 翻译游戏命名空间：`I18N_CHUNK=100 bash tools/i18n/mt/translate-codex.sh obj.json`
  - 翻译 TGUI：`I18N_CHUNK=100 bash tools/i18n/mt/translate-codex.sh tgui.json`
  - Tolgee 启动：`docker compose -f modular_nova/tools/i18n/docker-compose.yml up -d`
  - Tolgee 上传/拉取：`bunx @tolgee/cli push` / `bunx @tolgee/cli pull`
  - 拉取 Tolgee 后同步前端：`node tools/i18n/tgui-catalog.mjs sync`
  - 构建并启动：`tools/build/build.sh && DreamDaemon tgstation.dmb 1337 -trusted`
- **切全服中文**：配置项 `I18N_SERVER_LOCALE zh-Hans`（`config/`）。游戏文本、name/desc 反查、
  以及 `packages/tgui` 中已进入前端目录的静态文本都跟随这个全服 locale。
- **NixOS 上启动**：`nix develop` 后 `tools/build/build.sh` 编译，`DreamDaemon tgstation.dmb <port> -trusted`
  运行。`librust_g.so` 由 devShell 自动软链（缺它日志子系统会卡死，见 `nix/rust_g.nix`）。
- **32 位 rust_g iconforge OOM 崩溃（重要）**：BYOND/rust_g 在 Linux 是 **32 位**进程（地址空间
  ~3GB）。客户端进大厅时服务端用 rust_g 的 iconforge（rayon 全核并行）生成精灵图集，峰值内存会
  撑爆 32 位地址空间 → Rust OOM `abort`（核心转储，表现为**客户端停在大厅按钮界面、服务端不再
  刷日志**）。**与 i18n 无关**。修复：限制 rayon 线程数压低峰值——`nix/byond.nix` 的 DreamDaemon
  包装器已默认 `RAYON_NUM_THREADS=2`（实测稳定，可用 `RAYON_NUM_THREADS=N DreamDaemon …` 覆盖）。

### Credits:

- NovaSector i18n 基础设施。DM 解析复用 SpaceManiac/SpacemanDMM 的 `dreammaker` crate (GPL-3.0)。
