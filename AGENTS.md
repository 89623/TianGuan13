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
- `nova-i18n extract` —— 抽取玩家可见英文到 `strings/i18n/en/`（与 rewrite **共用 `build_template` 算 key**；合并已存在目录）。
- `nova-i18n rewrite` —— 幂等把汇聚点的字符串消息改写为 `LANG(...)`；核心文件首行加 `// NOVA EDIT - I18N CODEMOD` 标记；跳过 `#define` 宏体。已覆盖的 sink：`to_chat`/`visible_message`/`audible_message`/`balloon_alert`/`say`/`manual_emote`、examine 的 `. += "…"`、以及提示/对话框 `alert`/`tgui_alert`/`tgui_input_list`/`tgui_input_text`/`tgui_input_number`（仅改消息+标题，**不动**按钮/选项列表/返回值，以免破坏 `if(alert(...)=="Yes")` 比较）。
- `node tools/i18n/tgui-catalog.mjs extract` —— 抽取 TGUI 静态 JSX 文本到 `strings/i18n/en/tgui.json`，复用现有中文译文/术语并同步前端目录。
- 重同步（合并上游后）：`bash tools/i18n/resync.sh`。CI：`.github/workflows/i18n.yml`。

**关键规则**：
- **不要手改 `LANG("key", …)` 里的 key**——key 由内容哈希生成，由工具维护（改 key 会丢翻译）。
- 改了玩家可见英文文案后，跑 `nova-i18n extract` 刷新英文目录（CI 会检测漂移）。
- `code/__DEFINES/~nova_defines/i18n.dm`（定义 LANG/LANGU）必须在 `tgstation.dme` 里**极早**包含（已放在 `_compile_options.dm` 之后）。
- 不再提供玩家个人界面语言偏好；全服语言由 `I18N_SERVER_LOCALE` 控制，TGUI 的 `config.locale` 也跟随该配置。

**运行（NixOS）**：`nix develop` → `tools/build/build.sh` → `DreamDaemon tgstation.dmb <port> -trusted`。`librust_g.so` 由 devShell 自动软链（缺它服务端卡死）。**32 位 rust_g iconforge OOM**：客户端进大厅时 iconforge（rayon 并行）生成精灵图集会撑爆 32 位地址空间 → abort 核心转储（表现为停在大厅、服务端不刷日志，**非 i18n bug**）；`nix/byond.nix` 的 DreamDaemon 包装器已默认 `RAYON_NUM_THREADS=2` 修复。切全服中文：配置项 `I18N_SERVER_LOCALE zh-Hans`。

**翻译（Codex）**：用 `tools/i18n/mt/translate-codex.sh`（内部 `codex exec -c 'mcp_servers={}' -c 'model_reasoning_effort="low"' -s workspace-write`，禁用 MCP，输出写入 `.pending/*.codex.log`）。逐文件增量翻译，保留 `{0}` 占位符与 HTML/DM 文本宏，套用术语表 `tools/i18n/mt/glossary.zh-Hans.json`。人工校对走**在线本地化平台**（自选——译文是 `strings/i18n/<locale>/*.json` 扁平 JSON，Crowdin / Lokalise / Weblate / Tolgee Cloud 等都能导入导出；不再用自托管 Tolgee）。

**命令手册与文件地图**：游戏/TGUI 翻译、在线平台导入导出、上游同步、构建启动等命令集中在 `tools/i18n/README.md`；**全部 i18n 文件位置（含运行时钉死的目录）一览**见 `modular_nova/modules/i18n/readme.md` 的「文件地图」。

**当前覆盖（重要，勿误解为"全部已汉化"）**：
- 已抽取到目录（可进在线平台/Codex 翻译）：约 73,700 条（含 TGUI 静态文本约 4,904 条）。
- 已接入运行时 `LANG`（译了就能在游戏里显示）：约 15,700 处**消息/提示类**调用点（含新增的 alert/tgui_* 对话框约 2,093 处）。
- **name/desc 等变量类文本已接入**：`/atom/Initialize`（master_files/code/game/atoms.dm）+ runtime.dm 的 `lang_reverse_text` 反查表（英文整串→译文，仅无占位符纯串，全服 locale≠en 时生效）。**地图(.dmm) 上放置的物件/区域 name/desc 也走这条**（都过 Initialize），故无需单独抽 .dmm。
- **examine 的 `. += "…"` 已接入**（rewrite 处理 AddAssign，含 span 包裹）。
- 仍未接入：纸张/签名等**玩家书写内容**（本就不该翻）、运行期 `name = "…"` 重新赋值（仅 Initialize 期反查）、多段拼接/纯 `[var]` 拼成的消息。
- 实际中文覆盖仍需人工校对；TGUI 当前已抽取约 4,904 条，前端运行时子集只打包已译/语义 key。
- **TGUI 自动本地化注意**：按英文原文查表，运行时无法区分「字面量文案」与「正好等于常见词的动态数据」；个别误翻把英文原文加进 `tgui/packages/tgui/i18n/localize.ts` 的 `NO_AUTO_TRANSLATE` 即全局豁免。
