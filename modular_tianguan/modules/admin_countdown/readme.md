https://github.com/89623/TianGuan13/pull/<!--PR 编号-->

## 全局倒计时（管理员「秘密」面板里的演出用倒计时）

模块 ID：ADMIN_COUNTDOWN

### 说明：

给所有玩家屏幕推送一个**倒计时提示**，供管理员设计场景/演出时使用：

- **标题**（可留空） + **倒计时**（如 `3:00`）；
- 倒计时走完后显示**结束文本**（可留空）并保留**指定时长**，到期自动消失；
- 面板内可**暂停/继续**、**结束**（文本与计时一起消失，回到「未进行任何设置」）、
  以及**随时更改标题 / 更改结束文本**；
- **三处颜色各自独立可调**：**标题 / 倒计时 / 结束文本** 三行颜色互不影响 ✓。
  每行都有：十六进制输入框（`#RGB`/`#RGBA`/`#RRGGBB`/`#RRGGBBAA` 或 `gold`、`red` 这类色名）+ 当前色块预览
  + 「应用」+ **「取色」按钮**（调用本仓现成的 `tgui_color_picker()` ⇒ 走 TGUI 的 `ColorPickerModal` 取色窗，
  客户端关了 tgui_input 时回退拜恩原生取色环）+ 6 个预设色按钮。
  **颜色会被校验**后才拼进 maptext 的内联 CSS，非法值一律回退白色（不会把任意字符串塞进 HTML）。
  ⚠️ `tgui_color_picker()` 是**阻塞**的（内部 `picker.wait()`）⇒ 必须 `INVOKE_ASYNC` 调起，
  否则会把面板的 `ui_act` 卡住直到取色结束；取完用 `SStgui.update_uis(src)` 让面板回显新颜色。
- **纯演出，不产生任何玩法效果**：不判胜负、不触发事件、不改动任何游戏状态。

入口：管理员「秘密」面板 → Fun 页签 → 「全局倒计时」按钮 → 打开本模块自己的 TGUI 面板。

### 实现要点

- **显示层复用回合结束倒计时的做法**：`/atom/movable/screen/reboot_timer`
  （`code/__HELPERS/roundend.dm`）就是「maptext 屏幕元素 + `MAPTEXT_PIXELLARI` 描边字体」，
  本模块照此定义 `/atom/movable/screen/tianguan_countdown`，位置/尺寸/图层与它逐项相同。
  差异：那个元素由 ticker 每 tick 刷新且只在回合结束后挂载；本模块自带状态机与 1 秒循环，
  **自己负责挂载/摘除**。
- **挂载不需要核心钩子**：1 秒循环里顺带把元素补挂到所有 `GLOB.clients`
  （含中途加入的玩家），因此**没有**改 `code/modules/mob/login.dm` 那类登录挂载点。
- 状态机：`IDLE`（未设置，屏幕无内容）→ `RUNNING` ⇄ `PAUSED`（时间冻结，显示「已暂停」）
  → `ENDTEXT`（只显示结束文本）→ 到期自动回 `IDLE`。
- ⚠️ **计时方式：以"截止时刻"为准，不做逐跳累减**（2026-10 实测修正）。
  最初写法是 1 秒循环里 `remaining -= 10`，玩家实测**偶发"倒计时走得快一倍多"**（且不是每次都能复现）
  —— 这是 tg 计时器在服务器卡顿/补跳时短时间内连续触发造成的抖动，逐跳累减会把抖动**累积**成误差。
  现在改为：启动时记 `running_deadline = world.time + 剩余`，每一跳用 `max(deadline - world.time, 0)`
  **反推**剩余 ⇒ 与真实时间始终一致，卡顿后自动追上、不会越走越快；暂停 = 冻结当前值并把截止时刻清 0，
  继续 = 从冻结值重新算截止时刻。结束文本阶段同理（`end_deadline`）。
- 时间文本用 `DisplayTimeText()`（本仓已做本地化 ⇒ 显示为中文时长），与回合结束倒计时一致。
- 面板：`/datum/tianguan_countdown_ui`（`ui_state = ADMIN_STATE(R_ADMIN)`）+ 前端
  `tgui/packages/tgui/interfaces/TianGuanCountdown.tsx`。

### 核心文件 / Proc 改动：

- `code/modules/admin/verbs/secrets.dm` —— `ui_act()` 里 **4 行**最小钩子
  （`TIANGUAN EDIT ADDITION`）：把动作交给模块的 `tianguan_countdown_ui_act()`，
  返回 TRUE 即 `return`，否则原样继续原 `switch(action)`。
  **为什么不能完全模块化**：秘密面板的 `ui_act` 是一个大 `switch`，动作分发没有注册表可挂
  （DM 无反射），要在面板里加动作只能在该函数体内插钩子。
- `tgui/packages/tgui/interfaces/Secrets.jsx` —— Fun 页签里 **1 个按钮**
  （`{/* TIANGUAN EDIT ADDITION */}` 标记），点击发 `act('tianguan_countdown_open')`；
  另把该面板窗口从 `width={500} height={520}` 改成 `width={660} height={520}`（`TIANGUAN EDIT CHANGE` 标记，
  备注原文）：加了按钮后 Fun 页签首行由 3 个变 4 个按钮，500 宽放不下、会把最后一个顶出可视区。

### 模块化覆盖：

- 给 `/client` 新增 1 个模块私有 var（`tianguan_countdown_ui`，面板 datum 缓存）；
  新增 1 个全局 datum（`GLOB.tianguan_countdown`，控制器的懒创建入口）；
  新增 1 个 `/atom/movable/screen` 子类型 —— **不改动任何既有类型的既有 var**。

### Defines：

- `TIANGUAN_CD_IDLE` / `_RUNNING` / `_PAUSED` / `_ENDTEXT`（状态机常量，模块内使用）

### 本模块目录外的依赖文件：

- 无（仅需 `tgstation.dme` 两行 include：
  `modular_tianguan\modules\admin_countdown\code\admin_countdown.dm` +
  `modular_tianguan\modules\admin_countdown\code\countdown_music.dm`）
- 复用到的既有机制：`MAPTEXT_PIXELLARI()`、`DisplayTimeText()`、`SCREENTIP_LAYER`、
  `SStgui` + `ADMIN_STATE()`、`addtimer(TIMER_LOOP|TIMER_STOPPABLE)`、`log_admin()`
- 前端：新增 `tgui/packages/tgui/interfaces/TianGuanCountdown.tsx` + `Secrets.jsx` 一个按钮。
  ⚠️ **`tgui/public/` 是构建产物、不进仓库**（`tgui/.gitignore` 里 `/public/**/*`）⇒
  **每个要跑本模块的服都得自己跑一次前端构建**，顺序不能颠倒：

  ```sh
  cd tgui && bun install --frozen-lockfile   # 首次才有必要（≈1 分钟）
  ./node_modules/.bin/rspack.exe build       # 产出 tgui/public/tgui.bundle.js（≈40 秒）
  cd .. && rm -f tgstation.rsc               # 前端变了必须重建资源包，否则新 bundle 打不进去
  ./byond/byond/bin/dm.exe tgstation.dme     # 然后才是 DM 编译
  ```

  **只编 DM、不建前端** ⇒ 秘密面板里会出现「全局倒计时」按钮，但点开是空白/旧界面（JSX 没进 bundle）。
  另：本仓 `tgui:build` 脚本会先跑 `tools/i18n/tgui-catalog.mjs extract`（会动 i18n 目录）；
  只想打包前端时跳过它、直接 `rspack build` 即可（本模块的中文界面文案不依赖 i18n 表）。

### 测试方式：

1. 编译：`dm.exe tgstation.dme` ⇒ `0 errors`；前端：`tgui/` 下 `rspack build` ⇒ `compiled successfully`，
   且 `grep -c TianGuanCountdown tgui/public/tgui.bundle.js` = 1；
2. 游戏内（管理员，需 `R_ADMIN`）：秘密面板 → Fun → 「全局倒计时」→ 填标题/秒数/结束文本/结束文本秒数
   → 开始 ⇒ 所有玩家屏幕中央出现「标题 + 倒计时」；
3. 面板内点「暂停倒计时」⇒ 数字冻结并显示「已暂停」（停 5 秒后数字应**完全不变**）；再点「继续倒计时」⇒ 从冻结值接着走；
3b. **走时精度**：设 5 分钟，拿手机秒表比对 —— 屏幕从 5:00 走到 0:00 应与真实 5 分钟一致（误差应在 1~2 秒内）；
   这条是修正"偶发快一倍"后的回归项，务必跑一次；
4. 倒计时归零 ⇒ 屏幕只剩结束文本，持续设定秒数后自动消失（面板状态回到「未进行任何设置」）；
5. 「结束倒计时」⇒ 文本与计时立即消失，状态回到未设置；
6. 「更改标题」/「更改结束文本」⇒ 运行中即时生效（不重置剩余时间）；
6b. 「颜色」区：给标题/倒计时/结束文本各填一个 `#RRGGBB`（或点预设色按钮）⇒ 屏幕上三行颜色应各自独立变化；
   点行尾的「取色」按钮 ⇒ 弹出取色窗（TGUI 取色器/拜恩色环）取色后，面板色块与屏幕颜色都应立刻跟上；
   填个非法值（如 `xyz`）⇒ 回退成白色而不是渲染崩坏；
6c. 打开「秘密」面板时 Fun 页签首行 4 个按钮**全部可见**、不需要横向拉伸；
7. 边界：中途有玩家登录 ⇒ 也应看到倒计时（1 秒循环补挂）；
8. 回退验证：本模块的核心钩子**不是可选**的 —— 模块不在时 `secrets.dm` 里那 4 行钩子会因
   `tianguan_countdown_ui_act` 未定义而**编译报错**（响亮失败）。因此回退要**同时**做两件事：
   注释掉那 4 行钩子 + 移除本模块 include（前端按钮删不删都行，点了没反应而已）。

---

## 倒计时内的「优化放歌」（歌曲预传输 + 到点播放）

模块内的第二部分：借用倒计时这段**时间窗**，把曲目**提前、错峰**传给每个玩家，
到点再播放 ⇒ 消除「播放那一瞬间所有客户端同时来拉同一个文件」造成的卡顿。

### 要解决的问题：

原版「播放全局音效」（`code/modules/admin/verbs/playsound.dm`）与点唱机都是**在播放那一刻**
给每个玩家各发一份音频文件：几十人同时拉同一个文件 ⇒ 瞬时占满带宽 ⇒ 卡顿。

### 做法：

把「下载」从播放那一刻**提前**，并在倒计时期间**按份错峰**分发：

- **曲目来源 = 点唱机曲库** `config/jukebox_music/sounds/`（`CONFIG_JUKEBOX_SOUNDS`）。
  管理员用「点唱机上传音乐」传过的 .ogg **全部直接可用**；解析规则与点唱机一致
  （文件名 `标题+节拍+…` 用 `+` 分隔 ⇒ 取第一段为显示名。见 `code/datums/components/jukebox.dm`）。
  **本模块不内置任何曲目**，只读这个目录 —— 与管理员的上传习惯共用同一份数据。
  面板里也放了「上传音频」按钮（直接复用现成 verb，不复制一份上传逻辑）+「刷新列表」。
- **传输通道** = 与 tgui 同一套 `browse_rsc` 资源通道（`SSassets.transport.send_assets`），
  注册时**按需**（`register_asset`，上传的文件不是编译期常量）。
- **一份 = 一个玩家的一首歌**，铺成**全局单条队列**，按节奏**一份一份**推
  （只有一首歌时，「份」就等于「人」，与管理员的心智一致）。
- **节奏**：`自动 = 剩余时间 × 75% ÷ 剩余份数`；管理员可在面板改**手动「秒/份」**。
- **第一份立刻推**（进度条马上有动静，不用等一个间隔）。
- **倒计时途中新加入的玩家**：每秒补登一次，把他们的份额追加进队列（不会漏人）。
- **到点播放**：构造方式**照抄点唱机**（`sound(路径)` + `channel = CHANNEL_JUKEBOX`）；
  多首**按各自时长连播**；音量 = 面板音量 × **该玩家自己的** `sound_midi` 偏好
  （偏好为 0 的玩家跳过、不打扰）。
- **纯准备模式**：倒计时**不给玩家显示任何屏幕元素**（标题/数字/结束文本全不显示），
  只当"放歌准备窗"用 —— 面板里照常走时。

### 为什么这样能治卡顿（实测证据链）：

1. **客户端缓存按「文件内容 MD5」寻址** —— `code/modules/asset_cache/asset_cache_item.dm`：
   `hash = md5asfile(file)`，与资源名叫什么无关。因此**预传输放进缓存的副本，与播放时要找的
   是同一份** ⇒ 两条路天然共享缓存。
   ⚠️ **所以绝对不要**给这些资源设 `keep_local_name`：那会改成按**原文件名**存，
   反而与播放时的内容寻址**失配**、导致重新下载。
2. **实测（本机 127.0.0.1，60 秒倒计时）**：
   - 一首**从未缓存过**的曲目，其文件在**播放前 12 秒**就已落到客户端缓存
     （`Documents\BYOND\cache\<…>\asset.<内容md5>.ogg`，字节数与曲目**逐字节相同**）；
   - 那段时间的服务端日志里**没有任何播放事件** ⇒ 只能是预传输写的；
   - 已缓存曲目再次播放 ⇒ 客户端缓存**零新增**（即不再下载）。
3. **结论**：**播放那一刻客户端不需要下载** ⇒ 原来"几十人同时拉同一个文件"的尖峰被消除。

### 面板（两个窗口）：

- **主面板**新增一栏「倒计时音乐（预传输）」：纯准备模式开关 / 曲目多选（每条带**试听**）/
  音量 / 传输节奏（`0 = 自动`，右侧实时显示当前"秒/份"）/ **摘要** +「**查看传输详情**」按钮；
- **独立窗口** `TianGuanCountdownTransfer`：玩家数常有五六十人，主面板那条窄列表铺不开 ⇒
  这里按**玩家数自动换行**铺成网格，**每个玩家名字下面一条小进度条**（就绪绿 / 传输中白 / 离线红）；
- 两个窗口在倒计时运行中**每秒自动刷新**（面板回显只能由服务端推：循环里 `SStgui.update_uis`）。

### 诊断日志（排查"没声音"先看它）：

每次播放/试听都会往 `log_world()` 打一行：曲目名、完整路径、**文件是否存在**、基准音量、
**送达几人**、因音量偏好为 0 跳过几人、**最小实际音量**。
本项目实测就是靠它先把服务端一侧洗清（文件在、音量算出、`SEND_SOUND` 送达 ⇒ 问题在播放构造），
再去对照能响的那条路。**出问题先看这行，别猜。**

### 已知边界（不打包票的部分）：

- **单机验证的是机制**，不是 50 人的真实带宽表现。峰值已被摊平（前 75% 时间逐份推）+
  播放时零下载，**机制上成立**，但真实人数下的表现仍需在有人数的服上确认。
- **客户端本地解码**（几十人同时解码一个大文件）与传输无关，本功能治不了 ——
  若卡顿是这个成因，要动的是音频本身（时长/码率）。

### 调试记录（踩过的坑，别再踩）：

- **播放构造**：`sound(路径)` + `CHANNEL_JUKEBOX`（照抄点唱机）。
  **不要**用「新建 sound + `.file = file(路径)` + `CHANNEL_ADMIN` + `status = SOUND_STREAM`」——
  实测该形状在客户端**完全无声**，而服务端日志一切正常（文件存在、音量算出、`SEND_SOUND` 送达）。
  另外**不要**乘 `admin_music_volume`（点唱机那条能响的路不乘它）。
- **传输时间窗不能占满整个倒计时**：曾按 100% 平摊 ⇒「1 个人 1 份」时那一份会卡在**归零那一刻**
  才推，而此时 `state` 已非 `RUNNING`、推送被守卫拦掉 ⇒ **进度条永远停在 0/N 却照样播放**。
  现改为只占 **75%**，留 25% 余量。
- **曲目时长必须按需算**：`SSsounds.get_sound_length()` 会**读文件**；若放在曲库构建里，
  每次开面板/重建曲库都会把所有音频读一遍 ⇒ **打开面板卡顿**。现改为连播时按需计算并缓存。
- **曲库要按「目录清单是否变化」重建**：曾用一次性 `static` 缓存 ⇒ 管理员新传的歌**永远不出现**。
  判据用 `length(flist(...) ^ 缓存清单) == 0`（对称差为空 = 没变）。
- **上传按钮不要复制实现**：走 `SSadmin_verbs.dynamic_invoke_verb(user, /datum/admin_verb/upload_jukebox_music)`
  正规入口，权限检查与参数收集都由它负责；直接调 `/client/proc/__avd_*` 会被 `CanProcCall` 拦下并通报。

### 本模块目录外的依赖文件：

- 仅 `tgstation.dme` 两行 include（本文件 + `countdown_music.dm`）。
- 复用到的既有机制：`SSassets.transport`（`register_asset` / `send_assets` / `browse_queue_flush`）、
  `CONFIG_JUKEBOX_SOUNDS` / `JUKEBOX_NAME` / `IS_SOUND_FILE_SAFE` / `strip_filepath_extension`、
  `SSsounds.get_sound_length()`、`SSadmin_verbs.dynamic_invoke_verb()`、
  `SEND_SOUND()` / `CHANNEL_JUKEBOX`、`addtimer`。
- 前端：新增 `tgui/packages/tgui/interfaces/TianGuanCountdownTransfer.tsx`
  （界面靠 `routes.tsx` 的 `require.context('./interfaces', …)` **自动收集** ⇒ 只要导出的组件名
  与后台 `new(user, src, "TianGuanCountdownTransfer")` 一致即可，无需登记）。
  ⚠️ 老规矩：**`tgui/public/` 是构建产物、不进仓库** ⇒ 每个要跑本模块的服都得自己 `rspack build`
  再删 `tgstation.rsc` 再编 DM（顺序见上文主章节的代码块）。

### 测试方式（音乐部分）：

1. 先在一首曲子上点「**试听**」⇒ 应能听到（这是最快的声音链路自检）；
2. 选 1 首 + 勾「**纯准备模式**」+ **60 秒** → 开始 ⇒
   - **第 1 秒**进度条就应有反应（第一份立刻推）；
   - **约第 45 秒**（`60 × 75%`）应推完 ⇒ 玩家行变「就绪」；
   - 倒计时期间**玩家屏幕上不应出现任何倒计时元素**（纯准备模式）；
3. 到点 ⇒ **播放**（有声音；多首则按各自时长连播）；
4. **缓存命中验证法**（本项目就是这么做实的）：
   - 选一首**从未播放过**的曲目，开 60 秒倒计时；
   - 期间盯客户端 `C:\Users\<你>\Documents\BYOND\cache\<最新 tmp 目录>\`，
     看是否出现新的 `asset.<32位md5>.ogg`，**比对其字节数**是否等于该曲目文件；
   - 若它在**播放之前**就已出现 ⇒ 预传输生效 ✓；再看**播放那一刻**是否还有新增
     ⇒ 无新增 = 命中缓存 = 播放不再产生下载 ✓；
5. 边界：倒计时中途登录一个小号 ⇒ 它也应被补登（进度表里出现该玩家并逐份推进）；
6. 静音玩家：把自己的「管理员音乐」音量调 0 或 `sound_midi` 偏好设 0 ⇒ 应**听不到**（设计如此），
   且诊断日志会写明"跳过 N 人"。

### 致谢：

- 需求与验收：用户
