https://github.com/89623/TianGuan13/pull/<!--PR 编号-->

## 大厅标题界面：侧边栏布局 + 磨砂玻璃质感

模块 ID：`TG_LOBBY`

### 说明：

重做大厅（标题界面）的视觉与布局，把原本居中悬浮的菜单框改成左侧固定侧边栏，并换成半透明玻璃质感：

- **左侧边栏**（自上而下）：顶部展示图 → 角色头像 + 角色名 + `ID: ckey · 槽位 N` → 角色偏好摘要（种族/年龄/性别/职位）→ 原有全部按钮（功能不变，仅位置与样式变化）
- **右上角**：通知栏（承接 `SStitle.current_notice` 管理员公告）
- **可收起**：侧边栏右缘有一个把手（◀/▶），点击即把侧边栏滑出屏幕、让出背景；再点滑回。默认展开，纯 CSS checkbox 实现，无 JS、不刷新页面
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
- **其余 JS**（`toggle_ready` / `toggle_antag` / `update_current_character` / `append_terminal_text` / `update_loading_progress`）与上游一致

**2) `new_player.dm`**（上游：`modular_nova/modules/title_screen/code/new_player.dm`）

- **唯一实质差异**：`play_lobby_button_sound()` 的音效路径
  `modular_nova/master_files/sound/effects/save.ogg` → 本模块自带的
  `modular_tianguan/modules/tg_lobby/sound/button_click.ogg`
- 其余（`Topic()` 全部分支、`server_swap()`、`playerpolls()`、`/datum/asset/simple/lobby` 资产投递等）与上游**逐字一致**
- 验证方式：`diff` 上游版与派生版，差异应只有注释 + 那一行音效路径
- ⚠️ 上游 `server_swap()` 单服务器分支有个既有 bug：弹窗按钮给的是 `"Send me there"`，
  而下一行判的是 `if(confirm == "Connect me!")`，条件永远不成立。
  **本模块照抄未修** —— 不属于本次范围，保持"只差音效一行"更便于日后同步核对。

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
- 点侧边栏右缘把手 → 侧边栏滑出、背景完整露出；再点 → 滑回
- ⚠️ 编译会覆盖 `tgstation.dmb`，而 **dmb 里的字符串是编码的、`grep` 搜不到内容**；判断 dmb 是否为最新只能比对文件时间戳（dmb 必须晚于所有 `.dm` 的修改时间）

### 致谢：

布局与视觉需求：mohu19
上游大厅实现来源：Nova Sector（`modular_nova/modules/title_screen/`），其又派生自 Skyrat-tg / TauCeti
