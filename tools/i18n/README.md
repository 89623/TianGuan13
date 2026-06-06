# nova-i18n —— NovaSector 全量汉化工具链

DM 字符串抽取/改写工具（Rust，基于 SpacemanDMM 的 `dreammaker` 解析器）+ 机翻流水线。
配套运行时见 `modular_nova/modules/i18n/`（其 readme 有**全部 i18n 文件地图**）。人工校对走自选的**在线**本地化平台（导入导出 `strings/i18n/<locale>/*.json`）。

## 端到端流程

```
                          tools/i18n (Rust)
  DM 源码 ──parse(dreammaker)──▶ 抽取玩家可见字符串 ──▶ strings/i18n/en/<ns>.json (英文主目录)
                                       │                          │
                            改写调用点为 LANG/LANGU                │ 导入(import)
                                                                   ▼
   tools/i18n/mt/i18n-mt.ts ◀──── Codex 机翻预填(配 glossary) ◀── 在线本地化平台(自选)
        │                                                          │ 人工校对
        ▼                                                          │ 导出(export)
  strings/i18n/zh-Hans/<ns>.json  ◀───────────────────────────────┘
        │
        ▼
  运行时 modular_nova/modules/i18n/code/runtime.dm 按 locale 查表 + {0}/{1} 填充
```

## 命令速查

除特别说明外，下面命令都在仓库根目录执行。NixOS / 本机开发推荐先进入 dev shell：

```sh
nix develop
```

### 构建、检查、启动

```sh
# 构建 TGUI + DM。构建 TGUI 时会自动同步 tgui/packages/tgui/i18n/*.json
tools/build/build.sh

# 只构建 TGUI
tools/build/build.sh tgui

# TGUI 类型检查 / 测试 / lint
tools/build/build.sh tgui-test
tools/build/build.sh lint
tools/build/build.sh --ci lint tgui-test

# 启动本地服务器。端口可换成你的服务器端口
DreamDaemon tgstation.dmb 1337 -trusted

# 一条命令构建并启动
tools/build/build.sh && DreamDaemon tgstation.dmb 1337 -trusted
```

### 配置全服中文

```sh
# config/game_options.txt 里应有：
I18N_SERVER_LOCALE zh-Hans
```

改完配置后需要重启服务器。TGUI 的 `config.locale` 跟随这个全服配置。

### 游戏文本：抽取 / 改写 / 同步源码

```sh
# 只刷新英文目录 strings/i18n/en/*.json
cargo run --release --manifest-path tools/i18n/Cargo.toml -- \
  extract --dme tgstation.dme --out strings/i18n/en

# 只把新出现的消息调用点改成 LANG()/LANGU()
cargo run --release --manifest-path tools/i18n/Cargo.toml -- \
  rewrite --dme tgstation.dme

# 推荐：合并上游后的一键重同步
# 会构建 nova-i18n、刷新游戏英文目录、刷新 TGUI tgui.json、再做 rewrite
bash tools/i18n/resync.sh
```

游戏端运行时直接读取 `strings/i18n/<locale>/*.json`，所以游戏翻译本身不需要额外“生成前端包”。翻译更新后重新构建 / 重启服务即可生效。

### 游戏文本：Codex 批量翻译

```sh
# 看所有命名空间还有多少待译
bun tools/i18n/mt/i18n-mt.ts pending

# 看某个命名空间，例如 obj.json
bun tools/i18n/mt/i18n-mt.ts pending obj.json

# 看译文里哪些条目没有按术语表统一用词（不调用 Codex）
bun tools/i18n/mt/i18n-mt.ts terms obj.json

# 翻译全部游戏/TGUI 命名空间（默认单并发串行跑完整个待译队列）
bun tools/i18n/mt/i18n-mt.ts

# 翻译某个游戏命名空间
bun tools/i18n/mt/i18n-mt.ts obj.json

# 只让 Codex 修复术语表不一致的条目
bun tools/i18n/mt/i18n-mt.ts translate-terms obj.json

# 翻译后再检查剩余待译
bun tools/i18n/mt/i18n-mt.ts pending obj.json
```

翻译脚本按批次顺序启动 Codex 调用，不做并行：一批结束并合并后，才会启动下一批。默认
`I18N_MAX_CODEX_CALLS=0`，表示不限批次数，串行跑到队列完成或失败。Codex 失败时默认立刻停止，避免额度 / 登录错误后继续开新
调用；重跑同一命令会重新计算 `pending`，从剩余待译继续，不会重翻已合并条目。

为省 token，翻译中间批次会使用临时数字 ID（例如 `{"0":"English text"}`），并把同批重复英文源合并成一个 ID；
Codex 输出后再由脚本映射回真实目录 key。这对 TGUI 尤其重要，因为很多 TGUI key 本身就是英文长句。脚本默认每批
只把“本批英文源里命中的术语”发送给 Codex，不再每批发送完整术语表。

`terms` / `translate-terms` 使用同一份 `tools/i18n/mt/glossary.zh-Hans.json`：如果英文源里出现术语表 key，
但现有中文译文没有包含对应译名，就会被筛进 `tools/i18n/mt/.pending/glossary-mismatches.<locale>.json`。
`translate-terms` 只重翻这些条目，用来统一术语，不会处理普通缺译项。

`I18N_CHUNK` 控制每批喂给 Codex 的条数，默认 `200`；调小更稳但调用更多，调大能减少调用数但更容易输出不完整。
翻译脚本默认把 Codex 输出写到 `tools/i18n/mt/.pending/*.codex.log`，终端只显示批次进度条和合并数量。相关环境变量：

```sh
# 默认 0：不限批次数，但仍然单并发串行
I18N_MAX_CODEX_CALLS=0

# 兼容旧名：同义于 I18N_MAX_CODEX_CALLS
I18N_MAX_AGENTS=0
I18N_MAX_BATCHES=0

# 可选：限制一次命令只跑 4 批
I18N_MAX_CODEX_CALLS=4

# 可选：失败后继续；默认失败即停，避免 usage limit / reauth 错误时继续开调用
I18N_CONTINUE_ON_FAIL=1

# 可选：每个 Codex 调用之间等待，单位毫秒
I18N_CODEX_DELAY_MS=2000

# 可选：每批发送完整术语表；默认只发送本批命中的术语，更省 token
I18N_FULL_GLOSSARY=1

# 默认 low，覆盖用户全局 xhigh，翻译任务没必要高推理
I18N_CODEX_REASONING=low

# 可选：指定 Codex 模型
I18N_CODEX_MODEL=gpt-5.5

# 可选：调试时恢复旧行为，把 Codex 输出直接打到终端
I18N_CODEX_STDIO=inherit
```

### TGUI 文本：抽取 / 翻译 / 同步前端

```sh
# 抽取 TGUI 静态 JSX 文本到 strings/i18n/en/tgui.json，
# 复用已有中文译文/术语，并同步 tgui/packages/tgui/i18n/*.json
node tools/i18n/tgui-catalog.mjs extract

# 只同步：strings/i18n/<locale>/tgui.json -> tgui/packages/tgui/i18n/<locale>.json
node tools/i18n/tgui-catalog.mjs sync

# 查看 TGUI 待译
bun tools/i18n/mt/i18n-mt.ts pending tgui.json

# 查看 TGUI 术语不一致
bun tools/i18n/mt/i18n-mt.ts terms tgui.json

# 翻译 TGUI 命名空间
bun tools/i18n/mt/i18n-mt.ts tgui.json

# 只修 TGUI 术语
bun tools/i18n/mt/i18n-mt.ts translate-terms tgui.json

# TGUI 翻译完或从在线平台导回译文后，都要同步前端运行时目录
node tools/i18n/tgui-catalog.mjs sync

# 验证前端构建
tools/build/build.sh tgui
```

TGUI 动态文本如果带变量，应显式写成 `useT()` + `{0}/{1}` 参数；静态 JSX 文本由自动 runtime 查目录。例：

```tsx
const t = useT();

return <Button>{t('tgui.print_amount', [amount])}</Button>;
```

对应目录：

```json
"tgui.print_amount": "打印 {0} 个"
```

### 人工校对：在线本地化平台（自选）

译文就是 `strings/i18n/<locale>/*.json`（含 `tgui.json`）—— 扁平的 `{"key": "译文"}`。这是平台无关的标准
格式，可导入任意**在线**平台（Crowdin / Lokalise / Weblate / Tolgee Cloud 等）做团队校对，再导出回原文件。
运行时只读本地 JSON，**不联网连平台**。（旧版自托管 Tolgee 的 docker-compose 已移除。）

典型流程：

```sh
# 1) 机翻预填（Codex），先把英文目录翻一遍 / 补译；默认单并发串行跑完整个队列
bun tools/i18n/mt/i18n-mt.ts

# 2) 把 strings/i18n/<locale>/*.json 导入你选的平台 → 人工校对 → 导出回这些文件
#    （各平台用自带 CLI / 网页上传下载，格式选「扁平 JSON / key-value JSON」）

# 3) 导回后，若改了 tgui.json，需同步前端运行时子集
node tools/i18n/tgui-catalog.mjs sync

# 4) 重建生效
tools/build/build.sh
```

### 术语表

```sh
# 从英文目录挑高频候选术语（人工择入 tools/i18n/mt/glossary.zh-Hans.json）
bun tools/i18n/mt/glossary-sync.ts suggest
```

术语表本体 `tools/i18n/mt/glossary.zh-Hans.json`（英文->中文；保持英文则 value 同 key）由 Codex 机翻直接套用；
上线在线平台后，多数平台自带术语表/词汇表功能，可把这份 JSON 导入平台维护。

Codex 翻译时可以把本批新发现的固定专名写入 `.pending/*.glossary.json`，但合并阶段会保守过滤：
只自动收录缩写、带型号/符号的名称、明确的多词专名、少量显式允许的一词专名，以及 `LOWERCASE_TERM_ALLOWLIST` 里的小写游戏术语。
颜色、方向、大小、普通形容词、普通地点词、普通职业泛称、多义词等不会自动进入术语表；这类词应交给正文上下文翻译。

### 同步上游

本仓库的 `master` 在 GitHub 上自动跟随上游 NovaSector，所以本地**只需合并 `origin/master`**，
不必再配 `upstream` 远端。日常一条命令搞定（脏树检查会放过 `.vscode`/`zh-Hans` 等私有产物）：

```sh
bash tools/i18n/sync-upstream.sh        # SYNC_BUILD=0 可跳过末尾编译
```

它依次做：`git fetch` → 把 `origin/master` 合进当前 i18n 分支 → `resync.sh`（重抽取英文目录 +
幂等改写新字符串）→ `tools/build/build.sh` 编译验证。

**用 merge 不用 rebase**：本分支提交多、改了大量 NOVA EDIT 核心文件，rebase 会强推 + 把每个上游冲突
在所有提交上反复重放；merge 每次只解一次，且 `resync.sh` 的重收敛策略就是为 merge 设计的。

**冲突分辨**（脚本撞冲突会停下并列出冲突文件，按这条手动解）：

| 冲突 hunk 里是什么 | 怎么办 |
| --- | --- |
| codemod 行 `LANG("ns.hash", …)`，或你没改过的上游逻辑 | **取上游**：`git checkout --theirs <文件> && git add <文件>`。LANG 行交给 resync 重新加回，上游逻辑本就该采纳。 |
| 你手写的 i18n 逻辑（`lang_reverse_*()` 包裹、手加的 NOVA EDIT） | **留自己的**（或两边都留）。这些 resync **不会**重新生成，盲取 theirs 会永久丢掉。常见于 `code/` 下 `book.dm` / `say.dm` / `chat.dm` / `atom_examine.dm` / `_bodyparts.dm` / `preferences/species.dm`。 |

解决后 `git commit`，再次运行 `bash tools/i18n/sync-upstream.sh`（检测到已无未合提交，直接续跑 resync + 编译）。

> 别完全信 IDE 的一键「接受当前/传入」：它可能保留你旧行又取上游行，把上游真重构丢掉。冲突涉及非 LANG 的逻辑
> 改动时，先看两边再定：`git show :2:<文件>`（ours/你的）对比 `git show :3:<文件>`（theirs/上游）。

提交只放 `code/**`、`modular_nova/**`、`tools/i18n/**`、`strings/i18n/en/**`；**排除**私有产物
`strings/i18n/zh-Hans/*`、`tgui/packages/tgui/i18n/*`、`glossary.zh-Hans.json`、`.vscode/settings.json`。
最后跑 `bun tools/i18n/mt/i18n-mt.ts` 补译本次新增条目。

### 统计和排查

```sh
# 统计 TGUI 源目录总数、已译、待译、前端运行时子集数量
node - <<'NODE'
const fs = require('fs');
const en = JSON.parse(fs.readFileSync('strings/i18n/en/tgui.json'));
const zh = JSON.parse(fs.readFileSync('strings/i18n/zh-Hans/tgui.json'));
const runtimeZh = JSON.parse(fs.readFileSync('tgui/packages/tgui/i18n/zh-Hans.json'));
const pending = Object.keys(en).filter((key) => zh[key] === en[key]).length;
console.log({
  sourceTotal: Object.keys(en).length,
  sourceTranslated: Object.keys(en).length - pending,
  sourcePending: pending,
  runtimeZh: Object.keys(runtimeZh).length,
});
NODE

# JSON 格式检查
jq empty strings/i18n/en/*.json strings/i18n/zh-Hans/*.json

# 前端目录格式 / 类型 / 打包
./node_modules/.bin/biome check tgui/packages/tgui/i18n tools/i18n/tgui-catalog.mjs
cd tgui && ./node_modules/.bin/tsc && ./node_modules/.bin/rspack build
```

## 路线图（对应已批准计划的阶段）

- **阶段 0（当前）**：基建打通。抽取器可解析全树（实测 ~52,986 条 name/desc 类字符串）；
  运行时库 + 全服 TGUI locale 注入就绪；`packages/tgui` 静态 JSX 文本会自动查前端目录，
  TGUI 源翻译统一进入 `strings/i18n/<locale>/tgui.json`，
  `ammo_workbench` 仍保留端到端显式 helper 样例。
- **阶段 1**：扩展抽取到 proc 体内 `to_chat` / `visible_message` / `balloon_alert` 等汇聚点；
  把内插字符串 (`Term::InterpString`) 转 `{0}/{1}` 占位符模板。
- **阶段 2**：`rewrite` 子命令——幂等批量改写调用点为 `LANG/LANGU`（分域合入，每域编译/单测）。
- **阶段 3**：运行时 AC 兜底（`fallback.dm`）+ TGUI 前端静态文本全量抽取/翻译补全。
- **阶段 4**：CI 持续抽取/同步；人工校对推进覆盖率至 100%；合并上游后重跑工具。

## 注意

- 目录文件放 `strings/i18n/`（`strings/` 已被 git 跟踪；`data/` 被 .gitignore 忽略）。TGUI 也使用
  `strings/i18n/<locale>/tgui.json` 作为在线平台/Codex 源目录；`tgui/packages/tgui/i18n/*.json` 是同步出的
  前端运行时子集，未译静态英文不打进 bundle。
- 占位符 `{0}/{1}` 在机翻时会被掩码保护；HTML 标签需保留。
- `dreammaker` 为 GPL-3.0，作为独立构建工具链接可接受（本项目已 GPLv3）。
- **服务端进大厅就崩（核心转储、停在按钮界面不刷日志）**：是 32 位 rust_g 的 iconforge 生成精灵图集
  时 OOM，**非 i18n**。`nix/byond.nix` 的 DreamDaemon 包装器已默认 `RAYON_NUM_THREADS=2` 压低峰值
  内存修复（详见 `modular_nova/modules/i18n/readme.md` 的「运行服务器 / 已知问题」）。
