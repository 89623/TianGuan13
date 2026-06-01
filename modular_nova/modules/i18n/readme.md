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
3. **TGUI（TypeScript）**：静态界面元素用 Tolgee；动态内容由 DM 端预本地化后经 props 传来。
4. **平台**：Tolgee 自托管（`modular_nova/tools/i18n/`）+ 机翻预填 + 人工校对。

locale 解析：
- `LANG(key, args)` —— 全服 locale（`GLOB.i18n_server_locale`），用于广播类文本
  （`visible_message` 等：一条字符串展示给多名观察者，无法按单人区分）。
- `LANGU(user, key, args)` —— 接收者 locale（玩家偏好 `ui_language`），用于定向文本与 UI。

目录文件位于 `strings/i18n/<locale>/<namespace>.json`（`strings/` 已被 git 跟踪；不可用
`data/`，其被 .gitignore 忽略）。

### TG Proc/File Changes:

- `code/modules/tgui/tgui.dm`: `/datum/tgui/proc/get_payload` —— 在 config 负载注入 `"locale"`，
  供 TGUI 读取 `config.locale`（NOVA EDIT ADDITION）。
- `tgui/packages/tgui/events/types.ts`: `Config` 类型新增 `locale: string`（NOVA EDIT ADDITION）。
- 大量 `code/**/*.dm`：由 `tools/i18n` 幂等改写工具批量将字符串字面量替换为 `LANG/LANGU`
  （分阶段进行，每个被改写文件顶部带统一标记注释）。

### Modular Overrides:

- `modular_nova/master_files/code/modules/client/preferences/ui_language.dm`:
  `/datum/preference/choiced/ui_language` —— 玩家界面语言偏好。

### Defines:

- `code/__DEFINES/~nova_defines/i18n.dm`: `LANGUAGE_LOCALE_EN`、`LANGUAGE_LOCALE_ZH_HANS`、
  `DEFAULT_UI_LOCALE`、`I18N_SUBDIRECTORY`、`LANG(key, args)`、`LANGU(user, key, args)`。

### Included files that are not contained in this module:

- `strings/i18n/<locale>/*.json` —— 翻译目录（由 Rust 工具生成 / Tolgee 同步）。
- `tools/i18n/` —— Rust 抽取/改写工具与机翻流水线。
- `tgui/packages/tgui/i18n/*.json` —— 前端静态目录。

### Credits:

- NovaSector i18n 基础设施。DM 解析复用 SpaceManiac/SpacemanDMM 的 `dreammaker` crate (GPL-3.0)。
