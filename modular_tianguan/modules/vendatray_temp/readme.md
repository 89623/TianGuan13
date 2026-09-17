## Vend-A-Tray 临时核心补丁

模块 ID：VENDATRAY_TEMP

本模块**没有代码文件**，只用于登记一处无法模块化的核心文件改动，方便上游同步时复查。

### 说明：

让 Vend-A-Tray（`/obj/structure/displaycase/forsale`，用读卡器 + 展示箱体组装出的自动售货展示台）恢复"托盘打开时可以把物品放上展示台"的行为。

上游（/tg/station 与 NovaSector 的 `code/game/objects/structures/displaycase.dm`）的 `/forsale/item_interaction()` 是**完全覆盖**父类型的：

- 持 ID 卡 → 注册/开锁
- 持 PDA → 拦截
- 其它物品 → 仅 `SStgui.update_uis(src)` 后返回 `ITEM_INTERACT_SUCCESS`

它既不调用 `..()`，也没有父类型 `if(open && !showpiece)` 那段插入分支，所以**不打开 UI 直接拿物品点托盘时，物品会被静默丢弃**（无任何提示、无报错）。这是天关补的功能，上游没有。

### 核心文件 / Proc 改动：

- `code/game/objects/structures/displaycase.dm`
  - `/obj/structure/displaycase/forsale/item_interaction()`：在 PDA 拦截之后、末尾 `SStgui.update_uis(src)` 之前，增加 `if(open && !showpiece)` 分支，调用 `insert_showpiece(tool, user)`、刷新 UI 并返回 `ITEM_INTERACT_SUCCESS`（与父类型同形，成功与否都吞掉攻击链）。
  - 文件头（第 2-5 行）有 `TIANGUAN EDIT - VENDATRAY_TEMP` 台账注释。

对比父类型 `/obj/structure/displaycase/item_interaction()` 可见一模一样的分支，改动只是把它接回 `/forsale` 的覆盖里，**没有新增任何字符串**（不涉及 `LANG()` 与目录 key）。

额外那一行 `SStgui.update_uis(src)` 是必要的：`/forsale/insert_showpiece()` 只调 `update_static_data_for_all_viewers()`（推图标），而 `product_name` / `product_cost` 走 `ui_data()`（动态数据），且 Vend-A-Tray 的窗口是 `set_autoupdate(FALSE)`。不刷新的话，物品已经放进去了，UI 上还显示"未放置物品"。

### 为什么不能模块化：

`/obj/structure/displaycase/forsale/item_interaction()` 的上游实现里，末尾那条 `SStgui.update_uis(src); return ITEM_INTERACT_SUCCESS` 会吞掉所有非 ID 卡物品。要从未被调用的父类型分支里补回插入逻辑，只能改这个 proc 本体的控制流。

理论上可通过给 `/obj/structure/displaycase/forsale/Initialize()` 注册 `COMSIG_ATOM_ITEM_INTERACTION` 信号并返回 `COMPONENT_CANCEL_ATTACK_CHAIN` 来绕过（信号在 `item_interaction()` 之前触发，见 `code/game/atom/atom_tool_acts.dm` 的 `base_item_interaction()`），信号注册对上游同步免疫，不必改核心文件。当前先沿用核心补丁，若上游同步反复冲掉此补丁可考虑迁移到该方案。

### 模块化覆盖：

- 无（没有 `master_files/` 覆盖，也没有代码文件）

### Defines：

- 无

### 本模块目录外的依赖文件：

- `code/game/objects/structures/displaycase.dm`（本补丁的实际所在，含文件头台账与 `TIANGUAN EDIT` 标记）
- 不需要修改 `tgstation.dme`（本模块无代码文件）

### 同步上游时的注意事项：

- **`tools/i18n/sync-upstream.sh` 的冲突处理建议是 `git checkout --theirs <文件>`**，对"既含 `LANG(...)` 又含手写补丁"的文件（本文件正是）等于整份取上游 → 补丁被无声抹掉。同步后**必须**复查：
  ```
  grep -n VENDATRAY_TEMP code/game/objects/structures/displaycase.dm
  ```
  正常应命中 4 处（文件头 3 处 + proc 内标记 1 处）。只命中文件头、没有 `TIANGUAN EDIT ADDITION START` 就说明插入分支被冲掉了。
- `nova-i18n rewrite` 重写该文件时也可能抹掉标记（它只保留自己加的 `NOVA EDIT - I18N CODEMOD` 头）。重跑 rewrite / resync 之后同样复查一次上面那条命令。
- 玩家可见症状（用于快速判断补丁是否失效）：**托盘开着，拿食物点托盘放不进去，也没有任何提示**。

### 游戏内复验：

1. 组装/找一台 Vend-A-Tray（`/obj/structure/displaycase/forsale`，厨房、酒吧、tramstation 等地有）。
2. 用 ID 卡点一下 → 注册（`payments_acc` 设定）。
3. 打开托盘（UI 里的 Open，或用注册过的 ID 卡点一下切换）。
4. 手持食物/任意物品**点击托盘本体**（不是点 UI）→ 应出现"你把……放上展示台。"的提示，托盘外观出现缩略物品，UI 里显示物品名与价格。
5. 反例：托盘关闭时点击 → 不应放入；托盘里已有物品时再点 → 不应替换；持 PDA 点击 → 仍被拦截。
6. 回归：普通展示柜（`/obj/structure/displaycase`、实验室笼、馆长奖杯柜）的放置行为不受影响。

### 致谢：

- 无
