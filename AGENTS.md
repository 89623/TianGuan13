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
- **Maps**: never edit upstream `.dmm` maps directly (held to the same standard as icons). Use the **automapper** (`modular_nova/modules/automapper`, config in `automapper_config.toml`) — template automapper for rooms, simple area automapper for single items. See [Mapping the Interlink](#mapping-the-interlink) for the one map people keep getting this wrong on.
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

> **DM indentation is syntax — the `/* … */` REMOVAL block above is only safe at column 0, i.e. when removing whole top-level definitions.** To remove lines *inside a proc body*, use a single-line indented comment instead (`\t// NOVA EDIT REMOVAL - MODULE_ID - ORIGINAL: <the line>`). A `*/` sitting at column 0 **terminates the enclosing proc**, and every remaining body line is then parsed as a new type definition — producing dozens of misleading `duplicate definition` / `empty type name (indentation error?)` errors far from the real cause. Neither `nova-i18n extract` nor DreamChecker catches this (their parsers are more lenient); **only a real DreamMaker compile does**, so compile before you push.

### Mapping the Interlink

互联中枢（Ghost Cafe 所在的 CentCom z2）**不要**编辑 `_maps/map_files/generic/CentCom_nova_z2.dmm`。那是上游维护的文件，已恢复为上游原样，所有下游改动都活在 automapper 模板里：

- 主体改建 → `_maps/nova/automapper/templates/centcom/interlink_rework.dmm`（61×85，覆盖绝大多数改动）
- 零散单点 → 同目录下的 `interlink_*.dmm` 小模板，配置见 `_maps/nova/automapper/automapper_config.toml`

改完不需要动底图，automapper 会在开局时把模板覆盖上去。

写新的互联中枢模板时注意两点，都踩过：

- **`required_map` 必须写 `"CentCom_nova_z2.dmm"`，不能写 `"builtin"`。** `preload_templates_from_toml` 在每个 `LoadGroup` 内部都会调用，而 `"builtin"` 的判定看的是站点地图、不看当前组，于是会在**基础 CentCom** 那一组就匹配上——那时 CentCom 只有一层，`coordinates[3] = 2` 直接越界，而**一次越界会中断整个模板循环，后面所有模板静默消失且不报明显错误**。
- `coordinates` 第三项是 `levels_by_trait("CentCom")` 的**索引**：1 = 基础 CentCom，2 = 互联中枢（由 `modular_nova/modules/mapping/code/interlink_helper.dm` 在 `..()` 之后加载）。

**改完必须真起一局验证**，只编译不算数：模板是运行时加载的，不进 `.dmb`，编译永远是绿的。看 `runtime.log` 里的 `AUTOMAPPER: Successfully loaded map template ...` 条数对不对、有没有 `bad turf` 或 `index out of bounds`。

> 这张图曾被存成**普通 DMM 而非 TGM**，导致网格区每行都与上游不同、`mapmerge2` 完全失效，git 层面永远无法有意义地合并。副作用是绘图者基于过期副本整份保存时，会把上游的类型重命名**覆盖回旧路径**——迁移时发现了三处这样的死路径（`/turf/open/floor/pod/light`、`/obj/item/food/grown/poppy/geranium`、一个裸 `/area`），其中地板那处会让 turf 建不出来、退化成 space。用地图编辑器前请确认它按 TGM 保存。

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

全量本地化（首发 zh-Hans）。模块手册 `modular_nova/modules/i18n/readme.md`（含「文件地图」）；命令手册 `tools/i18n/README.md`。**全服语言由 config `I18N_SERVER_LOCALE` 控制；locale==en（默认）时所有翻译层 no-op。**

**运行时（DM）**：`LANG("key", args)` 按全服 locale 查 `strings/i18n/<locale>/<ns>.json`，位置占位符 `{0}/{1}`，缺失回退英文。**目录 key = 内容哈希，勿手改**（改 key 丢翻译）。改了玩家可见英文文案要跑 `nova-i18n extract` 刷新英文目录。`i18n.dm`（定义 LANG）必须在 `tgstation.dme` **极早**包含。运行时分层（均 gated locale≠en）：
- **P1（TGUI 负载反查）**：`get_payload`→`lang_reverse_tree`/`lang_reverse_phrase_tgui`（tgui.dm）对 `ui_data`/`ui_static_data` 的**多词字符串**反查（单词跳过防碰撞）；exact miss 且多词再过边界模板引擎。`i18n_payload_skip_keys`（id/buttons/列表等 act 标识符 key）整列表不反查。
- **反查表**：`lang_reverse_text`（整串精确、全量含单词）；`build_i18n_cache` 合并 locale 目录**所有** `*.json`，含手维护反查文件（en+zh 同 key）`_state_words`/`_fallback`(zh-only AC)/`_cargo_groups`/`_examine_tags`/`_paper_blanks`/`_root`/`_wires`(WIRE_* define 值：wires ui_data 显示字段反查、act 走 color)/`_templates`(运行期拼接 `{0}` 模板：DNA vault 报告行、电路板 `(Machine Board)` 后缀名、SM 完整性播报——边界模板引擎按锚命中) 等。`lang_unreverse_text` = zh→en（act 回传容错：`map[x] || map[lang_unreverse_text(x)]`）。
- **AC 子串兜底**（`lang_fallback_apply`，fallback.dm，rustg Aho-Corasick，**仅多词**）：挂 browse/状态栏/公告/maptext；聊天另受 config `I18N_CHAT_FALLBACK`（默认关）。AC 是**最短匹配**会把长句拆碎 → 长句在落地点先整串反查（`lang_localize_chat_sentence`）。
- **边界模板引擎**（`template_match.dm`）：目录已译 `{0}` 模板在输出边界整句命中（AC 锚→findtext 验证→捕获实参递归本地化）；挂 `lang_fallback_apply` 内、字面 AC 之前。单测 `i18n_template_match`。
- **LANG 实参链**（`lang_localize_arg`）：状态词表→`lang_pronoun`（代词/系动词 + `\the`/`\a` 冠词剥离 + `it's`/`they're` 缩写）→整串反查。文本宏（`\s`/`\he`…）由 `i18n_text_macro_regex` 剥。
- **落地反查钩子**：atom name/desc（`/atom/Initialize`；turf 另在 turf.dm；**排除 landmark**=出生点标识符）；datum 家族 New()（reagent/action/quirk/disease/material）；早于 i18n_cache 的 GLOBAL_LIST_INIT 母版表在 SS Init 补反查（gas/reagent…）；examine 显示点 `lang_reverse_text(desc)`。

**TGUI 前端**：JSX 静态文本经 `tgui/i18n` jsx-runtime `localizeProps` auto-localize（children + `TRANSLATABLE_PROPS`）按英文查 `tgui/packages/tgui/i18n/<locale>.json`（`tgui-catalog.mjs sync` 从 `strings/i18n/<locale>/tgui.json` 同步）。误翻豁免 `localize.ts` 的 `NO_AUTO_TRANSLATE`。**标识符耦合显示名**（职业/怪癖/选项/交互名，值兼 act/查表键）走 TS 端：act 回传英文 value、只翻 displayText；裸字符串下拉选项一律不翻（`localizeOption`），要中文用对象选项 `{value:英文, displayText:可翻}`。DM 名经 `DM_LABEL_SOURCES`（正则）/AST `nova-i18n labels`（choiced 下拉、类型作用域名）抽进 tgui.json。

**工具（Rust `tools/i18n/`，dreammaker 解析器）**：
- `nova-i18n extract` — 抽玩家可见英文到 `strings/i18n/en/`。覆盖：sink/`SINK_VARS`（type 变量 name/desc/message/`description`/taste_description/gain_text/lose_text/playstyle_string/singular_name/placeholder_*…）、**激进 pass**（proc 体/初值里**带句末标点**的句子，含插值模板——句末标点=排除 act/枚举/路径/SQL 标识符的安全闸）、proc 句子型 `return`、flavor 数据文件、verb 显示名、config 数据（`flavor.rs` 的 blanks/interactions）。抑制：日志/管理员 sink、`/datum/unit_test`。
- `nova-i18n rewrite` — 幂等改写 sink 字符串为 `LANG()`（to_chat/visible_message/audible_message/balloon_alert/say/manual_emote/examine `.+=`/alert/input/tgui_*；只改消息+标题，**不动**选项/返回值/`==` 比较）。核心文件首行加 `// NOVA EDIT - I18N CODEMOD`。公告 sink 走 `interp_only`（只改插值）。
- `nova-i18n labels`（AST→tgui.json）/`nova-i18n verbs`（编译期注入 verb 名，中文构建走 `build-verbs-zh.sh`、不入库）/`nova-i18n lint`（标识符碰撞门禁）/`nova-i18n pseudo`（伪 locale 查未接通路径）；`tgui-catalog.mjs extract/sync`。
- 上游合并后 `bash tools/i18n/resync.sh`（本地手动，**无 CI**）。
- 翻译：`bun tools/i18n/mt/i18n-mt.ts`（后端 codex/claude/openai，配置 `tools/i18n/mt/.env`）；术语 `glossary.zh-Hans.json`；故意保持英文白名单 `keep-english.<locale>.json`（`mark-english` 种子）；保留 `{0}`/HTML/DM 宏。

**运行（NixOS）**：`nix develop`→`tools/build/build.sh`→`DreamDaemon tgstation.dmb <port> -trusted`；`librust_g.so` 自动软链（缺它卡死）；`RAYON_NUM_THREADS=2`（防 32 位 iconforge OOM——表现停大厅、服务端不刷日志，**非 i18n bug**）。

**覆盖现状**（勿误解为「全已汉化」）：抽取 ~74k 条（TGUI ~4.9k）；运行时 LANG ~16k 处。未接：纸张书写（不该译）、verb keybind 标识符、摄像头/地图 c_tag（地图数据）、极少数动态拼接（聊天 AC 兜底）。实际覆盖仍需人工校对（在线平台导入导出扁平 JSON）。

**排查规律（先跑检测器，别凭经验逐条；新规律优先扩检测器 lint.rs/SINK_VARS/DM_LABEL_SOURCES）**：
- **检测器**：标识符被反查误翻（TGUI 蓝屏/出生错位/「按了没反应」/icon_state 中文）→ `nova-i18n lint`（扫 `==`/switch/下标位置碰撞，含目录卫生查多出占位符）+ `bash tools/i18n/pseudo-test.sh`（qps-ploc 下跑全量单测，抓运行期实际变异回归）；某路径没接通（selected 中文选项英文、漏接 raw browse/maptext/新 sink）→ `nova-i18n pseudo` + `pseudo-scan.mjs`；**生产服持续采集**（config `I18N_LOG_MISSES`，miss_log.dm）→ 经全部翻译层后残留的多词英文自动记 `i18n_misses.log`，`node tools/i18n/miss-scan.mjs <log>` 按频次聚合并自动分桶到下条①②③（口音替换词池 `*_replacement.json` 自动归「词池保英文」桶，无需处理）。抽取器漏一整类时先怀疑**遍历缺口**而非逐条补（实测 extract 的 visit_stmt 漏 ForList 分支 → 所有 for-in 循环体一个没抽，补一个分支多收 ~1400 条；rewrite.rs 同病未修，见 tools/i18n/README「已知事项」）。
- **玩家报「某控制台/公告整片英文」先查抽取器判据，别逐条补**。已踩三个**判据缺口**，每个都连坐一整类：
	- **全大写句子**：`is_loose_sentence` 曾要求「必须含小写」（原意排标识符/枚举），把 SS13 的控制台状态行、广播警报、广告词、法术咒语**整类**挡在目录外（实测 162 条，`OPERATION FAILED: CANNOT PROBE WHEN BUFFER FULL.` / `BLUESPACE ARTILLERY MALFUNCTION!`）。已放行：全大写需 ≥3 个「词」（≥2 字母），句末标点那道闸仍挡住 SQL/路径/define。
	- **关键字实参**：`priority_announce(text = "…", title = "…")`（上游 46 处这么写）在 AST 里那一项是**整个赋值表达式**，`build_template` 算出的 key 与目录对不上 → 改写器**一处都改不到**（玩家报的「紧急穿梭机公告半中半英」正是此因：整句带插值，反查要精确整串、AC 排除占位符，两条兜底都够不着，只剩 AC 认得 emergency shuttle 这种词组）。已加 `sink_arg_name` 形参名表按名对齐；名字对不上且位置上那项本身是关键字实参就整个跳过（宁可漏译不改错）。修完一次多改 182 处 / 72 文件。
	- **纸张印刷体**：`add_raw_text` 的**字面量**实参全是作者写的印刷体（每日密钥重置、核弹授权码、雇佣条款），玩家书写永远是变量；纸张渲染路径不过反查，所以只能靠 LANG 改写。已加进 sink 表（21 处）。
- **语境 sidecar 的 `#成员名` 后缀会污染命名空间**：`namespace_for` 曾直接 `split('/').next()`，遇到全局 proc（类型路径为空）的 `#atmos_scan()` 就把它当成命名空间 → 凭空生出 **400 个 `#xxx().json` 目录文件**，且 key 前缀跟着变、已有译文全部对不上。`namespace_for` 里已先剥 `#`。**判别信号：`strings/i18n/*/` 下冒出大量带 `#` 或 `()` 的 json 文件、`lint` 告警数从个位数跳到几百条「陈旧条目」。** 收拾时记得 `git clean` 两个 locale 目录都要扫（迁移步骤会把坏 key 同时写进 zh）。
- **生造咒语音译 = 帮倒忙**：巫师/异端法术的 `invocation` 分两类——**元音脱落的英文**（`BR'NG F'RTH TH'M T' M'.` = Bring forth them to me）读得懂，该译；**生造语**（`AULIE OXIN FIERA!` / `NOUK FHUNMM SACP RISSKA!` / `TARCOL MINTI ZHERI!`）本就无义，音译成「奥利·奥克辛·菲拉」既没信息，又毁掉玩家「听见这句 = 有人放了 knock」的辨识线索。生造语进 `keep-english`（同拟声词规则）。
- **「目录已译却显英文」先归类**：① **路径绕过 P1/sink**（静态 JSON asset `/datum/asset/json/*`、screentip maptext、非 sink 发送点如 `radio.talk_into`、运行期拼接/插值句、`print_command_report`）→ 落地点补反查（`lang_reverse_text`/`lang_localize_display_name`/`lang_fallback_apply`/`lang_localize_job_description`，注意同一文本多条渲染路径各自接）；② **没进目录**（源码外 config 数据、`new /datum/stack_recipe("title",…)` 构造参数、`#define` 值、`+" (Alt)"` 拼接名、proc-return 插值）→ 抽取器加源 或 手维护 `_<feature>.json`（稳定小集合）；③ **partial/bad MT**（grep zh 目录确认 zh 值本身含英文）→ 改译文；④ **陈旧构建**→重编。
- **标识符耦合（值兼 act/查表键/比较）一律保英文**（登记统一改 `strings/i18n/policy.json`——三端策略单一来源，DM `i18n_payload_skip_keys`/TS `NO_AUTO_TRANSLATE`/Rust `identifier_dot_procs` 都从它加载，lint 校验它；改完跑 `tgui-catalog.mjs sync` 刷前端副本）：服务端发的字符串列表进 `payload_skip_keys`（否则下拉**中英混排** + 发送/路由失败）；前端查英文常量表（MATERIAL_ICONS…）的发英文 `id`；UI 回传译名查英文键表用 `lang_unreverse_text` 兜（chem dispenser/cargo…）；`. +=` 在 update_overlays/StripMenu/key_name 等 proc 是 icon_state/act 键 → `is_identifier_dot_proc` 黑名单。判别：某「选择/发送」功能失效 + 下拉中英混排 → 服务端列表被 P1 译了多词项。
- **「键同时是显示文本」的字段，绝不能靠「假设 P1 不会翻它」**——必须把键挪进 `payload_skip_keys` 里已有的字段名（`id` 最省事），显示另发一份。地图投票踩过：选项键放在 `"name"` 里（`name` 不在跳过名单），多词 map_name（`Delta Station`/`Ice Box Station`）被 P1 译成中文 → act 回传中文 → `choices[中文]++` 建幽灵条目 → 真键**永远 0 票**、结束换不了图。**判别信号极其锐利：单词选项正常、多词选项失效**（`MetaStation`/`NebulaStation` 能投，`Delta Station` 不能）→ 一定是 P1 的多词反查动了 act 键。注意这类 bug 常由「往目录补词」引入（该案是补 17 个站点名进 `_map_names.json` 那次），改词表时要想一遍「这些词会不会正好是某处的 act 键」。另外**计票/查表侧应拒绝未知键**（`if(!(x in choices)) return`）而不是无条件 `++`，否则脏值会静默污染数据结构、把根因藏起来。
- **`payload_skip_keys` 是「整子树」跳过，会连坐纯显示字段**（→ 整个面板动态内容全英文）。典型：`items` 在跳过名单里（因为 `name` 是 `act('buy')` 的回传键），于是同一条目里的 `desc`/`tooltip` 也一并不反查——绑架者终端 12 件装备名+9 条描述**目录里全有译文却全显英文**就是这么来的。**判别：某 TGUI 面板「静态 JSX 都翻了、动态列表项全英文」→ 查该列表的键在不在 `payload_skip_keys`**（`grep` policy.json；别去查目录，目录里有译文会误导你以为已接通）。修法三件套：① DM 落地点显式 `lang_reverse_text(name/desc)`；② 另发一个英文 `id` 字段专供 act，前端 `item.id ?? item.name`（同 `Fabrication/Types.ts` 的 MATERIAL_ICONS 套路）；③ DM `ui_act` 用 `AG.name == x || AG.name == lang_unreverse_text(x)` 兜老客户端。**别直接把键从 `payload_skip_keys` 删掉**——那会让 act 回传值一起被译，功能直接坏。
- **碎片/连接词/状态词**：examine 的 `english_list` 连接词改顿号（**多处独立**，grep `english_list(` 逐处）；状态词/标签词/力量词/食物类别等有限集进 `_state_words`/`_examine_tags`/`_root`（落地点显式 `lang_reverse_text`，单词类天然不污染全局）。examine 残留多是**生成器**（english_list/bitfield_to_list/sink 漏网）而非个别串。
- **同一专名多个译名 = 术语表匹配大小写敏感，不是术语表漏收**：DM 里同一专名有两套写法——datum 显示名首字母大写（`Multiver`），obj 的 name/desc 按 SS13 惯例全小写（`multiver bottle`、`A small bottle of multiver.`）。术语表通常只收得到大写那条，`sourceTermPattern` 从前大小写敏感 → 小写那半**永远命中不了术语提示**，MT 每次现编 → 一个试剂六七种叫法（实测 syriniver 6 种、multiver 7 种）。**判别信号：`grep -i` 目录能查到同一英文的大小写两种写法，而术语表里只有一条。** 已改为大小写不敏感（`tools/i18n/mt/i18n-mt.ts` 的 `sourceTermPattern`，`iu`），一次把 `terms` 检出量从 1314 抬到 4456。两个例外必须保留大小写敏感：**全大写缩写**（AI/ID/NT，小写形式是别的词）与 `CASE_SENSITIVE_TERMS`（换个大小写就是普通英文词：Straight/Cream/Cook/Criminal/robust/byond…，否则 "ice cream" 被要求译成奶油）。**玩家报「译名不统一」时不要手改那几条**——先跑 `bun tools/i18n/mt/i18n-mt.ts terms` 看该词全部渲染点（实际数量通常是玩家报的两倍），定规范译名进 glossary（带 `note` 说明小写形式同此译名），再统一改全部条目。
- **一词多义靠「类型路径限定」，不靠 MT 猜**：`nova-i18n extract` 会额外产出 `strings/i18n/scopes.json`（key → 该串出现过的**完整 DM 类型路径**；覆盖 83%，缺的是 tgui.json 与手维护表这类本就没有 DM 类型的）。术语表条目因此可以按语境拆义项——`"Base": [{"scope":"/datum/reagent","zh":"碱"}, {"scope":["/area","/turf"],"zh":"基地"}, {"zh":"基础"}]`，**最长前缀命中优先，无 scope 的是兜底**，一个都不命中就不检查该词。这比往句子里猜上下文可靠：语境信号本来就在源码结构里。注意 `scopes.json` **必须放在 locale 目录之外**（与 `policy.json` 同级）——`build_i18n_cache` 会把 locale 目录里每个 `.json` 全量并进反查表，放进去等于让类型路径变成可反查的「译文」。已被 rewrite 改写的串源码里只剩 `LANG("key")`，其 scope 从**调用点**回收（`extract.rs` 匹配宏展开后的 `lang_format`/`lang_format_for`，AST 里没有 `LANG`）。**TGUI 侧暂无此机制**：tgui.json 以英文原文为 key，同一个 `"Basic"` 被化学反应室和设置面板共用，类型路径救不了，得靠按 interface 文件分域（未做）。
- **config 数据陷阱**：`config_entry` 的 `default` 进目录但**服务器 config/*.txt 设了同名键就用 config 值**（译 default 无效）→ 直接在 config 文件译。
- **maptext「模糊」= 字体/字号（非翻译）**：用打包的 Fusion Pixel 中文像素字体，**必须放 font-family 首位**（BYOND 不跨字体回退）；**字号必须整数 pt**（小数如 7.5pt→非整数 px→糊；6pt=8px/9pt=12px/12pt=16px/18pt=24px）；**runechat 字体来自外层 `.maptext` 类**（经 MAPTEXT 宏包裹）非 `.center`。skin.dmf 改完**重编**（先关服务器防 `.rsc` 锁致 icon-cutter 报 `invalid expression`；勿 `git reset --hard`，否则 `--force-recut`）。诊断渲染问题靠问玩家（无法渲染验证）。
- **输入框中文发不出** = `reject_bad_text(ascii_only=TRUE)` 拒非 ASCII（非 i18n bug）；**列表选项「少一个字」** = `tgui_input_list` 字符白名单 `[^ -耀]` 砍 U+8000 以上 CJK（已修 `￿`）→ 任何「中文少字」先查字符范围白名单。
- **Catalog entry exists but the UI still shows English** — compare the key byte-for-byte with what the runtime actually looks up. TGUI keys must be the *post-JSX-transform* string: `tgui-catalog.mjs` decodes HTML entities (`&apos;` `&nbsp;` `&ensp;` …) because `JsxText.text` keeps them raw while React does not. An entity in a catalog key is a dead key; an entity in a translation renders literally to the player. `tgui-catalog.mjs extract` warns on both.
- **按 proc 语义界定，不要按变量名穷举** — examine/`. +=` 类累加器原先靠一张手写变量名白名单，任何局部名（`how_cool_are_your_threads += "…"`）都会漏。`extract::ProcCtx` 改为按 proc 名判定 examine 家族；放宽准入时配一道整句闸门（`is_examine_sentence`），否则拼句碎片（`" and "`、`" (good)"`）会各自入目录，被 AC 层在半句处替换成语序错乱的中文。
- **TGUI 混排 children 必须整条抽成模板** — `<Box>Reduced by {n}% when infected.</Box>` 的 children 是 `["Reduced by ", n, "% when infected."]`。逐段翻会按英文语序拼回去（「减少了 2 感染病毒时的%。」），中文语序不同 → 碎片翻译必错，比不翻更糟。`tgui-catalog.mjs childrenTemplate` 整条抽成 `Reduced by {0}% …`，`localize.ts localizeChildrenTemplate` 整条查表再回填占位符；占位符数量对不上就整条保持英文，绝不回退逐段翻。抽取期的空白处理要与 JSX transform 逐字节一致（`jsxTextValue`，Babel 同款规则）。
- **TGUI 下拉的英文是设计缺口、不是漏译** — P1（`lang_reverse_phrase_tgui`）对「本身就是 tgui 目录键」的负载值**故意保持英文**，把显示交给 TS 端 auto-localize，好让 `act()` 回传仍是英文标识符；单词串（`"Assistant"`）连多词门槛都过不了。但 `localizeOption` 又对**裸字符串选项**一律不翻（`m(o)=o`，翻了回传就变中文）。两侧各自正确、合起来就是「下拉永远英文」。修法在 `localize.ts localizeDropdownProps`：运行时把裸字符串升级成 `{value: 英文, displayText: 译文}`，并按 `selected` 补 `displayText`（Dropdown 收起时显示的是 value 不是 displayText）。识别靠 `type === Dropdown` 组件标识，**不能**按「有 options prop」猜——界面里自定义组件也叫 options（AdminFax/LogViewer 是 `string[]`）。
- **可翻 prop 名清单必须单一来源** — 抽取器与 `localize.ts` 各存一份时，新增 prop 只改一边 → 「目录有键界面不翻」或「界面翻了目录没键、MT 永远漏」。已收进 `strings/i18n/policy.json` 的 `translatable_props` / `option_text_props`。`Button.Confirm` 的 `confirmContent`（满屏「Confirm?」）就是这么漏了整整一类。
- **JSX 属性里的 `'A' + 'B'` 折行拼接**：JS 求值后是一整串，运行时按整串查表，逐个操作数抽出的半句是死键。`addDisplayExpr` 对 `+` 链做纯字面量折叠（`foldStringConcat`）；含表达式的拼接（`'Tank (' + moles + ')'`）形状不可复原，**整条不抽**——同混排 children 的道理。
- **`capitalize()` 显示层把整类译文打掉** — DM 惯例「小写存、显示时 `capitalize()`」（手术名、伤口/器官/试剂名、`"[capitalize(x.name)]"` 拼句），而目录键保留源码原样的小写 → 精确反查与 AC 字典双双 miss。`lang_build_reverse` 为**多词**小写键登记首字母大写变体；单词键**不登记**（`move`/`clear`/`ready` 是标识符形态，会把 `switch("Clear")` 拖进反查面——与 P1 多词门槛、AC 多词过滤同一条安全线）。单词类仍需落地点收口。改了这条变体规则要同步 `lint.rs` 的碰撞集合，否则门禁看不见新暴露面。
- **DM 单词显示名到不了前端** — P1 对「本身就是 tgui 目录键」的负载值故意保持英文（留给 TS 只翻显示、`act()` 回传仍是英文），而单词串连多词门槛都过不了。于是 `mutation.Name` 这种「前端既显示又当标识符用」的值，译文明明躺在 `datum.json` 里却永远显英文。修法不是改 P1，是把该类型的 name 经 `labels.rs TYPE_VAR_RULES` 桥进**前端目录**（按类型路径，覆盖全部子类型、上游移动文件不失效）。判据：前端是否拿它做比较/取 ref（`m.Name === name`、`Name !== 'Monkified'`）——是则必须走这条桥，绝不能让 P1 改数据。
- **AC 自动机一律要 LeftmostLongest，默认 Standard 取最短匹配** — 这条踩过两次，第二次代价大得多。字面 AC（fallback.dm）早就换了；**模板逆匹配引擎的锚自动机漏了**，还留着一句「重叠锚被遮蔽只是少收一个候选、不影响正确性」的注释——不成立，少收的正是对的那个：`" begins to make an incision in "` 把 `" begins to make an incision in the organs within "` 整个遮住，更短的通用锚还能把两条一起遮住，于是唯一匹配得上的模板根本不进候选，整句原样留英文。所有插值句（手术每一步的可见消息、examine 拼句…）都吃这一刀。`i18n_real_catalog` 守这条。
- **tgui.json 也在全局反查表里** — 「值兼标识符的显示词就抽进前端目录、让 TS 只翻显示」这条路对**多词**成立，对**单词**不成立：`build_i18n_cache` 扫 locale 目录下**全部** .json，tgui.json 也在内，所以往里塞 `blue`/`purple`/`gold` 等于毒化整个 DM 侧的 `lang_reverse_text`（P1 有 `i18n_tgui_strings` 守卫，`lang_reverse_text` 没有）。线缆颜色这么塞过一次，被 `i18n_real_catalog` 的「**不应**进反查表」断言当场抓住。单词类显示词要么走域内表（`lang_scoped_table`），要么在 ui_data 里另发一个显示字段（线缆最终用后者：`shownColor` 继续当 CSS 颜色名与 act 值，另加 `shownColorLabel` 供前端作 label）。
- **悬空 LANG key 比不翻译严重得多** — 抽取与改写是两条独立通道，任何「让 extract 跳过、rewrite 不跳过」的规则都会产出 `LANG("obj.b045da9c")` 而目录里没这条；`lang_resolve` 兜底**返回 key 本身**，玩家看到的就是这串乱码。一次实测全仓三万余处调用里有 76 个（耳机频率表、无人机分发器、血虫技能、雇佣合同…）。`nova-i18n lint` 现在把它当**错误**扫。要回填原文：`git log -S<key> -- <file>` 找引入 commit，从 diff 的 `-` 行取字面量，用 `nova-i18n key <ns> <tpl>` 的 hash **校验**再写回（76 条里 72 条能这么自动恢复，剩下的是多行续行串，手拼后同样按 hash 验）。注意占位符按**出现次数**编号：同一个 `[employee_name]` 出现两次就是 `{0}` 和 `{1}`。
- **假数据测不出真目录的坑** — `i18n_template_match` 注合成模板验证引擎逻辑、`i18n_unreverse` 验证反查往返，两者全绿，而真目录里那条就是翻不出来（锚遮蔽只在成千上万条真锚互为前缀时才发生）。要有一个**拿真目录、按真实渲染形态**跑落地层的测试（`i18n_real_catalog`），并且**分层断言**（目录 → 引擎就绪 → 锚命中 → 裸句 → 带 span 整条），否则只知道红了不知道断在哪一层。
- **改写把字面量抬成 LANG 实参后，没有任何抽取路径认得它们** — `"The [x ? "bolt" : "screw"] is …"` 改写成 `LANG(key, list(x ? "bolt" : "screw", …))` 之后，那两个字面量既不是 sink 实参也不是累加器右值。模板译了、`lang_localize_arg` 拿实参去查却查不到 → 整句里嵌着英文（全仓 800+ 调用点）。抽取时走 LANG 实参子树，但**必须绕开下标键**（不下探 `Follow::Index`，否则 `ded["name"]` 被译、取值 miss）和**嵌套 LANG 的 key**（按 `<ns>.<hash>` 形态挡）。同样**只收多词**：单 token 实参里 act/topic/wire 键、黑板键、全大写常量浓度极高，放开一次就是 12 条高置信碰撞。
- **运行期 `X.desc += 后缀` 会连基础句一起打掉** — 拼接后整串不是目录键，精确反查整条 miss（高优先级赏金三条整段英文即此，基础句本来早就译好）。两侧都要补：抽取侧认 `X.desc/description +=`（原有累加器规则只看裸标识符），运行侧把后缀登记进 `i18n_appended_suffixes`、由 `lang_reverse_suffixed` 拆开分别反查，并让 `lang_reverse_phrase_tgui` 兜住它。接缝空白是暗礁：有的后缀源码自带前导空格，有的靠 DM 续行（`"</br>\` + 换行 + 制表符），抽取器与 BYOND 未必逐字节一致 → 测试要**照抄源码的续行写法**构造被测串（`i18n_suffixed`），别手写等价物。
- **`lang_localize_arg` 的 capitalize 兜底会撞上同形异义词** — `smell`（名词，污染物 descriptor，`#define` 不在目录）→ 兜底 capitalize 成 `Smell` → 命中动词条目「闻」→「烟细微的闻让你的鼻子发痒」。同形异义的显示词要进 `_state_words.json`（查表第一步，先于兜底）钉死词性。
- **MT 会吃掉纯 ASCII 译文里的字符** — `H.A.R.S.` → `H..R.S.`、血型 `A+` → `+`。查法：扫「译文不含 CJK、比原文短、且是原文的字符子集」，全仓一遍只有个位数，其中冠词/复数类是有意的，缩写/型号类是 bug。
- **共享常量表住在 .ts 里，`walk()` 只扫 .tsx/.jsx** — `constants.ts` 的 `GASES` 经 `getGasLabel(gas_id)` 渲染进一整排大气界面，界面文件里没有任何字面量 → 整类漏抽。按「文件+表名+字段」定点登记（`CONSTANT_LABEL_TABLES`），不整体放开 .ts（backend/logging 里的 name/label 多是标识符）；`id`/`path` 是回传标识符，永不入表。
- **上游把逻辑搬进新组件文件 = 整类落地点静默回退英文** — 上游把板条箱隐私锁重构成 `/datum/component/locked_to_account` 后，消息经**项目自定义 proc**（`deny(source, user, msg)` → 内部 `to_chat(span_warning(msg))`）下发。extract 认得这些字面量（照常进 `datum.json` 并被翻译），rewrite 却不认 `deny` 这个非注册 sink → 源码留裸英文、目录里躺着永远查不到的译文。**「目录里有、且已翻译」不等于「玩家看得到」**：同文件里 `balloon_alert` 那行照常被改写，对比之下更隐蔽。上游同步后的排查手段是拿「不再被引用的旧 key」反查其英文原文在源码里是否又以裸字面量出现（仅凭 `nova-i18n lint` 查不出——它只查悬空 key，查不出「该 LANG 而没 LANG」）。
- **同一次 rewrite 可以既漏抽又生成悬空 key** — 上游把 cyborg examine 的盖板句拆成 `var/cover_message = "…" ` + 两段 `+=` 后：基础句因是**局部变量赋值**（非 `. +=` 累加器）整条没抽 → 裸英文；而 `+=` 的 href 段被 rewrite 改成了 `LANG("mob.4b3e8678")`，extract 却因含 `<a href=…>` 跳过 → **悬空 key，玩家直接看到 `mob.4b3e8678` 这串乱码**。两个方向的缺口出现在**相邻三行**里。`nova-i18n lint` 只抓得住后者，前者要靠回归门禁的裸英文反查。恢复悬空 key 的原文去 `git show upstream/master:<file>` 取（这类 key 是本次 rewrite 新生的，`git log -S` 查不到引入 commit）。
- **前端把 payload 的 `name` 拼进 act 动作串 = P1 一译按钮就哑火** — `payload_skip_keys` 只保护「值本身就是回传标识符」的键（`buttons`/`items`/`id`/`ref`…），`name` 不在其中且**本该不在**（绝大多数场合 name 就是纯显示）。危险形状在 TS 侧：``gear_action: `toggle_reagent_${reagent.name}` ``——P1 把 `name` 译成中文后回传 `toggle_reagent_生理盐水-葡萄糖溶液`，DM 侧 `action == ("toggle_reagent_" + known_reagents[i].name)` 拿英文比，永远不等 → 按钮点了没反应、无任何报错。**单词名（Epinephrine/Multiver）因多词门槛不被译而照常工作**，于是表现为「只有多词化合物坏」，极易被当成个别条目漏译。修法不是把 `name` 加进 skip keys（会让整界面回退英文），而是**另发一个 `id` 字段**（`id` 已在 skip keys 内，天然免疫）供拼动作串，`name` 继续只做显示。全仓扫法：``grep -rn '`[a-z_]*\${[a-zA-Z_.]*\.name}`' tgui/packages/tgui/interfaces/``（2026-08-13 只有机甲注射器枪/机甲睡眠舱三处）。
- **React 不渲染的 children 占了模板占位符 = 整类「目录有译文、界面永远英文」** — `<div>{text}{cond && <Divider/>}</div>` 在 cond 为假时 children 是 `[原文, false]`。`localizeChildrenTemplate` 旧实现按「非字符串 = 一个占位符」建模板，于是查的是 `…station.{0}`，目录里当然没有 → 未命中后又撞上「混排就整条保持英文」的保守分支，把它焊死。React 对 `null/undefined/boolean` 什么都不渲染，这类空位必须在建模板**之前**剔除。反派介绍 tooltip 整页英文即此（译文一直躺在 `tgui.json` 里）。判据：目录里有键有译文、但界面是英文，且该处 JSX 有 `{cond && …}` 兄弟节点。
- **「混排就整条保持英文」把「运行期整条文案 + 装饰性兄弟节点」也一起焊死** — 上一条剔掉了 `false` 空位，但只救了**末段**；真正的漏洞在保守分支本身。`<Box>{icon}{tab.name}</Box>`（配装页分类页签）、`<div>{desc}<Divider/></div>`（反派介绍非末段）、`<>{name}<span>{n} slots available</span></>`（中途加入菜单部门标题）这三种形状里，字符串是**运行期数据**、整条模板永远不可能在目录里，于是全部回退英文——而它们各自的英文原文本来就是独立目录键、译文一直躺着。判据是「同一条 tooltip 第一段英文、第二段中文」这类**同形状不同待遇**的反差（末段 `false` 被剔除后走了纯文本路径）。修在 `localize.ts localizeChildrenSegments`：模板未命中后允许逐段翻，但闸门要双重——每个非空白字符串 child 都必须**整条精确命中目录**（拼句碎片按定义不是独立键，抽取器只存整条模板），且**首字符不是小写字母/标点**（目录里确实躺着 `and give it a`、`a mindshield.` 这类碰巧能命中的续接碎片）。`localize.test.ts` 正反三条守这条。
- **拼句碎片进字面 AC 子串字典 = 从单词内部开火** — 反查表同时喂两条路：`lang_reverse_text` 的**整串精确**反查（碎片在那里无害）和字面 AC 的**子串替换**（碎片会在任意句子中间开火）。rustg 的 AC 没有词边界概念，LeftmostLongest 只管「同起点取最长」。旧闸门只要求「pattern 含空格」，于是 `"one of"→"其中一只"`（一条**没有调用点的悬空目录项**）把 `But n|one of| its eggs hatched!` 咬成「But n其中一只 its eggs hatched!」；`" and "→" 和 "`（靠首尾空格才含空格的单词碎片）污染整段 NPC 检查文本。闸门只能设在 `lang_fallback_setup` 建字典这一步（`lang_fallback_pattern_safe`：trim 后须多词；无句末标点的 ≤3 词短语若首/尾是虚词则拒收），碎片仍留在目录里供各自调用点精确查表。`i18n_ac_fragment` 守这条。
- **目录键里嵌着 HTML 标签 → 聊天落地层永远查不到** — 抽取器照抄源码字面量，标签就留在键里；而 `lang_fallback_apply_html` **按标签切块**、只把标签之间的纯文本送去查表。两种形态各需一处修：
  · **边缘标签**（整句被包住，`"<b>But none of its eggs hatched!</b>"`、`"<span class='notice ml-1'>Subject contains no neuroware…</span>"`）→ `lang_build_reverse` 登记**剥标签变体键**（值同样剥标签，外层标签由切块器自己保留）。与既有的剥宏/去转义/首字母大写变体同一条流水线、同一条「只做多词」安全线。
  · **句中内联标签**（`examine_text = "There is a sticker displaying the <b>Chief Engineer's SEAL OF APPROVAL.</b>"`）→ 切成两个半句，谁都不是键 → `lang_fallback_apply_html` 前置一遍 `lang_localize_inline_runs`：跨内联标签把整段文本连起来整段精确查表，命中才替换、未命中原样交还切块器（不新增误翻面）。含 `<script>/<style>/<textarea>` 的文档整个跳过这条前置 pass。
    **run 必须是元素的「内容」，不能跨过该元素自己的边界标签**：只靠 depth 计数不够——run 从外层 `<span class='notice'>` **之前**就开始的话，该 span 会被吸收进 run、它的闭合又把 depth 抵平，于是整条替换把 span 一起吃掉、聊天配色全丢。判据要加一条：run 至今没有任何非空白文本时遇到的**开标签**属于外壳，让它当边界、run 从它之后重新开始。这条是 `i18n_html_tag_keys` 实测抓出来的（译文正确但 span 没了），静态看代码看不出来。
  症状特征：整句英文，且句中某个专有名词被单独译成中文（AC 只咬中了那一个词组）。`i18n_html_tag_keys` 守这两条。
- **`examine_tags` 是全仓唯一「assoc 键即文案」的合法形状** — 该 proc 返回的 list，**键**是检查面板上那颗标签的文字、**值**是它的悬停 tooltip。抽取器原本只抽值，于是直接写字面量当键的写法整类漏掉（`examine_list["partially EMP blocking"] = …`）；用 `EXAMINE_TAG_*` 宏的那批因为宏本身是标签文字而早就在目录里，对比之下更隐蔽。这条只能开在本 proc 语境内——别处的下标键一律是程序查表用的键名，`visit_expr` 对 `Follow::Index` 的整支跳过必须保留。
- **proc 形参默认值是 SINK_VARS 够不着的一类**（已修） — `Initialize(revive_title = "a recovered crewmember", spawn_text = "Recovered Crew", …)` 这种把玩家可见文案写在**形参默认值**里的组件（ghostrole_on_revive 等），SINK_VARS 走的是类型变量声明，一条都抽不到 → 玩家看到「你想扮演a recovered crewmember吗？」。放开时的误伤担忧是真的（`name`/`message` 作形参名时标识符浓度远高于作类型变量时，`proc/f(message = "some_key")`），解法是**在 SINK_VARS 之上再加一道多词闸门**（复用 LANG 实参的 `is_lang_arg_text`），单 token 默认值一律不收。实测全仓只新增 14 条、逐条人工过目零标识符混入——**先量化再决定**，这个量级本身也证明闸门没开太大。
- **`{' '}` 被当成占位符 = 一次毒掉 90 条模板 key** — prettier 换行时到处插 `{' '}`（`The <b>Linguist</b>{' '}` + 换行 + `neutral quirk …`）。React 把它渲染成一个**字符串** child，运行时 `localizeChildrenTemplate` 会把它并进模板文本；而抽取器 `templateChildren` 原本对 `ts.isJsxExpression` 一律记 `{slot:true}` → 算出的 key 比运行时多一个 `{N}`（`The {0}{1}neutral quirk` vs 运行时的 `The {0} neutral quirk`）→ 整条模板永远查不到 → **整段回退英文**。判据/症状：整段英文，但段落里的 `<b>`/`<span>` 词是中文（它们是独立 jsx 节点、各自 auto-localize 命中）——与「AC 只咬中一个词组」的 HTML 标签类症状很像，区别在这里被译的是**元素子节点**而非任意词组。修在抽取侧：JSX 表达式里是字符串字面量（`StringLiteral`/`NoSubstitutionTemplateLiteral`）时按**文本**处理。旧的错误 key 会永远留在只增不减的目录里，新 key 需重新翻译。`localize.test.ts` 用「按源码 JSX 形状独立构造 children、断言命中真目录条目」的方式守这条（不从 key 反推，否则是循环论证）。
- **落地层的层序：整串精确反查必须排在模板引擎之前** — `lang_fallback_apply` 原本是「模板逆匹配 → 字面 AC」，没有独立的整串精确反查那一步（整句只能靠 AC 顺带命中）。于是目录里那些「三两个词 + 占位符」的**泛化骨架模板**会抢在前面把整句劫持，把捕获到的英文原样塞回中文脚手架：`It appears to {0}`→`它看起来像{0}` 把「It appears to be completely inactive. The reset light is blinking.」吃成「它看起来像be completely inactive.」；`{0} produces a {1}.`→`{0}产出{1}。` 把「Fully heals the target and produces a random coin.」吃成「Fully heals the target and产出random coin。」。**两句的整句译文一直都在目录里**，只是永远轮不到。这比不翻更难看（中文脚手架裹着英文、语序还错），而且**不能靠收紧模板锚解决**：真正该留的手术类锚（`" begins to make an incision in "`）同样以介词结尾、词数门槛也会误杀 `{0} succeeds!` 与 `Prevent {0} from escaping alive.`。正解是让最具体的证据优先——整串命中就直接返回，模板与 AC 都不再跑。症状特征：中文句式里裹着成段英文（区别于 AC 碎片类的「英文句里嵌一个中文词」）。`i18n_real_catalog` ①c 守这条。
- **模板的字面段里嵌着 HTML 标签 = 整条在聊天路径上永远验证不过（全仓 859 条）** — `lang_fallback_apply_html` **先按标签切块**，送进模板引擎的是**纯文本块**；而 `lang_tpl_match` 要求逐段 `findtext` 命中**带标签的**字面段，于是这类模板一条都匹配不上。译文早就在目录里，只是这条通道走不通。实测：15906 条已译插值模板里 859 条（5.4%）是这形状——高级健康扫描仪整页（`<span class='info ml-1'>Genetic Stability: {0}%.</span><br>`）、回合总结经济行（`There were {0} {1} collected by crew this shift.<br>`）皆在其中。解法是在 `lang_tpl_setup` 里给这类模板**额外登记一条剥标签变体记录**去匹配切块后的纯文本，外层标签由切块器自己保留、排版不丢。两条硬约束：
  · **含 `<a>` 的一律不登记剥标签变体**（71 条）：剥掉链接会把功能弄没（`<a href='byond://…'>here</a>` 是投票入口）。这批改走**整行作用域**——`lang_fallback_apply_html` 在**切块之前**先对整行跑一遍 `lang_template_apply`，那时字面段里的标签与原文逐字节对得上，zh 模板连同自己的 `<a href>` 一起填回去，链接与排版都保住。**作用域选错才是原来的死结**，不是「剥不剥标签」的取舍。整行 pass 同样让 788 条纯排版模板优先在完整形态下命中，剥标签变体退化为切块后的兜底。
  · 剥标签时**不能 trim/折叠空白**（要另写 raw 版，别复用给反查变体用的那个）：字面段靠精确 `findtext` 定位，段首那个分隔占位符与词的空格一旦被 trim，整条模板反而再也匹配不上。
  `i18n_html_tag_keys` ③④ 正反两面都守（③ 断言剥标签变体命中，④ 反向断言投票行**必须**保持英文）。
- **LANG 实参里「本身就是插值句」的那类，抽取器整段丢弃** — `collect_lang_arg_literals` 对 `Term::InterpString` **只下探内插表达式、把字面文本全丢掉**，于是 `ask_role ? "Personality requested: \[[ask_role]\]" : ""` 这种被改写抬成 LANG 实参的插值句，一个字都进不了目录：外层模板译好了、句子中间嵌着一截英文。修法是加一条平行的**模板**收集器，按 `Personality requested: {0}` 的形态入目录，运行期由整行模板引擎命中并递归本地化捕获值。安全线：**只收带占位符的模板**（永不进反查表，且要求全部字面段按序命中，比裸串反查安全得多）+「去占位符后须多词」挡掉 act/黑板键。全仓 87 条。
  连带坑：抽出的是 `Personality requested: \[{0}\]` —— DM 源码里 `\[` `\]` 是「字面方括号」的转义（否则被当成内插），而运行时是裸括号。`lang_tpl_normalize` 原本只归一 `\"` `\n` `\t` 与文法宏，**漏了这两个**，不补则字面段照样对不上、等于白抽。
- **地图里定义的 `desc` 覆盖，整类不在目录** — `.dmm` 里的 `desc = "…"` 是**实例变量覆盖**，不在任何 `.dm` 源码里，dreammaker 解析器（`nova-i18n extract`）根本看不到 → 整类漏抽。**迷惑性极强**：物体的 **name 是中文**（地图名早就手工收进 `_map_names.json`）、**desc 却是英文**，看着像「这一条漏译」，实际是「这一整类从没进过目录」；而且在 `.dm` 里怎么 grep 都找不到那句英文（线上实例：heretic.dmm 的「充满恐惧的人」）。判据：`grep -rl "<那句英文>" _maps/`。产物由 `node tools/i18n/map-descs.mjs` 生成 `strings/i18n/en/_map_descs.json`（identity 表，与 `_map_names.json` 同形态，只合并不裁剪），resync 之后跑一次。
- **P1（TGUI 负载）缺字面 AC 兜底 → 「基础句 + 运行期后缀」整段英文** — `lang_reverse_phrase_tgui` 的链是「精确反查（含 `lang_reverse_suffixed`）→ 模板引擎」，**没有 AC**。而 TGUI 负载里的追加后缀不止可枚举那种：幽灵生成器的 `flavour_text` 是`基础句` + `switch(rand(1,4))` 四选一的身世段（其中一段还带 `pick(...)` 内插），后缀根本没法手工登记进 `i18n_appended_suffixes`。**两半各自都是目录键、也都译好了**，字面 AC 的子串替换正好能分别换掉、接缝原样保留——聊天路径一直这么做，P1 少了这一步。症状：生成器菜单里「来源」是中文、「指令」整段英文（同一条负载两个字段待遇不同，这个反差就是判据）。闸门必须严：AC 是子串替换，**长度 ≥ 80 且含句末标点**（散文形态，不可能是 act 回传标识符）才放行，短值一律不走——那是标识符浓度最高的区间。
- **`span_*()` 包裹的 LANG 实参，`lang_localize_arg` 每一步都 miss** — 改写后的调用形如 `LANG(key, list(span_bold("[read_only ? "protected" : "unprotected"]")))`，运行期传进来的是 `<b>unprotected</b>`：整串既不是状态词、也不是目录键，于是中文句子里嵌着一个英文状态词（软盘的「写保护标签设置为unprotected。」）。`lang_localize_arg` 现在会剥掉**首尾包裹标签**、对内层递归本地化，命中后把标签原样套回去（加粗等排版不丢；内层已无标签，递归必然终止）。
  另一半是数据：`protected`/`unprotected` 是**单词**，被 LANG 实参的多词闸门挡掉——那条闸门不能放开（单 token 实参里 act/topic/黑板键浓度极高）。这类「同形异义状态词」的正确去处是 `_state_words.json`，它只在 LANG 实参/模板捕获这个受限范围内生效，不会污染全局反查表。
- **整句在 TypeScript 里拼 = DM 侧模板再全也没用** — 偏好菜单的个性总结 `You are ${finalString}.` 完全由 TS 拼出（`PersonalityPage.tsx`）：整串是运行期产物、永远不是目录键，而个性名是**单词**（Compassionate/Diligent…）也进不了字面 AC → 两条落地路径都够不着。顺带一提 DM 侧那条 `You are {0}.` 的锚只有 8 字符、低于 `I18N_TPL_MIN_ANCHOR`，本来也进不了模板引擎。
  修法是让它走**既有机制**：名字逐个 `translateCurrent` 查表（`/datum/personality name` 早由 labels.rs 桥进前端目录），外框写成 **children 模板** `You are <span>{finalString}</span>.` —— 抽取器收成 `You are {0}.`、运行时 `localizeChildrenTemplate` 整条查表后按中文语序回填。
  **绝不能写成 `You are {finalString}.`**：那样三个 children 全是字符串、会被并成一整条查不到的文本（与 `{' '}` 那条同一个坑）——必须把它包进一个元素才算一个占位符。连接符也要按 locale 走（中文顿号、无 "and"），否则是「甲, 乙, and 丙」。
  另一种「整列英文」的成因完全不同：**该类型的 name 从没进过任何目录**。强化+ 页的体表标记名（`/datum/body_marking`）不是 SINK_VARS 覆盖的形状、也不在 `labels.rs TYPE_VAR_RULES` 里 → `en/datum.json` 与 `en/tgui.json` 都查不到。判据一步到位：拿一个界面上的英文名去 `grep strings/i18n/en/`，**一条都没有**就是整类漏抽（对比「个别条目漏译」是目录里有键、值等于原文）。补一条 TYPE_VAR_RULES 即可，前端已是对象选项时 value 保英文、只有 displayText 被翻。
  同类：船员名单的 `title={dept + \` (${open} positions open)\`}`（`CrewManifest.jsx`）。改法一样——部门名包进 `<span>` 当占位符（自身是独立目录键、auto-localize），外框整条抽成 `{0} ({1} positions open)`。**prop 值里的 JS 拼接一律是这个坑**，`title`/`content` 这些可翻 prop 只做整串精确查表，拼出来的串永远查不到。
  prop 拼接全仓 151 处，逐处改 children 模板并不通用（`placeholder`、`Window title` 只吃字符串），所以走**抽取模板 + 运行期逆匹配**：`tgui-catalog.mjs propTemplate` 把 `` `Reading: ${x}` `` 收成 `Reading: {0}`，`localize.ts matchPropTemplate` 在精确查表 miss 之后按字面段整串逆匹配、回填捕获值。三道闸门缺一不可，且都是实测逼出来的：
  · **准入面用 sidecar 隔离**（`strings/i18n/tgui-prop-templates.json`，每次抽取全量重写、**不合并**——它是误翻面不是译文）。目录里另有 590+ 条 children 模板，它们本就走整条精确查表；把 `- {0}, the {1}`、`{0} of 12 total` 这种泛化骨架放进逆匹配面就是 DM 侧「中文脚手架裹英文」那一跤。
  · **抽取期要求锚里有实词**：字面段全是虚词/标点的骨架（`{0} from {1}, {2}`，锚只有 `" from "` 与 `", "`）实测能吃掉目录里 27 条正常整句。
  · **运行期要求捕获值像「值」不像散文**（≤60 字符、不跨句、多词时不以小写开头、末尾不吞句号）。这条只能设在运行期：抽取期看不出 `Select {0}` 的 `{0}` 将来会被喂进什么，而 `Select ` 是正经实词却又是极常见的句子开头——目录里 17 条 `Select a policy to view. These policies are…` 全靠这条挡住。
  两道闸门加完，能被劫持的目录整句从 44 条降到 0（剩余匹配全是「本身就是目录键、精确查表先命中」的良性形状）。审计手法：拿目录里所有非模板 key 逐条过一遍逆匹配引擎，看有多少被吃掉。
- **`initial(x.name)` 拼出来的列表 = 只有多词项被译的「半译列表」** — 储物袋检查的「可以容纳:」每项是 `"\a [initial(valid_item.name)]"`：`initial()` 取**英文原名**（改成显示边界翻译之后，运行期 `name` 同样是英文），整条描述又是运行期拼的、不是目录键 → 落地只剩字面 AC，而 AC 按安全线**只收多词** → 多词名（circuit board→电路板）命中、单词名（limb/beaker/bottle/assembly）整类漏掉。玩家看到的「a limb / a 电路板 / a beaker」混排就是这条界线的直接投影，很容易被当成个别条目漏译。修法：在 `set_holdable()` 用 `. = ..()` 之后**重建**该描述，逐项走精确反查（单词也能命中、且不存在 AC 的词内开火风险），命中项**丢掉 `\a` 冠词**（中文无冠词，留着就是「a 电路板」）。同理适用于任何 `initial(name)` 拼列表的地方。
- **`%VAR` 宏占位公告：模板译了、值没译** — `announcement_system.dm` 的公告模板用 `%PERSON`/`%RANK` 而非 `{0}`，整条模板早有 Nova 反查编辑，但 `%VAR` 的**值**由调用方传入英文 → 「Feng Xin Zi 已注册为 Detective」。职位名多为单词（AC 够不着）、公告整串又是运行期拼的（不是目录键），两条路径都不行，只能在替换处逐个值过 `lang_localize_arg`。**必须在 proc 内部改**：`. = ..()` 拿到的是替换完的串，无法再区分哪段是值。公告是纯显示、无 `act()` 回传，值被译不破坏任何比较。
- **按序 `replacetext` 填占位符 = 实参自吞** — `lang_interpolate` 原本按序 `replacetext("{0}")`、`replacetext("{1}")`…，于是**上一轮写进串里的实参内容会被下一轮当成模板再扫一遍**：只要某个实参的值里恰好含 `{1}`（纸张文本、玩家自定义命名、任何玩家可控串都做得到），它就会被后一个实参顶掉。已改为单趟扫描（实参写进输出后不再参与匹配），顺带省掉「模板里没有该占位符时仍白跑一遍 `lang_localize_arg` + 全串 replacetext」的开销 —— LANG 是全仓三万余处调用的热点。`i18n_interpolate` 守这条。**测试实参必须用生造词**（Zxqv 系）：locale≠en 时 `lang_interpolate` 会对文本实参跑 `lang_localize_arg`，真实英文词（`stick`/`tail`）在真目录或伪 locale 下会被译掉，断言就从「测填充逻辑」变成「测目录内容」。
- **逐字节 `copytext(s, i, i+1)` 扫描在落地层是真开销** — `lang_fallback_apply_html` 是**每条 to_chat、每个浏览器页面**的必经路径，而它的内循环 `lang_html_tag_end`（找标签结束的 `>`，且要跳过引号里的 `>`）原本按字节推进，每字节分配一个新字符串；记录台/健康扫描那种几十 KB、上千标签的页面光这里就是几十万次分配，且**跑两遍**（内联 run 前置 pass + 切块器各一次）。DM 516 的原生 `spantext`/`nonspantext`（「从起点开始有多少个连续字符属/不属于某字符集」）与 `findtext` 直接顶掉这类循环，逐字节行为等价。同类还有 `lang_html_tag_parts`／`lang_html_raw_text_tag_name` 的标签名扫描、`lang_localize_inline_runs` 里「run 至今有没有非空白文本」的 `length(trim(copytext(...)))`（两次分配 → 一次 `spantext`）。注意 DM 字符串里**没有 `\r` 转义**（写了直接编译报错 undefined text macro）。另：`trim()` 上游已经委托给原生 `trimtext()`，不必再手工替换。
- **`name`/`desc` 是 `appearance` 字段，别在 `Initialize` 里原地反查** — 旧做法在 `/atom/Initialize` 与（不调父级的）`/turf/Initialize` 里把英文名/描述整串反查成译文，覆盖面最大，但代价是地图加载期对约 128 万实例各做两次外观变更（churn；appearance 内化+引用计数，同型实例仍共享一份，所以**不是**「每实例一份外观」——写文档时别把这点夸大成结论）。已改成实例保留 canonical English、只在显示边界翻：`/atom/get_examine_name`、`/atom/examine` 的 desc、`/atom/MouseEntered` 的 hover screentip，统一走 `lang_localize_name_for_display`。三条连带规律：
  · **分清「这次的回退」与「历来如此」**：`/datum` 的 name（材料/试剂/设计/配方/货运包）从不走 atom 的 Initialize 钩子，那些界面的单词名是既有状态；这次真正影响的只有「obj/turf 的 name 直接进 TGUI 负载」这一小类，而高流量那几处早有定点本地化。已补的两处宽覆盖边界：`tgui_input_list`（选项文本反查 + `items_map` 用显示串作键 + `default` 换显示形态，往返由 `i18n_display_boundary` 守）与径向菜单切片 `name`（标识符走 `E.choice`）。
  · **代价只在「名字不作 LANG 实参」的路径**：聊天不受影响——`[src]` 早被 rewrite 抬成 LANG 实参（`list(src` 一种形状全仓 3000+ 处），`lang_localize_arg` 是逐实参精确反查、**没有多词门槛**，单词名照样命中。真缺口是 TGUI 负载单词名、径向菜单 tooltip、状态栏、`tgui_input_list` 选项：那里只剩字面 AC 与 P1，两条都卡多词（`lang_reverse_phrase_tgui` 见无空格值直接返回；`lang_fallback_pattern_safe` 要求 trim 后多词）。量级：名字形已译条目里单词占约 10%（2122/21174），多词名仍被覆盖。补法是按类型桥进前端目录（`labels.rs TYPE_VAR_RULES`）或域内表 / ui_data 另发显示字段，**不是**把原地反查加回来。审计时别只看「界面英文」就判缺口，先确认该处名字是不是 LANG 实参。
  · **mob 的判据只用 `initial(name)`**：`name` 偏离即身份名（角色名/宠物挂牌/赛博编号/ERT 头衔）一律不翻，等于 `initial(name)` 才是类型标签。别另设「是否被改名」标志位——它只覆盖走 `fully_replace_character_name` 的那条路径，还得跟父级的 early-return 保持同步（父级 `oldname == newname` 时会 return FALSE，标志位却已经清了），比这条判据弱。
  · **`lang_reverse_text(initial(name))` 这类补偿代码分两种，别一刀切**（全仓 44 处，撤了 7 处、留了 37 处）：注释理由都是同一句「`initial(name)` 会覆盖掉 Initialize 反查好的中文名」，钩子删掉后该理由全部作废，但**去留看实例名有没有英文语义**。撤：名字参与英文解析/比较的（火警器与防火门的 `"[区域名] [类型名] [id_tag]"` 按英文解析区域前缀、异种的防重名重置）——留着就是 memory 里「机器丢区域前缀」那一类。留：**上游本来就在运行期写 `name`** 的（MMI/posibrain/礼物/尸袋/项圈挂牌/蜂/无人机…），那里不存在「多一次外观写入」的代价，而拼句碎片（`"casing"`、`" This one is spent."`）没有别的落地手段，撤掉纯亏。撤 mob 侧的之前先确认边界认得 `set_name()` 形态（`"类型名 (编号)"` 翻前缀留后缀），否则例检当场退回英文。
  · **注入 locale 的单测必须在 `Destroy()` 里恢复全局**：`TEST_ASSERT` 失败即 `return`，恢复写在 `Run()` 末尾就会把合成 locale 留在 `GLOB` 里，之后每个 i18n 测试连带染红。`i18n_display_boundary` 守这条边界（正反两向：静态类型名要翻、身份名与 `TRAIT_WAS_RENAMED` 不许翻）。
- **「name 兼作 act 标识符」的单词显示名：走前端目录桥，且只收单词** — 这类 name（`/datum/vote`、`/datum/ai_module`、`/datum/chemical_reaction`、`/datum/design`、`/datum/material`、`/datum/reagent`）在 TGUI 里既显示又当回传键/客户端比较键，DM 端不能改数据，只能进前端目录让 TS 只翻显示（`labels.rs SINGLE_WORD_TYPE_VAR_RULES`）。**按词数分叉是硬约束**：多词 name 本来就被 P1 在负载里翻好了，塞进前端目录反而让 P1 按「本身是 tgui 目录键」跳过、改由 TS 翻，一旦该界面把它渲染在非可翻位置（模板串、非 translatable prop）就从中文退化成英文；单词 name 连 P1 的多词门槛都过不了、本来恒为英文，进目录是纯增益。配套安全线在 `tgui-catalog.mjs extract`：单词键的译文**只许沿用其它命名空间的既有词对**（`reverseZh`），`phraseTranslation` 现编的值一律不收——`tgui.json` 会被 `build_i18n_cache` 扫进 DM 侧**全局反查表**，凭空多出的单词词对就是扩大全局误翻面。审计手法：抽取后逐条比对「新键的 en→zh 是否已存在于其它命名空间」，实测 506 条新键里 462 条沿用既有、0 条新造。
