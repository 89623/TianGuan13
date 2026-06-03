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
- 仍未接入：verb `set name`（BYOND 命令面板编译期元数据，运行时难本地化）、纸张/签名等玩家书写内容（本就不该翻）。`browse()`/`output()`/`maptext` 的残留英文现经腿 B 的 AC 兜底（仅多词、需译文进字典）尽力翻，非逐句精确改写。
- 实际中文覆盖仍需人工校对；TGUI 当前已抽取约 4,904 条，前端运行时子集只打包已译/语义 key。
- **TGUI 自动本地化注意**：按英文原文查表，运行时无法区分「字面量文案」与「正好等于常见词的动态数据」；个别误翻把英文原文加进 `tgui/packages/tgui/i18n/localize.ts` 的 `NO_AUTO_TRANSLATE` 即全局豁免。
