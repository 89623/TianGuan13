https://github.com/89623/TianGuan13/pull/<!--PR 编号-->

## 指南浏览器（Guide Browser）

模块 ID：`GUIDE_BROWSER`

### 说明：

给玩家一个「指南浏览器」动作按钮，点开是 tgui 窗口 `GuideBrowser`，左侧列出服务器指南/维基目录，
点一下链接条目就在**游戏内浏览器**里打开对应页面（DreamSeeker 自带浏览器，不是系统浏览器）。
目录内容、按钮文字、跳转链接**全部写在配置文件里**，管理员改配置**不需要重新编译**
（停服起服，或每局开局自动重读，或游戏内管理员指令重载）。

两种形态（与配置里两类条目一一对应）：

| 条目 | 配置里长什么样 | 点击行为 |
| --- | --- | --- |
| 分组 | 有 `children`（可再嵌套分组） | 展开 / 折叠，不发任何请求 |
| 链接 | 只有 `url` | **直接跳转**，怎么跳由 `open` 字段决定（默认在游戏内浏览器里打开） |




### 主要功能

- 界面是**常驻双栏**：左侧目录树，右侧是当前选中条目的标题、URL 和「在游戏内打开」按钮。
  右侧只在条目用 `open: "frame"` 且客户端支持时才内嵌网页本体（其余方式没法内嵌，原因见下文）。
- 动作按钮「指南浏览器」在玩家连接时自动发放，目录为空时不发放（不会给一个点开是空白的按钮）。
- 左侧目录树：分组可展开/折叠（标题上带条数），链接按配置顺序排列。
- 点击链接条目 → 按该条目的 `open` 打开（出厂默认 **游戏内浏览器弹窗**：服务器不联网、页面由玩家客户端请求）。
- 右上角常驻「在浏览器中打开」按钮：任何时候都能兜底交给系统浏览器。
- 配置改动检测：文件内容没变就不重载、不关闭任何人正开着的窗口；变了才会重建并对齐。
- 管理员指令「重载指南浏览器配置」当场重载，并把结果（可用链接条数 / 逐条跳过原因）写进日志。

### 新增或修改的文件

| 文件 | 性质 | 说明 |
| --- | --- | --- |
| `modular_tianguan/modules/guide_browser/code/guide_config.dm` | 新增 | 配置读取 / 校验 / 提交 / 自检日志 / 子系统 / 动作发放 / 四种打开方式 |
| `modular_tianguan/modules/guide_browser/code/guide_browser.dm` | 新增 | `/datum/action/guide_browser` 动作按钮 + tgui 交互 |
| `modular_tianguan/modules/guide_browser/code/guide_admin.dm` | 新增 | 管理员指令 `reload_guide_browser` |
| `modular_tianguan/modules/guide_browser/readme.md` | 新增 | 本文件 |
| `config/tianguan/guide_browser.json` | 新增 | 目录数据（生效条目 + 全部示例） |
| `tgui/packages/tgui/interfaces/GuideBrowser.tsx` | 新增 | tgui 界面（顶部带 `// THIS IS A TIANGUAN UI FILE`） |
| `tgstation.dme` | 修改 | 天关块内加 3 行 `#include`（项目清单，不是源码） |

### 核心文件 / Proc 改动：

- 无。本模块不修改任何 `code/` 或 `modular_nova/` 文件，也没有 `master_files/` 覆盖。
  子系统用 `SUBSYSTEM_DEF` 自动注册。

### 模块化覆盖：

- 无。

### Defines：

文件内宏（`guide_config.dm` 顶部定义、文件尾 `#undef`，不污染全局编译上下文）：

| 宏 | 默认 | 用途 |
| --- | --- | --- |
| `TIANGUAN_GUIDE_MAX_DEPTH` | 4 | 分组最多嵌套几层 |
| `TIANGUAN_GUIDE_MAX_NODES` | 256 | 整棵树最多多少条目（分组 + 链接），防手滑写出巨型配置 |
| `TIANGUAN_GUIDE_MAX_LABEL` | 64 | 按钮文字最长字符数，超长截断 |
| `TIANGUAN_GUIDE_MAX_URL` | 2048 | 链接最长字符数 |
| `TIANGUAN_GUIDE_OPEN_PANEL` / `_WINDOW` / `_FRAME` / `_BROWSER` | `panel` / `window` / `frame` / `browser` | 四种打开方式的取值 |

配置**路径**刻意不用宏，而是 `/proc/tianguan_guide_config_path()` —— 管理员指令那边也要报这个路径，
跨文件用宏会受 include 顺序影响（本文件尾会 `#undef`）。

### 本模块目录外的依赖文件：

- `config/tianguan/guide_browser.json` — 目录数据（纯数据，改它不用重编译）
- `tgui/packages/tgui/interfaces/GuideBrowser.tsx` — 界面。tgui 界面**必须**放在
  `tgui/packages/tgui/interfaces/` 下（`require.context('./interfaces')` 自动发现），
  不能搬进模块目录；它在 dme 里不需要 include，但要**重新打包 bundle** 才会生效
  （`cd tgui && bun run tgui:build`，产物 `tgui/public/tgui.bundle.js` 是 gitignored 构建产物）。

### 配置文件格式（`config/tianguan/guide_browser.json`）

顶层是 JSON 数组，每个元素是一条**顶级条目**（建议先把分组放最上面）：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `label` | string | ✅ | 按钮文字（≤ 64 字符，超长自动截断） |
| `children` | array | 二者其一 | 子条目数组 → 本条目是**可展开分组**，children 里是同结构的条目（可再套一层） |
| `url` | string | 二者其一 | 跳转链接，**必须带 `http://` 或 `https://`** → 本条目是**直接跳转** |
| `open` | string | ❌ | 打开方式：`window`（出厂默认）/ `panel` / `frame` / `browser`，见下表。写在**分组上会被整组子条目继承**，子条目自己写了以自己为准 |
| `enabled` | bool | ❌ | `false` = 跳过本条（JSON 没有注释语法，**这就是"注释掉"的手段**）；不写等于启用 |
| `_说明` | string | ❌ | 随便写给人看的备注，模块会忽略 |

一边有 `children` 一边写 `url` 时以 `children` 为准（分组）。

### 四种打开方式（`open`）

| 值 | 玩家看到什么 | 备注 |
| --- | --- | --- |
| `window`（出厂默认） | **游戏内浏览器弹窗** —— 同名窗口反复复用，不会开一堆 | 一定弹出，不依赖客户端布局；页面由玩家客户端请求，能过站点防护 |
| `panel` | **游戏内浏览器面板** —— 嵌在 DreamSeeker 窗口里的浏览器 | 服务器不联网；面板是否可见取决于客户端设置（有些客户端把面板藏起来） |
| `frame` | 就在**指南窗口右侧** iframe 内嵌渲染 | ⚠ 仅当目标站点允许被内嵌才可用；天关自己的 wiki **不行**，见下节 |
| `browser` | 交给**系统默认浏览器** | 兜底；玩家会切出游戏 |

```jsonc
// 下面这些注释只是讲解，写进 JSON 时删掉（JSON 不支持注释）
[
  {
    // ① 分组：点击展开 / 折叠。约定放在最上面。
    "label": "新手入门",
    "children": [
      // ② 链接：点击直接跳转 —— 不写 open 就是默认的游戏内浏览器面板
      { "label": "维基首页", "url": "https://tianguanstation.miraheze.org/wiki/%E9%A6%96%E9%A1%B5" },
      { "label": "初学者指南", "url": "https://tianguanstation.miraheze.org/wiki/%E5%88%9D%E5%AD%A6%E8%80%85%E6%8C%87%E5%8D%97" }
    ]
  },
  {
    // ③ 顶层也能直接放「直接跳转」条目：没有 children、只有 url
    "label": "快速上手",
    "url": "https://tianguanstation.miraheze.org/wiki/%E5%88%9D%E5%AD%A6%E8%80%85%E6%8C%87%E5%8D%97"
  },
  {
    // ④ 分组里还能再套一层分组；不写 open 就是出厂默认的游戏内浏览器弹窗
    "label": "示例分组（默认游戏内浏览器）",
    "children": [
      { "label": "示例子条目", "url": "https://tianguanstation.miraheze.org/wiki/%E9%A6%96%E9%A1%B5" },
      {
        "label": "示例：再套一层",
        "children": [
          { "label": "示例孙条目", "url": "https://tianguanstation.miraheze.org/wiki/%E5%88%9D%E5%AD%A6%E8%80%85%E6%8C%87%E5%8D%97" }
        ]
      }
    ]
  },
  {
    // ⑤ open 换成别的打开方式；enabled: false 则是「注释掉」的唯一手段
    //    （条目留在文件里，模块静默跳过）
    "label": "示例：系统浏览器跳转",
    "enabled": false,
    "open": "browser",
    "url": "https://tianguanstation.miraheze.org/wiki/%E9%A6%96%E9%A1%B5"
  }
]
```

> ⚠️ 配置文件里同时放了**生效条目 + 全部示例**（示例一律 `enabled: false`）；上面这段是同一套示例的
> 带注释版。两边示例集合保持一致，别只改一边。

### 为什么默认不是 `frame`（内嵌）—— 实测记录

1. 天关维基（Miraheze）对页面发 `x-frame-options: SAMEORIGIN`，且是**全站统一**加的：
   实测 `主页` / `?useskin=vector` / `?action=render` / `index.php?…&action=render` /
   `api/rest_v1/page/html/…` / `?printable=yes` **六个 URL 全部带这个头**（换皮肤、换入口都没用）。
2. BYOND 516 起把内置浏览器从老 IE 换成了 **WebView2（Chromium）**（516 发行说明），
   所以它会**照章执行**这个头 ⇒ iframe 里只会得到「拒绝连接」（2026-09 本机实测确认）。
3. 因此游戏内渲染改走 BYOND 自己的 `browse()`：它打开的是**顶层导航**，不受 `X-Frame-Options`
   约束；而且页面是**玩家客户端**去请求的（能过站点的防爬/防护），服务器完全不需要联网。
4. 实现方式：先送一张极小的「导航垫片」HTML（`onLoad="parent.location='<url>'"`），
   加载完立刻把窗口/面板自身跳到目标 URL。这样 `panel` / `window` 两种模式共用同一张垫片，
   URL 里的单引号会转义成 `%27`（否则会截断垫片里的 JS 字符串）。

⇒ 换站点时的判断：**先把它写进配置点一下**，能正常显示就用默认值；只有确认该站点允许被内嵌
（响应头里没有 `X-Frame-Options: SAMEORIGIN/DENY`）才给它写 `"open": "frame"`。

**如果要让 wiki 配合（把 frame 模式救回来）**，需要站点方做下面任一件事，然后本模块一个字都不用改：

| 做法 | 说明 |
| --- | --- |
| 去掉 `X-Frame-Options` 响应头 | 最简单，但对全站生效 |
| 改用 `Content-Security-Policy: frame-ancestors …` 精确放行 | 现代做法；`X-Frame-Options` 只有 SAMEORIGIN/DENY 两档，做不到"只放行某类客户端" |
| 只给专用路径放宽（如 `/embed/`） | 最保守，其它路径保留现有防护 |

验证命令（对方自己就能跑）：`curl -sI <wiki>/wiki/<页面> | grep -iE 'x-frame-options|content-security-policy'`
—— 修好后 `x-frame-options` 应消失，且 CSP 里不应有 `frame-ancestors 'self'`。

⚠️ 现实情况（2026-09 实测）：天关 wiki 在 **Miraheze**，这个头是**全站统一**的
（`tianguanstation` / `meta.miraheze.org` / `login.miraheze.org` / `static.miraheze.org` 全带），
wiki 管理员在 `Special:ManageWiki` 里没有这个开关 ⇒ 要走 **Miraheze 的 Phorge 提请求**给
Technology/Infrastructure 团队，而它属于对方的安全基线，被拒的概率很高。
另外 Miraheze 的自定义域名政策**明确不允许**在前面再挂一层自己的 Cloudflare/反代
（"禁止双层代理"）⇒ "自己反代把那个头去掉"这条路在 Miraheze 上走不通。
真要"嵌进客户端窗口里"，最稳的是把 wiki 放到自己完全可控的域名/自建 MediaWiki。

### 容错纪律（启动路径绝不允许 CRASH）

| 情况 | 处理 |
| --- | --- |
| 配置文件不存在 / 读不出 | 记日志，本次沿用旧目录（启动期则是"目录为空 ⇒ 不发放按钮"） |
| `json_decode` 结果不是数组 | 记日志，本次沿用旧目录 + 提示用管理员指令重载 |
| 条目不是对象（写了字符串/数字） | 跳过该条 + 日志 |
| 缺 `label` / `label` 是空串 | 跳过该条 + 日志 |
| 既没有 `children` 也没有 `url`，或 `url` 不是 http(s) | 跳过该条 + 日志 |
| `open` 值不认识 / 不是字符串 | **回退**（继承分组的值，分组也没有就用出厂默认 `window`）+ 日志，条目照常可用 |
| 分组里一条可用条目都没有 | 跳过整个分组 + 日志 |
| 嵌套超过 4 层 / 条目超过 256 个 | 跳过该分支 + 日志 |
| `enabled: false` | 静默跳过，计入"已禁用"计数 |

读取时机：子系统 `Initialize()`（此时 GLOB 与 i18n 已就绪、还没有任何玩家）+ 每局开局
（`COMSIG_TICKER_ENTER_PREGAME`）各一次；外加管理员指令手动重载。三次都走同一个
`tianguan_load_guide_config()`，**文件原文没变时直接短路**（不重建、不关闭任何人的窗口）。

### 测试方式（本地私服实测）

1. 编译：`dm.exe -DCBT tgstation.dme` → `0 errors, 0 warnings`。
2. tgui：`cd tgui && bun run tgui:tsc`（无输出即通过）+ `bun run tgui:build`（产物
   `tgui/public/tgui.bundle.js` 里能搜到 `GuideBrowser`，且 mtime 晚于改过的 `.tsx`）。
3. 起服看启动日志（`-log data/server_test.log`），应有：

   ```
   GUIDE_BROWSER: config/tianguan/guide_browser.json 读到 10 条，启用 8 条（分组 8 个 / 链接 91 条），已禁用 2 条，跳过 0 条
   GUIDE_BROWSER: 分组一览 → 新手入门(8) · 规则与政策(8) · 角色与扮演(8) · 部门标准作业程序(10) · 职业手册(20) · 玩法指南(14) · 背景与势力(19) · 管理员资料(4)
   GUIDE_BROWSER: 打开方式 → 游戏内面板 0 条 / 游戏内弹窗 91 条 / 窗口内嵌 0 条 / 系统浏览器 0 条
   GUIDE_BROWSER: 示例链接 → 维基首页 = https://tianguanstation.miraheze.org/wiki/%E9%A6%96%E9%A1%B5
   ```
4. 游戏内：连接后点动作按钮「指南浏览器」→ 弹出**双栏窗口**（左：8 个可展开分组；右：当前条目的详情与
   「在游戏内打开」按钮）。点左侧任一条目 → 右侧更新为该条目详情，同时按 `open` 打开：
   出厂默认（`window`）应**弹出一个游戏内浏览器窗口**并加载该维基页面；想要"嵌在客户端窗口里"的面板
   效果就把配置里该分组的 `open` 改成 `panel`，**不用重编译**。
5. 容错自测（可选）：把配置文件改成非法 JSON → 起服/重载后应看到
   `解析失败（顶层必须是 JSON 数组）` 且不崩；改成 `[]` → 应看到「没有任何可用链接 ⇒ 不发放按钮」；
   把某条 `open` 写成 `"iframe"` → 应看到「open 值不认识…按 window 处理」而那条仍可用。

### 维护备注

- 配置文件是**纯数据**，改它不用重新编译：停服起服即生效；管理员指令可以当场重载；
  每局开局也会自动重读（文件没变则跳过）。
- 跳转链接全部指向天关维基 `https://tianguanstation.miraheze.org/wiki/<百分号编码的页面名>`。
  加新指南：去维基确认页面名，再按同样格式加一条（页面名里的空格写 `_`，中文/标点按 UTF-8 百分号编码）。

### 致谢：

  
- 「书页里跳转维基」的既有做法参考天关自己的 `modular_tianguan/modules/sop_book`。
- 「用一张垫片 HTML 让内置浏览器导航到指定 URL」的手法来自 BYOND 论坛教程
  （browse_link 例子，post 1899）—— 本模块的 `panel` / `window` 两种模式就靠它绕开
  `X-Frame-Options`。
