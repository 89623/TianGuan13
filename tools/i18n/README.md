# nova-i18n —— NovaSector 全量汉化工具链

DM 字符串抽取/改写工具（Rust，基于 SpacemanDMM 的 `dreammaker` 解析器）+ 机翻流水线。
配套运行时见 `modular_nova/modules/i18n/`，平台见 `modular_nova/tools/i18n/`（Tolgee）。

## 端到端流程

```
                          tools/i18n (Rust)
  DM 源码 ──parse(dreammaker)──▶ 抽取玩家可见字符串 ──▶ strings/i18n/en/<ns>.json (英文主目录)
                                       │                          │
                            (后续) 改写调用点为 LANG/LANGU         │ push
                                                                   ▼
   tools/i18n/mt/translate.ts ◀── 机翻预填(配 glossary) ◀──── Tolgee 平台 (modular_nova/tools/i18n)
        │                                                          │ 人工校对
        ▼                                                          │ pull
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

# 翻译全部游戏/TGUI 命名空间（很久，适合分批跑）
bash tools/i18n/mt/translate-codex.sh

# 翻译某个游戏命名空间
I18N_CHUNK=100 bash tools/i18n/mt/translate-codex.sh obj.json

# 翻译后再检查剩余待译
bun tools/i18n/mt/i18n-mt.ts pending obj.json
```

`I18N_CHUNK` 控制每批喂给 Codex 的条数，默认 `200`；大文件建议 `50` 到 `100`，更稳。翻译脚本默认
把 Codex 输出写到 `tools/i18n/mt/.pending/*.codex.log`，终端只显示批次进度条和合并数量。相关环境变量：

```sh
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

# 翻译 TGUI 命名空间
I18N_CHUNK=100 bash tools/i18n/mt/translate-codex.sh tgui.json

# TGUI 翻译完或 Tolgee pull 后，都要同步前端运行时目录
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

### Tolgee：启动 / 上传 / 拉取

Tolgee 只用于开发期翻译管理；游戏和 TGUI 运行时都读本地 JSON，不联网连 Tolgee。

```sh
# 启动本地 Tolgee + Postgres
docker compose -f modular_nova/tools/i18n/docker-compose.yml up -d

# 查看 Tolgee 日志
docker compose -f modular_nova/tools/i18n/docker-compose.yml logs -f tolgee

# 首次登录 http://localhost:8085 后创建项目，把 projectId 写到 tolgee.config.ts
# 然后创建 API key，并在当前 shell 设置：
export TOLGEE_API_KEY='你的 API key'

# 上传本地 strings/i18n/<locale>/<namespace>.json 到 Tolgee
bunx @tolgee/cli push

# 从 Tolgee 拉取校对后的翻译回 strings/i18n/<locale>/<namespace>.json
bunx @tolgee/cli pull

# 可选：查看本地与远端差异
bunx @tolgee/cli compare

# pull 后必须同步 TGUI 前端运行时目录
node tools/i18n/tgui-catalog.mjs sync

# 停止 Tolgee
docker compose -f modular_nova/tools/i18n/docker-compose.yml down
```

### 术语表

```sh
# 从英文目录挑高频候选术语
bun tools/i18n/mt/glossary-sync.ts suggest

# 本地术语表 -> Tolgee glossary
export TOLGEE_API_URL='http://localhost:8085'
export TOLGEE_API_KEY='你的 API key'
export TOLGEE_ORG_ID='你的 organization id'
export TOLGEE_GLOSSARY_ID='你的 glossary id'
bun tools/i18n/mt/glossary-sync.ts push
```

### 同步上游

本地当前仓库默认只有 `origin`。第一次同步上游前先配置 upstream：

```sh
git remote -v
git remote add upstream https://github.com/NovaSector/NovaSector.git
git fetch upstream
```

之后每次同步：

```sh
# 确认工作区干净，或者先 commit/stash
git status --short

# 取上游最新 master
git fetch upstream

# 在你的工作分支上合并或 rebase 上游
git switch feat/i18n-localization
git rebase upstream/master
# 如果你更习惯 merge，也可以用：
# git merge upstream/master

# 解决冲突后，重同步 i18n 目录与 LANG/LANGU 改写
bash tools/i18n/resync.sh

# 重跑翻译检查 / TGUI 同步 / 构建
bun tools/i18n/mt/i18n-mt.ts pending
node tools/i18n/tgui-catalog.mjs sync
tools/build/build.sh tgui
tools/build/build.sh
```

如果冲突发生在 i18n 改写行，通常先保留上游英文原文，再跑 `bash tools/i18n/resync.sh` 让工具重新抽取并改写。

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
  `strings/i18n/<locale>/tgui.json` 作为 Tolgee/Codex 源目录；`tgui/packages/tgui/i18n/*.json` 是同步出的
  前端运行时子集，未译静态英文不打进 bundle。
- 占位符 `{0}/{1}` 在机翻时会被掩码保护；HTML 标签需保留。
- `dreammaker` 为 GPL-3.0，作为独立构建工具链接可接受（本项目已 GPLv3）。
- **服务端进大厅就崩（核心转储、停在按钮界面不刷日志）**：是 32 位 rust_g 的 iconforge 生成精灵图集
  时 OOM，**非 i18n**。`nix/byond.nix` 的 DreamDaemon 包装器已默认 `RAYON_NUM_THREADS=2` 压低峰值
  内存修复（详见 `modular_nova/modules/i18n/readme.md` 的「运行服务器 / 已知问题」）。
