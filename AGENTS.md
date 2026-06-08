# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

NovaSector is a **downstream fork of /tg/station** (Space Station 13), a round-based multiplayer game written in **BYOND's Dream Maker (DM)** language. The frontend (TGUI) is React + TypeScript bundled with rspack. This repo carries adult content and follows tgstation's code direction, layering its own content on top in a strictly modular way (see Modularization below).

The whole game is one big DM project rooted at `tgstation.dme`, an auto-generated manifest of `#include`s. **Do not hand-edit the `BEGIN_/END_` blocks in `tgstation.dme`** — the build/CI manages file inclusion (and `code/genesis_call.dme` must remain the first include; see its comment).

## Build, run, test, lint

The canonical entrypoint is the Juke-based build script. On Linux:

```sh
tools/build/build.sh            # build everything (DM + tgui); skips steps whose inputs are unchanged
tools/build/build.sh --help     # list all targets
tools/build/build.sh tgui       # build only tgui
tools/build/build.sh tgui-test  # tgui bun tests
tools/build/build.sh lint       # tgui lint (biome + tsc)
tools/build/build.sh --ci lint tgui-test   # exactly what CI runs for tgui
```

In VSCode: `Ctrl+Shift+B` builds, `F5` builds + runs with the debugger. On Windows use `BUILD.bat` / the `bin/*.cmd` wrappers (`server.cmd`, `test.cmd`, `tgui-dev.cmd`, etc.). Building directly in DreamMaker is unsupported and errors out.

TGUI dev workflow (from `tgui/`, package manager is **bun**):

```sh
bun run tgui:dev    # hot-reloading dev server
bun run tgui:build
bun run tgui:test
bun run tgui:tsc
```

### Unit tests

DM unit tests live in `code/modules/unit_tests/` (one file per area, registered in `_unit_tests.dm`). They only run when compiled with `UNIT_TESTS` defined — uncomment `#define UNIT_TESTS` in `code/_compile_options.dm` (CI defines it automatically via `CIBUILDING`). A test run does a single full game setup → run tests → teardown.

**To run one test in isolation**, wrap its type in `TEST_FOCUS(...)` (e.g. `TEST_FOCUS(/datum/unit_test/math)`) — only focused tests execute. `code/modules/unit_tests/focus_only_tests.dm` exists for this. Assertion macros: `TEST_ASSERT`, `TEST_ASSERT_EQUAL`, `TEST_ASSERT_NOTNULL`, `TEST_FAIL`, etc.

### Linting (CI `run_linters.yml`)

CI runs **DreamChecker** (SpacemanDMM, config in `SpacemanDMM.toml`) and **OpenDream** as compile-time linters, plus a battery of Python/bash checks: grep checks (`tools/ci/check_grep.sh` **and** `modular_nova/tools/nova_check_grep.sh`), ticked-file enforcement, define sanity, trait validity, map lint, DMI tests, filedir and changelog checks. SpacemanDMM forbids relative type/proc definitions and the `:` type-override operator — cast instead.

## Modularization — the most important rule of this fork

To stay mergeable with upstream tgstation, **almost all NovaSector changes go in `modular_nova/`, not the core `code/` tree.** See `modular_nova/readme.md` (the full handbook) and `modular_nova/mirroring_guide.md`. Violating this gets PRs rejected.

- **New content** → `modular_nova/modules/<module_id>/`. Inside, separate by type: `code/` (`.dm`), `icons/` (`.dmi`), `sound/`. **Do NOT mirror the core folder structure** inside a module (`modular_nova/modules/foo/code/thing.dm`, not `.../code/modules/antagonists/...`). Non-trivial modules need a `readme.md` (template: `modular_nova/module_template.md`).
- **Overrides of core files** (overriding a core proc, adding vars to a core type) → `modular_nova/master_files/`, which **must mirror the core path** (`code/modules/mob/living/living.dm` → `modular_nova/master_files/code/modules/mob/living/living.dm`). Prefer extending via `. = ..()` over copy-pasting whole upstream procs.
- **Defines** used across more than one file → `code/__DEFINES/~nova_defines/`. Single-file defines should be declared at the top and `#undef`'d at the bottom of that file.
- **Maps**: never edit upstream `.dmm` maps directly (held to the same standard as icons). Use the **automapper** (`modular_nova/modules/automapper`, config in `automapper_config.toml`) — template automapper for rooms, simple area automapper for single items.
- **Binaries/assets**: never modify core binary files. New clothing icons go into the existing files in the `master_files` clothing section.

### NOVA EDIT comments (when core edits are unavoidable)

When you must touch a core file, mark it precisely so merge conflicts stay tractable, and log the change in the module's `readme.md`:

```dm
// NOVA EDIT ADDITION START - MODULE_ID - (optional reason)
... added lines ...
// NOVA EDIT ADDITION END

something = 2 // NOVA EDIT CHANGE - ORIGINAL: something = 1

/* // NOVA EDIT REMOVAL START - MODULE_ID - (reason)
... removed lines ...
*/ // NOVA EDIT REMOVAL END
```

Avoid multiline single-`CHANGE` edits — use a REMOVAL block + ADDITION block instead. In **modular** files don't comment out dead code, delete it (git blame exists); this rule does not apply to core/NOVA-EDIT changes.

### Modular TGUI

All TGUI lives in `tgui/packages/tgui/interfaces/` (and subdirs) — there is no separate Nova folder. **A brand-new Nova UI file must start with `// THIS IS A NOVA SECTOR UI FILE` on line 1** and needs no further edit comments. Editing an *upstream* `.tsx`/`.jsx` follows the same NOVA EDIT comment rules as DM (inline `// NOVA EDIT` or `/* NOVA EDIT */`).

## Conventions

- **Changelog**: player-facing PRs add a YAML file under `html/changelogs/` (copy `example.yml`); indent changes with **two spaces, not tabs**; valid prefixes include `bugfix`, `qol`, `rscadd`, `rscdel`, `balance`, `code_imp`, `refactor`, `imageadd`. CI checks this.
- **Indentation**: `.dm`, `.json`, `.md` use **tabs**; everything else (including JS/TS via biome) uses spaces. See `.editorconfig` and `biome.json`.
- **Security-sensitive DM** (from `.github/guides/STANDARDS.md`): treat all player input as malicious; re-validate context *after* any input/prompt resolves (input-stalling exploits); parameterize SQL queries and use `format_table_name()`; never `locate(ref)` without scoping to a list; validate all Topic href calls. New player-facing UIs must be TGUI.
- More guides live in `.github/guides/` (STYLE, STANDARDS, MAPS_AND_AWAY_MISSIONS, TICK_ORDER, HARDDELETES, atomization, etc.).

## Code layout (orientation)

- `code/` — core tgstation DM. Key subdirs: `controllers/` (subsystems & the master controller), `datums/`, `game/`, `modules/`, `__DEFINES/`, `__HELPERS/`, `_globalvars/`.
- `modular_nova/` — all NovaSector code (`modules/`, `master_files/`, `tools/`).
- `tgui/packages/` — frontend (`tgui` interfaces, `tgui-core`, dev/bench/sonar servers).
- `_maps/` — map definitions and map configs. `config/` — server config. `tools/` — Python/bash/C# tooling for CI, mapping, icons, changelogs.

## 国际化 / 汉化 (i18n)

本仓库带一套全量本地化系统（首发简体中文 zh-Hans）。模块手册：`modular_nova/modules/i18n/readme.md`。

**运行时（DM）**：`LANG("key", args)` 用全服 locale（`GLOB.i18n_server_locale`）；`LANGU(user, "key", args)` 保留为兼容入口，但当前同样回落到全服 locale。模板用位置占位符 `{0}/{1}…`，按 locale 查表后填充（缺失回退英文）。目录文件在 `strings/i18n/<locale>/<namespace>.json`（**不可用 `data/`，被 .gitignore 忽略**）。TGUI 源目录统一放 `strings/i18n/<locale>/tgui.json`，由 `tools/i18n/tgui-catalog.mjs sync` 同步运行时子集到 `tgui/packages/tgui/i18n/<locale>.json` 给前端打包；`packages/tgui` 的 JSX 静态文本经 `tgui/i18n` runtime 自动查前端目录。

**工具（Rust，`tools/i18n/`，基于 SpacemanDMM 的 dreammaker 解析器）**：
- `nova-i18n extract` —— 抽取玩家可见英文到 `strings/i18n/en/`（与 rewrite **共用 `build_template` 算 key**；合并已存在目录）。**另含 flavor pass**：把白名单 `strings/` 数据文件（tips/ion_laws/junkmail…）逐字抽进 `strings.json` 命名空间（保留 `@pick`/`@`/HTML token；排除口音表/人名/词频/生成器）——使数据文件与 sink/SINK_VARS 走**同一目录**。`SINK_VARS`（type 变量白名单）除 name/desc/message/title/flavor_text 外，还含 `description`（试剂等用此非 desc，曾完全漏抽）、`taste_description`、`display_name`、`wiki_desc`、`war_declaration`、`explanation_text`、`cure_text`/`spread_text`，以及 ② 类经 to_chat 发出的整条消息 type 变量 `gain_text`/`lose_text`/`playstyle_string`（多为 `span_*()` 包裹，抽内层文本，靠聊天 AC 子串层显示）。
- `nova-i18n rewrite` —— 幂等把汇聚点的字符串消息改写为 `LANG(...)`；核心文件首行加 `// NOVA EDIT - I18N CODEMOD` 标记；跳过 `#define` 宏体。已覆盖的 sink：`to_chat`/`visible_message`/`audible_message`/`balloon_alert`/`say`/`manual_emote`、examine 的 `. += "…"`、以及提示/对话框 `alert`/`input`/`tgui_alert`/`tgui_input_list`/`tgui_input_text`/`tgui_input_number`（仅改消息+标题，**不动**按钮/选项列表/返回值/`as type in list`，以免破坏 `if(alert(...)=="Yes")` 比较。注：`input()` 是 dreammaker 的 `Term::Input` 不是 `Call`，工具在 `visit_expr` 专门处理）。
- `nova-i18n extract` 还**通用抽任意 proc 的句子型 `return` 字面量**（多词 + 首字母大写 + 无占位符；覆盖「proc 返回玩家可见整句、字面量不在 sink 调用处（经 to_chat/alert 变量参数发出）、rewrite 够不着」长尾——穿梭机/天气/投票/实验提示等；靠聊天 AC 子串层显示）；以及**安全 verb 命令面板名**（首字母大写显示名，自动排除 `.click`/`body-chest`/`quick-equip` 等 keybind/宏按名调用标识符——改名会断快捷键）。
- `nova-i18n verbs --locale zh-Hans` —— **编译期**把核心安全 verb 的 `set name = "X"` 字面量原地换成译文（含 ADMIN_VERB 宏的 verb_name 实参）。**只换字面量、不加行内 `//` 注释**（verb 名常是宏实参/行中 token，行内 `//` 会注释掉其后实参 → 编译失败）；NOVA 标记靠文件级 CORE_MARKER。verb 名是 BYOND 编译期元数据、**唯一不能 locale 门控**的类别；内容守卫=源码原文须严格 == en（防错位/宏误改）、幂等。需先 extract + 翻译；**不在 `resync.sh` 里**（会改核心、需先有译文），手动跑；产物是**可提交的核心源码**（专属中文服，英文构建需 `git checkout` 还原）。
- `node tools/i18n/tgui-catalog.mjs extract` —— 抽取 TGUI 静态 JSX 文本到 `strings/i18n/en/tgui.json`，复用现有中文译文/术语并同步前端目录。
- 重同步（合并上游后）：`bash tools/i18n/resync.sh`。CI：`.github/workflows/i18n.yml`。

**关键规则**：
- **不要手改 `LANG("key", …)` 里的 key**——key 由内容哈希生成，由工具维护（改 key 会丢翻译）。
- 改了玩家可见英文文案后，跑 `nova-i18n extract` 刷新英文目录（CI 会检测漂移）。
- `code/__DEFINES/~nova_defines/i18n.dm`（定义 LANG/LANGU）必须在 `tgstation.dme` 里**极早**包含（已放在 `_compile_options.dm` 之后）。
- 不再提供玩家个人界面语言偏好；全服语言由 `I18N_SERVER_LOCALE` 控制，TGUI 的 `config.locale` 也跟随该配置。

**运行（NixOS）**：`nix develop` → `tools/build/build.sh` → `DreamDaemon tgstation.dmb <port> -trusted`。`librust_g.so` 由 devShell 自动软链（缺它服务端卡死）。**32 位 rust_g iconforge OOM**：客户端进大厅时 iconforge（rayon 并行）生成精灵图集会撑爆 32 位地址空间 → abort 核心转储（表现为停在大厅、服务端不刷日志，**非 i18n bug**）；`nix/byond.nix` 的 DreamDaemon 包装器已默认 `RAYON_NUM_THREADS=2` 修复。切全服中文：配置项 `I18N_SERVER_LOCALE zh-Hans`。

**翻译**：用 `bun tools/i18n/mt/i18n-mt.ts`（已 chmod +x；旧 `translate-codex.sh` 已删）。后端 `I18N_BACKEND`=codex（默认，禁用 MCP）/claude（`claude -p`）/openai（API，OPENAI_API_KEY + I18N_OPENAI_MODEL/BASE_URL，可走 DeepSeek/通义/vLLM），配置写 `tools/i18n/mt/.env`（见 `.env.example`）；codex/claude 是 agent 写文件、agent 输出写入 `.pending/*.codex.log`。优化：跨命名空间复用（默认开，I18N_NO_REUSE 关）、并发 I18N_CONCURRENCY（openai 默认 4）、分批 I18N_CHUNK（openai 400/agent 200）。逐文件增量翻译，默认 `I18N_MAX_CODEX_CALLS=0`，即单并发串行跑完整个待译队列：一批结束合并后才启动下一批；失败即停，重跑同一命令会从剩余待译继续。为省 token，Codex 中间批次用临时数字 ID，且默认只发送本批命中的术语；最终目录仍是 `strings/i18n/<locale>/*.json`。保留 `{0}` 占位符与 HTML/DM 文本宏，套用术语表 `tools/i18n/mt/glossary.zh-Hans.json`。`bun tools/i18n/mt/i18n-mt.ts terms <ns>` 可筛出术语不一致，`bun tools/i18n/mt/i18n-mt.ts translate-terms <ns>` 只让 Codex 修这些条目。人工校对走**在线本地化平台**（自选——译文是 `strings/i18n/<locale>/*.json` 扁平 JSON，Crowdin / Lokalise / Weblate / Tolgee Cloud 等都能导入导出；不再用自托管 Tolgee）。

**命令手册与文件地图**：游戏/TGUI 翻译、在线平台导入导出、上游同步、构建启动等命令集中在 `tools/i18n/README.md`；**全部 i18n 文件位置（含运行时钉死的目录）一览**见 `modular_nova/modules/i18n/readme.md` 的「文件地图」。

**当前覆盖（重要，勿误解为"全部已汉化"）**：
- 已抽取到目录（可进在线平台/Codex 翻译）：约 74,000 条（含 TGUI 静态文本约 4,904 条）。
- 已接入运行时 `LANG`（译了就能在游戏里显示）：约 16,000 处**消息/提示类**调用点（含 alert/input/tgui_* 对话框）。
- **atom name/desc 已接入**：`/atom/Initialize`（master_files/code/game/atoms.dm）+ `lang_reverse_text` 反查表（英文整串→译文，仅无占位符纯串，全服 locale≠en 时生效）。**地图(.dmm) 放置的物件/区域 name/desc 也走这条**（都过 Initialize）。
- **非 atom datum 文本（试剂/法术/研究/说明书等）经 TGUI 接入**：`get_payload`（tgui.dm，NOVA EDIT）对 `ui_data`/`ui_static_data` 跑 `lang_reverse_tree`——递归反查负载里**含空白的多词字符串**（单词跳过避免碰撞），datum 文本在 UI 里即显示译文（译了的话）。
- **标识符耦合的显示名（职业/怪癖/食物类别/精灵配件）走 TS 端而非 P1**：这些 `name`/`title` 在 TGUI 里**既是显示又是 `act()` 标识符**（如 `act('set_job_preference',{job:jobName})`、`give_quirk`）。P1 改 ui_data 值会破坏 act（多词名翻了就坏）。改法：`tgui-catalog.mjs` 的 `DM_LABEL_SOURCES` 把这些 DM 名读进 `tgui.json` 前端目录——**已接**：food 全局列表、jobs.dm 的 `#define JOB_X "…"`（职业/部门）、`code/datums/quirks` 的 `name`、`sprite_accessories.dm`（发型/渐变…）、`code/modules/language`（语言名）、`code/modules/loadout/categories`（配装物品名，按 item_path 选=安全）、species_types（物种名；`addText` 已全局剥 `\improper`/`\proper` 宏使键与运行时对齐）。→ TS 端 auto-localize **只翻显示**（act 用原英文值，安全；TS 无多词门槛单词也翻）；运行时 `lang_reverse_phrase_tgui`/`GLOB.i18n_tgui_strings`（runtime.dm，读 en/tgui.json key 集）让 **P1 跳过 tgui 目录里的串**（不动数据=保住标识符，防多词名被改坏）。**零上游 .tsx 改动**，上游合并友好；唯一耦合是 `DM_LABEL_SOURCES` 钉的源路径（上游重命名→静默少翻，改路径即可）。**加新面只需在 `DM_LABEL_SOURCES` 加一行**。**反派名待接**（散在 antagonists 各处，整目录抽混入海量目标/技能名，需专门源）。
- **examine 的 `. += "…"` 已接入**（rewrite 处理 AddAssign，含 span 包裹）。
- **关键 datum 家族的 name/desc 在创建时反查（P1b）**：`/datum/reagent`、`/datum/action`、`/datum/quirk` 的 `New()` 内联 NOVA EDIT 反查 name/desc（用全量 `lang_reverse_text`，覆盖**聊天里 `[试剂名]` 等单词类插值**——P1 的 TGUI 多词门槛漏掉的）。locale==en 时仅一次比较，零开销。
- **表情（emote）已接入（P4）**：`/datum/emote/New()`（emotes.dm，NOVA EDIT）反查 name 与全部 message 形态变量（默剧/外星/AI/机器人/猴/动物/`message_param` 等）；抽取器 `SINK_VARS` 已增列这些变体，`message_param` 译文须保留 `%t`。emote 每类型仅 New 一次。**聊天里最高频的可见文本之一。**
- **气体/疾病/材料 name/desc 已接入（P5）**：gas 经 `SSair.Initialize()` 遍历 `GLOB.meta_gas_info` 反查（gas datum 从不实例化，且 `meta_gas_info` 是 GLOBAL_LIST_INIT 早于 `i18n_cache`，故放 SS Init）；disease 经新增 `/datum/disease/New()`；material 经 `initialize_material`。覆盖聊天里这些家族的单词类名。
- **`strings/` flavor 数据文件已并入主目录**（取代旧的平行副本方案）：`extract` 的 flavor pass 把白名单文件抽进 `strings.json`，运行时在 load 处反查落地——`.json` 经 `load_strings_file`（_string_lists.dm）跑 `lang_reverse_tree`，`.txt` 经 `world.file2list`（type2type.dm）逐行 `lang_reverse_phrase`（均 NOVA EDIT，gated locale≠en，多词门槛）。译文填进 `strings/i18n/<locale>/strings.json` 即生效（tips/ion_laws/junkmail/抗体/伤痕描述等）。**无需运行时白名单**：只有被抽进目录的 flavor 会被改写，names/口音表/词频表天然 no-op。
- **AC 子串兜底层已挂接（腿 B）**：`lang_fallback_apply`（fallback.dm，rustg Aho-Corasick）字典从内存反查表自动构建——**仅多词短语**（单词排除避免子串误伤），可选合并人工 `strings/i18n/<locale>/_fallback.json`。挂接点（全服 locale≠en）：browse（`browser.dm` 的 `get_content`）、状态栏（`statpanel.dm` 的 `set_status_tab` —— 顶部 `global_data` 与角色 `other_str` 均过 `i18n_localize_stat_list` 本地化副本，不动点击链接）、大厅/逃逸菜单 maptext（maptext 不被抽取，phrases 需进 `_fallback.json`）。已建 `strings/i18n/zh-Hans/_fallback.json` 起步清单（覆盖这些未抽取但已挂 AC 的静态短语）。**聊天**（`to_chat`/`to_chat_immediate`）的 AC 额外受 config **`I18N_CHAT_FALLBACK`（默认关）**控制——开后翻「英文拼进变量再 to_chat」长尾，代价是热路径每行开销 + 可能误翻。`lang_build_reverse` 已加固：`i18n_cache` 未就绪时返回空表但不缓存（防极早期调用毒化反查表）。
- **② 「拼进变量再 to_chat」的消息**：经审计绝大多数是 proc 形参 / 动态拼接 / 自定义转发 proc（字面量不在 sink 调用处），无法在 sink 点静态抽取；可抽的「type 变量整条消息」(gain_text/lose_text/playstyle_string) 已并入 SINK_VARS。这类**显示靠聊天 AC 子串层**（`I18N_CHAT_FALLBACK TRUE` 时把目录里的多词短语在 to_chat 输出里命中替换）——即 ② 的运行时归宿是 AC，不是逐句改写。
- **proc-return 长尾、标题界面、大厅按钮、maptext、旧 browse 已接（P7，本轮补齐）**：① 任意 proc 的句子型 `return` 由抽取器通用抽取 → 聊天 AC 显示（需 `I18N_CHAT_FALLBACK TRUE`，本服已开）；② **verb 命令面板显示名**经 `nova-i18n verbs` 编译期注入（安全子集，排除 keybind 标识符）；③ **标题界面**（`modular_nova/modules/title_screen` 的 HTML 菜单，raw browse 绕过 AC 钩子）经 `get_title_html` 末尾 `lang_localize_title_html` 专项翻译；④ **大厅按钮**（文字烤进 `icons/hud/lobby/*.dmi`）经 `master_files/.../new_player.dm` 的 `SlowInit` 全服中文换中文重绘图（核心 .dmi 不动；重绘见 `tools/i18n/lobby-buttons/`）；⑤ **maptext**（`MAPTEXT()`，不过 AC）少数标签 gated 直译；⑥ 旧 raw `browse()` 的玩家 prose 复用现成 LANG key（`/datum/browser` 包装器本就已 AC）。
- 仍未接入：纸张/签名等玩家书写内容（本就不该翻）；verb 的 **keybind/标识符**子集（`.click`/`body-chest`/`quick-equip` 等，按名被快捷键/宏调用，改名会断，故只译首字母大写显示名）；极少数动态拼接残留（靠聊天 AC 兜底）。
- 实际中文覆盖仍需人工校对；TGUI 当前已抽取约 4,904 条，前端运行时子集只打包已译/语义 key。
- **TGUI 自动本地化注意**：按英文原文查表，运行时无法区分「字面量文案」与「正好等于常见词的动态数据」；个别误翻把英文原文加进 `tgui/packages/tgui/i18n/localize.ts` 的 `NO_AUTO_TRANSLATE` 即全局豁免。

**i18n 排查规律 / 已知陷阱（每次定位到新规律就追加到这里）**：
- **【源码外文本不在目录】**抽取器只扫**源码**（`.dm`/`.tsx`）。凡运行时从源码外读入的玩家可见文本——**config 文件（`config/*.txt`）、管理员/玩家输入、DB、运行时下载/生成**——都不在目录里，反查（整串精确）与 AC（整串）都 miss，**只有恰好已进 AC 字典的子短语被替换** → 典型表现「**整句英文夹个别中文词**」（如安全等级公告：`...hostile activity 在站上。... all 通信控制台s`——`on the station`/`communications console` 是目录里的多词短语被 AC 换了，整句没换）。
  - **尤其坑（config_entry 覆盖）**：`/datum/config_entry/string/...` 的 `default = "..."` **会**被抽取进目录、可翻；**但服务器 `config/*.txt` 一旦设了同名键，运行时用的是 config 文件的值**（文案常与 default 不同）→ 把 default 译了 N 遍也不显示（运行时压根没用 default）。例：`alert_blue_upto` 的 default 在 `datum.json` 已译，但 `config/game_options.txt` 的 `ALERT_BLUE_UPTO` 才是实际公告文本。
  - **判别**：某条「明明译了却不显示」时，去 `config/` 和运行时数据里 grep 该英文；若 config 里有、而 `strings/i18n/en/` 里**没有**（或只有**不同文案**的 default）→ 即此类。
  - **修法**：config 文本**直接在 config 文件里译**（它就是运行时值、服务器专属、不归 i18n 流水线）——`config/*.txt` 被 git 跟踪，可提交；或把该 config 值并入抽取（需给抽取器加 config 源）。`priority_announce`/`minor_announce` 已有 `lang_reverse_text`+AC 钩子，故 config 值只要进了目录/`_fallback` 即整句翻。
- **【公告：插值 vs 非插值走不同路径】**`priority_announce`/`minor_announce`/`print_command_report` **非插值**（纯字面量）靠 `priority_announce.dm` 运行时**整串反查**显示（不 LANG 改写、零 churn）；**插值**（`"[X]…suffix"`）则反查（需精确整串，插值后 miss）和 AC（排除占位符）**都够不着** → 必须 LANG 改写。rewrite.rs 已对公告 sink 启用 **`interp_only` 门控**（只改插值公告）。表现：插值公告未译时整句英文夹个别中文词（同上）。
  - **【多行 `\` 续行串 codemod 漏改】**个别**跨行 `"…\<换行>…"`** 字符串 codemod 切片够不着 → 仍是字面量、不被 LANG 改写（即便已加进 sink 表）。判别：`grep` 到该 sink 调用源码跨行、以 `\` 续行。修法：源码并成**单行**让 codemod 接手；或**手接 `LANG("既有key", list(插值…))`**（key 用 `strings/i18n/en/` 里抽取已生成的那个，**勿新造**——内容哈希一致才命中）。例：安全等级公告 `code/datums/communications.dm` 的 `[等级文案]\n\nA summary…`。
- **【choiced 偏好下拉「选项显示名」走常量资源、绕过 P1，唯一通道是前端目录(tgui.json)】**角色 setup 的所有下拉（体型 body_type、角色性别 display_gender、吸引力 attraction、ERP erp_*、预览背景 background_state、entombed 套装外观…）选项由 `/datum/preference/choiced/*/init_possible_values()` 返回 → `compile_constant_data` → 前端 `serverData.choices` → `dropdowns.tsx` 渲成 `{displayText: capitalizeFirst(choice), value: choice}`。**常量资源经 `get_constant_data` 发送、绕过 P1（lang_reverse_tree 只跑 ui_data）**；且选项多为**单词**（"Male"/"Unset"/"Gay"），P1 多词门槛本就漏。**唯一翻译通道 = TS 端 auto-localize 按英文查前端目录 `tgui/packages/tgui/i18n/<locale>.json`**（`displayText`/`options[].displayText` 在 TRANSLATABLE_PROPS/OPTION_TEXT_PROPS）。所以选项 display 串必须经 `DM_LABEL_SOURCES`（`tgui-catalog.mjs`）抽进 `tgui.json`；act 回传的是 `value`（原英文标识符）、只翻 displayText=安全（同「标识符耦合显示名走 TS 端」）。**坑① capitalizeFirst**：displayText=`capitalizeFirst(choice)`，故 DEFINE 值（`MALE="male"`）的查表键是 **"Male"** 不是 "male"——body_type 的 male/female 靠 display_gender 里同名**大写字面量**覆盖，不能指望抽 body_type 的小写 define 值。**坑② 空白容差**：选项行可能 `"Dark Tiles" ,`（引号后带空格再逗号），正则用 `^\s*"([A-Z][^"]*)"\s*,?\s*$`。判别：某下拉选项不翻 → 查 choices 是否在 `DM_LABEL_SOURCES`，不在就加一行（行锚定上述正则；新加面只需一行）。
- **【TGUI 裸字符串下拉选项被翻译 → onSelected 回传中文、按英文匹配失败 → 点了没反应】**tgui-core `Dropdown` 里**字符串选项的「值」就是显示文本**（`m(o)= typeof o==="string"?o:o.value`），`onSelected` 回传的正是这个串；而调用方几乎都按**英文原文**匹配（`aug_options.find(a=>displayName(a)===回传)`、`value===style.name`，或把回传直接当标识符发回服务端 `style_name:value`/`marking_name:value`/`preset:value`）。一旦选项名进了翻译目录、被 auto-localize（`i18n/localize.ts` 的 `localizeOptions`）翻成中文 → 回传中文、英文匹配失败 → **选择静默失效**（典型：强化+ 身体部位「强化/植入/外观/标记」下拉点了没反应；选项已显中文但选不动）。**根因**：auto-localize 原来对**裸字符串选项**也整串翻译，破坏了「值=标识符」的回传契约。**修法（两层，已落地）**：① **系统层**——`localizeOption` 对**裸字符串选项一律不翻**（其值即标识符，不可改）；只翻**对象选项** `{value, displayText}` 的 `displayText`。这一改让所有此类下拉立即**可选**（未转对象的显英文但能用）。② **要中文又要能选**的下拉改用**对象选项** `{value:<英文标识符/typepath>, displayText:<可翻显示>}`——value 保持英文回传匹配、仅 displayText 过翻译（已转：`LimbsPage.tsx` 的强化/植入/内部植入/外观/标记下拉，value 用 `aug.path`/`style.name`/marking name）。**判别**：某 TGUI 下拉「显中文但点了没反应」→ 必是裸字符串选项被翻 + onSelected 按英文匹配；查该 `<Dropdown>` 的 options 是否 `string[]`、onSelected 是否拿回传去 find/比较英文。**新增可翻下拉时**：凡 onSelected 用回传值做匹配/回发的，必须用对象选项（别让 displayText 串兼当标识符）。对象选项天然安全（同 `dropdowns.tsx` 的 choiced 偏好）。
- **【`#define` 定义的选项/名字绕过 tgui-catalog 的字面量正则（mjs 无预处理器）】**前端目录 `tgui.json` 由 `tgui-catalog.mjs` 的 `DM_LABEL_SOURCES` **正则**抽取（**纯文本扫描、不跑 DM 预处理器**），故 `name = SOME_DEFINE` / `init_possible_values()` 返回 `DEFINE` 时，字面量在 `#define X "..."` 里、`name="..."` 与裸字符串选项正则**都够不着** → 该串不进前端目录 → 下拉选项/名字不翻（典型：硅基脑类型 ORGAN_PREF_*、预览视图 PREVIEW_PREF_*、语音类型 VOICE_TYPE_*、`DEATH_CONSEQUENCES_QUIRK_NAME` 等怪癖名）。**注意 Rust 抽取器相反**：它走预处理器、`name=DEFINE` 会被展开成字面量进**主目录** datum.json（故聊天里 P1b/反查能翻、且 selected 值经 P1 也能翻），所以**主目录有、前端目录没有** → 表现「**下拉 selected 显中文、但展开的选项列表全英文**」（selected 走 ui_data→P1 查主目录命中；options 走常量资源+前端目录、miss）。**修法**：给该 `#define` 文件加一条 `DM_LABEL_SOURCES`，正则抽 `#define\s+\w+\s+"([A-Z][^"]*)"`（首字母大写排除数字/小写标识 define）或定向 `*QUIRK_NAME*`。判别：下拉选项不翻但 selected 翻了 → 八成是 `#define` 值、且该 pref 的 choices 没进 `tgui.json`。
- **【职业描述运行期被拼接 antag opt-in 后缀，破坏整串反查】**`modular_nova/modules/antag_opt_in/code/job.dm` 在 `description` 末尾拼 opt-in 后缀（`description = initial(description) + " Forces a minimum of … Targetable by contractors. …"`），于是运行期 `job.description` = 基础句 + 后缀 → **整串非目录键**，偏好菜单 `lang_reverse_pref_descriptions`（assets.dm，对**常量资源** asset 跑：折叠续行制表符→整串精确反查→miss 退 AC）整串精确必 miss，长基础句 AC 也不稳 → 表现「**基础句英文（仅 AC 命中的个别词如 Captain→舰长）、后缀句中文**」（后缀各短语都在目录、单行、AC 稳命中）。**修法**：`lang_localize_job_description(job)`（runtime.dm）用 `initial(job.description)` 取回**基础句**单独精确反查（折叠后命中目录键），`copytext` 切出后缀走 AC，拼回；middleware/jobs.dm 的 `"description"=job.description` 改调它。规律同上「常量资源/拼接文本绕 P1，须在落地点按结构拆开反查」。
- **【物种「描述/背景」由 proc 返回（get_species_description/lore），返回可为裸串或 list；占位文本是变量引用】**物种浏览器的描述/背景经偏好**常量资源**展示（同样绕过 P1），来源是各物种覆盖的 `get_species_description()`/`get_species_lore()` **返回值**（非 sink/SINK_VARS）；运行时在 `species.dm` 的 `compile_constant_data` 反查落地（`lang_reverse_text_or_list`/`lang_reverse_string_list`）。三个漏抽子坑：① `get_species_description` 返回可为**裸串**（多数）或 **`list("段1","段2")`**（shadekin/abductorweak 多段）——抽取器原来只 `build_template`（只认裸串）→ **list 形态描述完全漏抽**（表现：物种名/背景已中文，唯独「描述」英文）；且运行时 `lang_reverse_text(list)` 也处理不了 list。修：抽取 description 也 `emit_list_strings` 兜底、运行时改 `lang_reverse_text_or_list`。② **占位描述/背景**（多数未写 lore 的物种 `return placeholder_description` / `return list(placeholder_lore)`）返回的是 `/datum/species` 上的**变量引用**，proc-return 抽取（build_template/emit_list_strings）**解析不出变量值** → 必须把 `placeholder_description`/`placeholder_lore` 加进 **`SINK_VARS`**（按类型变量抽其初始字面量），覆盖一片 placeholder 物种。③ 反查需英文进目录——跑 `nova-i18n extract` 刷新后才有 key。规律：**「常量资源/proc 返回的玩家可见文本」既绕过 P1 又绕过 sink 改写，必须靠『抽取器专项 + 运行时在落地点反查』两头接**。
