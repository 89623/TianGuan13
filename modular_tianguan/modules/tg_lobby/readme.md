https://github.com/89623/TianGuan13/pull/<!--PR 编号-->

## 大厅标题界面：侧边栏布局 + 磨砂玻璃质感

模块 ID：`TG_LOBBY`

### 说明：

重做大厅（标题界面）的视觉与布局，把原本居中悬浮的菜单框改成左侧固定侧边栏，并换成半透明玻璃质感：

- **左侧边栏**（自上而下）：顶部展示图 → 角色头像 + 角色名 + `ID: ckey · 槽位 N` → 角色偏好摘要（种族/年龄/性别/职位）→ 原有全部按钮（功能不变，仅位置与样式变化）
- **右上角**：通知栏（承接 `SStitle.current_notice` 管理员公告）
- **可收起**：侧边栏右缘有一个把手（◀/▶）。点击即把**侧边栏 + 左下两个跳转栏一起滑出屏幕**（都往左滑走消失），再点滑回。默认展开
- **左下两个跳转栏**：「天关wiki」→ 天关维基；「支持我们」→ 爱发电。图标在文字右侧；「支持我们」四字持续走彩虹色
- **收起状态由服务端持有**（`/mob/dead/new_player.tg_sidebar_collapsed`）：点把手走 `byond://` Topic → 服务端取反 → `output()` 投给页面 → 页面给 `<body>` 挂/摘 `tg_collapsed` 类 → CSS 三条规则一起动。**不重投页面**（重投会闪一下并丢掉滑行动画）
- **玻璃质感**：半透明底 + 高光渐变 + 亮边框 + 内阴影 + 细斜纹噪点
- **改角色即时反映**：在「角色设置」里改种族/性别/年龄/职位/名字等，侧边栏头像与偏好摘要会跟着刷新

⚠️ 关于「磨砂」的实现边界：BYOND 的 browser 控件是 **IE 内核**（`interface/skin.dmf` 的 `nova_title_browser`），IE11 不支持 `backdrop-filter`，也不支持 `filter: blur()`，所以**真正的背景模糊做不出来**。本模块用 `.tg_glass` 一类玻璃板（半透明 + 高光 + 内阴影 + 斜纹噪点）近似，并遵守三条 IE 约束：

- GIF 动图必须用 `<img>` 标签引用（IE 不播放 CSS 动画背景图，只会显示第一帧）
- 布局用绝对定位 + `vmin`，不使用 flexbox/grid（IE11 的 flexbox 有已知缺陷）
- 收起动效只用 `transition: left`（IE10+ 支持），不依赖 JS 动画

### 核心文件 / Proc 改动：

- 无（未触碰 `code/` 下任何文件）

### 模块化覆盖：

本模块**派生接管**了上游 `modular_nova/modules/title_screen/` 的两个文件（原因都是
**DM 不允许同一类型上的同一 proc 重复定义**，而后 include 并不会覆盖、只会直接编译报错）：

- **`tgstation.dme`**：从清单移除 `modular_nova\modules\title_screen\code\title_screen_html.dm`
  与 `modular_nova\modules\title_screen\code\new_player.dm`，改 include 本模块的同名文件。
- 上游 `modular_nova/` 目录**本身零改动**（未删改任何文件内容）。
- 代价：这两个文件在上游更新时需要人工比对同步。差异清单见下节。

### 本模块相对上游的差异点（同步时核对）：

**1) `title_screen_html.dm`**（上游：`modular_nova/modules/title_screen/code/title_screen_html.dm`）

- **新增 CSS**：`TG_LOBBY_CSS` —— 玻璃板 `.tg_glass`、侧边栏 `.tg_side`、收起开关 `.tg_collapse_input` / `.tg_handle`、顶部图 `.tg_art`、角色卡 `.tg_card` / `.tg_pname` / `.tg_pid` / `.tg_avatar`、偏好 `.tg_prefs`、右上通知栏改写
- **新增 proc**：`tg_lobby_art_html()`（投递侧边栏顶部图）、常量 `TG_LOBBY_ART_CANDIDATES`
- **改写**：`get_title_html()` 的 `else`（大厅）分支 —— 菜单区由居中 `.container_nav` 改为左侧 `.tg_side` 侧边栏；通知由居中改为右上 `.container_notice`；并插入收起用的 `<input>` + `<label>`
- **大幅保留**：`GAME_STATE_STARTUP`（启动终端 + 进度条）分支、尾部 XHR `title_is_ready` 回报、`lang_localize_title_html()` 汉化表、页面 `<head>` 骨架仍取自 `config/nova/title_html.txt`
- **新增 JS**：`tg_set_avatar()` / `tg_set_prefs()` / `tg_set_name()` —— 侧边栏角色卡的实时刷新接收端（启动分支里给了同名空实现占位）
- **JS（本模块的坑，同步上游时必须逐字核对这一段）**：`toggle_ready` / `toggle_antag` /
  `update_current_character` / `append_terminal_text` / `update_loading_progress`
  **曾经整段丢失**（当初接管这个文件时没带过来）。症状：**加载界面不动**（看着像"卡加载"
  —— 终端不滚、进度条不走）、**点准备后图标不从 ☒ 变 ☑**、头像/名字不刷新。
  现已从上游同文件**逐字补齐**。
  本模块另加的函数：`tg_set_avatar` / `tg_set_prefs` / `tg_set_name` / `tg_set_pid`
  （大厅角色卡实时刷新的接收端，对应 `lobby_card.dm` 里那几条 `output(..., "nova_title_browser:…")`）
  + `tg_set_collapsed`（侧边栏收起）。
  ⚠️ 改这里的 JS 要记住 DM `{"..."}` 的两条雷区：**字面方括号要写 `\[`**；
  **而需要 DM 求值的表达式恰恰不能转义** —— 写成 `\[tg_sidebar_collapsed ? 1 : 0\]` 会**原样输出**
  字面括号，初始状态就永远注入不上（这个坑真踩过）。
  ⚠️⚠️ **本模块的 `<script>` 排在按钮之前（上游相反）⇒ 所有 `getElementById` 必须"惰性"
  （写在函数内），不能像上游那样写成模块级变量**：
  上游按钮（103 行）在脚本（128 行）之前，所以它那样写没事；我们把按钮挪进侧边栏后
  **顺序反了**（脚本 462 行 / 按钮 556 行）⇒ 脚本求值时 `#ready` 还是 `null`
  ⇒ `ready_mark` / `antag_mark` / `character_name_slot` 全是 `null`
  ⇒ 每次赋值抛 `Cannot set properties of null (setting 'innerHTML')` ⇒ **图标永远不动**。
  ⇒ 结论：**这个文件里的上游代码不能无脑逐字搬**，凡"脚本里提前抓节点"的写法都要改成惰性。
  ⚠️ **加载页那段脚本曾经整块不执行（症状：进度条不动、终端不刷、诊断行停在初始文字）。
     真因有两个，都只会在浏览器里**静默**失效 —— 编译 0 errors、生成的 HTML 也完整**：
  1. **数组尾逗号**：上游把启动消息拼成 `[ "a","b", ]`。BYOND 内嵌浏览器是**老 IE 引擎**，
     数组字面量里的**尾逗号**会直接抛语法错误 ⇒ **整段 `<script>` 被丢弃**
     ⇒ 已改成 `var terminal_lines = [];` + `terminal_lines.push("…")` 逐条添加。
  2. **未定义引用**：把进度条改成"本页时钟驱动"时删掉了 `progress_completion_time` 的声明，
     却留下引用它的 `var srv_total = progress_completion_time;` ⇒ `ReferenceError`
     ⇒ **脚本在 `setInterval` 之前中止**。已移除该引用（估时固定 150 秒，
     服务端 `update_loading_progress` 只用来**修正**它）。
  ⇒ **定位办法（本模块反复靠它才抓到）**：按 DM 字符串规则把**生成出来的页面 JS 切出来**，
     丢进 node 跑一遍。编译通过、HTML 完整，都**不能**证明那段脚本能在浏览器里跑。
  ⇒ **另一条独立的坑**：进度动画别拿「world.timeofday − 服务端开局时刻 / 历史平均估时」算比例 ——
     开服几分钟后才连进来的人分子早已超过分母 ⇒ 条**满格不动**。改成分子＝本页运行时长。
  ⚠️ **另有两处上游老毛病，补回 JS 之后才暴露出来，已在本模块页面侧兜住**：
  1. **不能整块重写按钮的 `innerHTML`**：上游把 `☒/☑ READY` 写成**英文常量数组**、点击后整块覆盖
     ⇒ 会把服务端渲染并**已汉化**的文字顶掉（实测：点一下准备，中文「准备」变回英文「READY」）。
     本模块改为**只改里面那个 `<span>` 的 class 与图标字符**，按钮文字一律不动
     （图标与语言无关，硬写没问题）。
  2. **`update_loading_progress` 收到的参数是坏的**：服务端用
     `output(list2params(list(a, b)), "…:update_loading_progress")` 推（上游写法），
     而 BYOND 到 browser 会把文本**按 URL 参数解析** ⇒ 页面只收到**一个** `"a=b"` 形式的参数
     ⇒ `total_time` 为 `undefined` ⇒ `parseFloat(undefined)` = `NaN`
     ⇒ `progress_completion_time` 变 NaN ⇒ **进度条整根不动**
     （实测症状：「开服以后那个加载条不动，加载完直接进去」）。
     本模块在页面侧拆 `"="` 兜住，并加"**坏值一律不采纳**（NaN/0 都跳过）+ 用内联估计值保底"
     ⇒ 进度条永远不会卡死（最多是估得不准）。
     ⚠️ 这条正是 readme 上一节「推送的两个约束」里点名的那个坑 —— 本模块只在**页面侧**兜，
     **没有**去改上游的 `title_screen_subsystem.dm`。

**2) `new_player.dm`**（上游：`modular_nova/modules/title_screen/code/new_player.dm`）

- **唯一实质差异**：`play_lobby_button_sound()` 的音效路径
  `modular_nova/master_files/sound/effects/save.ogg` → 本模块自带的
  `modular_tianguan/modules/tg_lobby/sound/button_click.ogg`
- 其余（`Topic()` 全部分支、`server_swap()`、`playerpolls()`、`/datum/asset/simple/lobby` 资产投递等）与上游**逐字一致**
- 验证方式：`diff` 上游版与派生版，差异应只有注释 + 那一行音效路径
- ⚠️ 上游 `server_swap()` 单服务器分支有个既有 bug：弹窗按钮给的是 `"Send me there"`，
  而下一行判的是 `if(confirm == "Connect me!")`，条件永远不成立。
  **本模块照抄未修** —— 不属于本次范围，保持"只差音效一行"更便于日后同步核对。

### 左下两个跳转栏（外链）：

- **外链必须走 `byond://`**：BYOND 的 browser 不跟 `http://` 直链（点了没反应），
  做法是 `<a href='byond://?src=…;tg_ext=wiki'>` ⇒ `Topic()` 里 `client << link(url)` 交给系统默认浏览器。
  不接受任意 URL 从页面传进来（只认 `wiki` / `afdian` 两个键）。
- **图标必须走 `browse_rsc`**：写文件路径浏览器取不到，要像顶部展示图那样
  `src << browse_rsc(file(path), "名字.png")` 投给客户端，`<img src>` 用**投递后的短资源名**（**要带扩展名**，`browse_rsc` 靠它判类型）。
  图标放本模块 `icons/`（`wiki.png`、`moneybag.png`），由 `/mob/dead/new_player/proc/tg_lobby_ext_icon()` 投递。
- **钱袋是像素图**（游戏内 `/obj/item/storage/bag/money` 的 `moneybag` 图标，32×32）：网页里加
  `image-rendering: pixelated` + `-ms-interpolation-mode: nearest-neighbor`，1:1 不放缩；wiki 那张是平滑图，默认平滑缩放。
- **彩虹字**：用 `@keyframes` 循环 `color`（6 个色相点），**不能用 `filter: hue-rotate()`**（IE 内核不支持）。

### 收起机制（含错位动画）：

一条规则族驱动三处，错位由 `transition` 的时长/延迟造出来：

| 元素 | 展开 | 收起 | 动效 |
| --- | --- | --- | --- |
| `.tg_dock`（收起把手的外壳） | `50vmin` | `2.5vmin`（**留在左缘**，否则收起后没有东西可点开） | `0.14s`，无延迟，先走 |
| `.tg_extlinks`（两个跳转栏） | `50vmin` | **`-20vmin`（滑出屏幕左侧、消失）** | `0.14s`，无延迟，先走 |
| `.tg_side`（侧边栏） | `0` | `-51vmin` | `0.22s`，延迟 `0.06s`，后走 |

⇒ 观感是「**两个跳转栏先滑走、侧边栏随后滑走**」。

⚠️ **结构铁律：`.tg_extlinks` 必须是 `.tg_dock` 的兄弟，不能放在它里面。**
`.tg_dock` 是 `position: absolute` ⇒ 放在里面时两个跳转栏的 `left` 会**相对 dock 再叠加一次**，
实测表现为「展开时两个框跑到屏幕右外很远」（dock 50vmin + 框 50vmin = 100vmin）、
「收起时看着几乎没动」（2.5 + 2.5 = 5vmin）。改样式前先确认这一层嵌套关系。

### 按钮音效：

`sound/button_click.ogg`（0.65 秒，44.1kHz 立体声，Vorbis）。**用 OGG 而不是 MP3 是刻意的** ——
BYOND 官方文档两种都支持，但 MP3 在 BYOND 的 **Linux** 版上不可靠，而本服务器线上跑的是 Debian。

### 实时刷新机制（改角色后侧边栏跟着变）：

`/datum/preference_middleware/tianguan_lobby` 是一个**新增子类型**，靠上游的
`subtypesof(/datum/preference_middleware)` 自动注册（`code/modules/client/preferences/assets.dm:44`），
因此无需改动任何上游 middleware。它在 `post_set_preference` / `on_new_character` 时调用
`/client/proc/tg_push_lobby_card()` 重算头像与偏好摘要并推给页面。

**职业是特例**：改职业走 `action_delegations` → `/datum/preference_middleware/jobs/proc/set_job_preference`，
**不经过** `post_set_preference`（症状：改完职业要切一次角色槽位才生效）。
也不能自己注册一个同名 delegation 去补 —— `preferences.dm:372-375` 的派发命中第一个就 `return`，
而上游 jobs middleware 的 include 顺序在前，永远轮不到本模块。
本模块改为挂上游在那里发出的信号 `COMSIG_JOB_PREF_UPDATED`
（`code/__DEFINES/~nova_defines/signals.dm:110`）：在 `tg_lobby_card_html()`
（每次生成页面必跑）里 `RegisterSignal(..., override = TRUE)`，收到即推。
参考实现：`modular_nova/modules/job_estimation/job_estimation.dm:99`。

### 头像渲染（与角色设置保持一致）：

头像**直接复用角色设置里那套渲染** ——
`/datum/preferences/proc/render_new_preview_appearance(mannequin, show_job_clothes)`
（`code/modules/mob/dead/new_player/preferences_setup.dm:97`，角色设置的
`/atom/movable/screen/map_view/char_preview` 就是调它）。它一函数包办：
取最高优先职业 → `apply_prefs_to` → **按玩家自己的 `preview_pref` 决定穿制服 / loadout / 内衣 / 裸体**
→ 叠加视觉 trait → 应用身高 → 返回 `mannequin.appearance`。
本模块再 `getFlatIcon(appearance, SOUTH, no_anim = TRUE)` 拍成 icon 送 base64。

于是「角色设置里什么样，大厅里就什么样」。**不要**退回
`get_flat_human_icon(..., job, ...)`：那条路只走 `job.outfit`，既漏 loadout 又无视 `preview_pref`。
取职业也请用上游现成的 `get_highest_priority_job()`，别自己遍历 `job_preferences`。

### 推送的两个约束（都踩过坑）：

- **每个字段单独调用一次 `output()`，只传标量。**
  BYOND 的 `output()` 到 browser 会把文本按 URL 参数解析（`&`/`;` 分隔多个参数），而
  `list2params(lst)` 要求列表是 key/value 交替 —— 直接塞 `list(a, b, c)` 会得到畸形串，
  JS 侧根本收不到多个参数。（上游 Nova 的 `update_loading_progress` 就踩了这个坑，未修，不在本模块范围。）
- **base64 里的 `+` 会被 URL 解码成空格**，所以 JS 侧必须 `.replace(/ /g, "+")` 还原，
  否则 PNG 数据损坏、头像显示成一个叉。

### ⚠️ 不要用 `title_screen_is_ready` 做门槛：

`/mob/dead/new_player/title_screen_is_ready` 唯一的置位点是页面底部那句 XHR
（`?src=...;title_is_ready=1`），实测**从未置位过**，永远是 `FALSE`。
上游 `update_character_name()` 和 `add_startup_message()` 都拿它当门槛，因此一直是坏的
（本模块对后者无能为力，对前者已在推送里补发 `update_current_character`）。
本模块推送**刻意不检查它** —— 玩家能打开角色设置改东西，本身就证明大厅页面已加载。

### 性能：

头像走 `render_new_preview_appearance()`（构造 dummy human → 套外观 → 按 `preview_pref` 穿戴 →
叠加 trait → 应用身高 → 拍平），单次约几十到上百毫秒，已放在 `INVOKE_ASYNC` 里，不阻塞设置界面响应。

### Defines：

- `MAX_STARTUP_MESSAGES`（随文件携带，同上游）
- `TG_LOBBY_ART_CANDIDATES`（`title_screen_html.dm` 内使用，末尾 `#undef`）
- `TG_LOBBY_CSS`（同上）
- `TG_LOBBY_AVATAR_DIRS`（`lobby_card.dm` 内使用，末尾 `#undef`）

### 本模块目录外的依赖文件：

- `config/nova/title_html.txt` —— 页面骨架与基础 CSS 仍由它提供（**运行时配置文件，未修改**）。若该文件缺失，`SStitle` 会回退到 `DEFAULT_TITLE_HTML`，侧边栏样式依然生效（本模块的 CSS 是追加注入的）
- `modular_nova/modules/title_screen/icons/loading_screen.gif` —— 侧边栏顶部展示图的兜底（可被本模块 `icons/lobby_art.gif` 覆盖）
- `code/modules/client/preferences/assets.dm` —— 依赖其 `subtypesof(/datum/preference_middleware)` 自动注册机制（只读依赖）
- `code/datums/holocall.dm` / `code/modules/admin/verbs/selectequipment.dm` —— 头像生成沿用它们所用的 `get_flat_human_icon()` + `icon2base64()` 现成模式（只读依赖）

### 换个 GIF / 图：

把文件丢进 `modular_tianguan/modules/tg_lobby/icons/`，命名 `lobby_art.gif`（或 `lobby_art.png`）即可，按候选顺序优先于上游兜底图。

### 测试方式：

- `byond/bin/dm.exe -DCBT tgstation.dme` → 0 errors 后启动 `dreamdaemon`，本地连 `byond://127.0.0.1:1337` 查看大厅
- 改角色槽位 / 改角色设置（种族、发色等）→ 侧边栏头像与偏好摘要应即时刷新
  （若没刷新，查 `data/server.log` 里的 `TG_LOBBY:` 行，定位是钩子没触发、还是被 `title_screen_is_ready` 门槛挡住）
- 点侧边栏右缘把手 → **两个跳转栏与侧边栏先后向左滑出、背景完整露出**；再点 → 滑回
- **收起/展开各点两次以上**：确认第二次能回来（曾被 `output()` 投数字 `0` 时那次 JS 调用不触发而卡住，
  现改投字符串 `"1"`/`"0"`）
- 点两个跳转栏 → 用系统默认浏览器打开对应链接（验 `byond://` + `link()` 这条路）
- ⚠️ 编译会覆盖 `tgstation.dmb`，而 **dmb 里的字符串是编码的、`grep` 搜不到内容**；判断 dmb 是否为最新只能比对文件时间戳（dmb 必须晚于所有 `.dm` 的修改时间）

### ⚠️ DM `{"..."}` 字符串与浏览器行为的坑（都实测踩过）：

- **`[` 必须写成 `\[`**，否则被当成 DM 内嵌表达式，字符串被截断。
- **不要在这个字符串里写正则字面量**：`\s`、`/g`、`^…$` 之类在 DM 转义规则下会失真，
  编译期报 `error: text"`（症状是"改了代码但编译不过，于是服务器跑的还是旧版本"）。
  页面 JS 里要处理字符串就用 `indexOf` / `split` / 循环，别用正则。
- **CSS 注释里不能用裸的 ASCII 双引号**（`"`）—— 它会**提前结束** DM 的 `{"..."}` 字符串，
  其后所有 CSS 静默丢失。注释里用「」代替。
- **`output(0, "…:fn")` 投数字 0 时，那次 JS 调用可能不触发** ⇒ 投字符串 `"1"`/`"0"`，JS 侧两种都认。
- **不要整块覆盖 `document.body.className`**（会擦掉 body 上其它类，且 IE 内核下清空不总是生效）；
  只增删自己那一个类。
- **`show_title_screen()` / `update_title_screen()` 是"硬更新"**（整页重投，注释里自己写了
  "causes visual glitches if used"）⇒ 收起这种频繁交互**不要**走它，否则闪屏且丢动画。

### 致谢：

布局与视觉需求：mohu19
上游大厅实现来源：Nova Sector（`modular_nova/modules/title_screen/`），其又派生自 Skyrat-tg / TauCeti
