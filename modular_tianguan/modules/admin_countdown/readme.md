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

- 无（仅需 `tgstation.dme` 一行 include：
  `modular_tianguan\modules\admin_countdown\code\admin_countdown.dm`）
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

### 致谢：

- 需求与验收：用户
