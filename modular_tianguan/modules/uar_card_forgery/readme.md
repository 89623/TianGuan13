https://github.com/89623/TianGuan13/pull/<!--PR 编号-->

## 团结联盟审查官卡可被特工卡变造

模块 ID：UAR_CARD_FORGERY

### 说明：

特工卡（`/obj/item/card/id/advanced/chameleon`，游戏内名「特工卡 / agent card」）能变造两样东西：

| 变造项 | 实现 | 清单来源 |
| --- | --- | --- |
| 外观（卡面） | `/datum/action/item_action/chameleon/change/id` | `initialize_disguises()` 里写死的卡类型清单 |
| 印花（徽记/部门色/secHUD） | `/datum/action/item_action/chameleon/change/id_trim` | `initialize_disguises()` 里写死的 id_trim 白名单 |

天关的 `/obj/item/card/id/advanced/uar_admin`（行政ID，审查官开局那张）和 `/datum/id_trim/job/uar_inspector`
是模块新增类型，两份清单里都没有 ⇒ 游戏里无论怎么点都变不出审查官样式的卡。

本模块补上两件事：

- 外观菜单加入 `/obj/item/card/id/advanced/uar_admin`
- 印花菜单加入 `/datum/id_trim/job/uar_inspector`
- 另外补一个上游漏掉的细节：`change/id/update_item()` 只抄 `icon_state`、**不抄 `icon`（卡面图集）**。
  天关的卡用模块自带 `uar_card.dmi`，不补这一下，变造出来的卡会去默认图集里找
  `card_uar_admin` 这个不存在的状态 ⇒ 变出一张空白卡。本模块在 `..()` 之后把 `icon` 一并对齐
  （取不到源卡 icon 时回落到特工卡自己的图集）。

### 核心文件 / Proc 改动：

- 无。全部是「`..()` + 追加」的子类型覆写，不修改 `code/modules/clothing/chameleon/` 下任何文件，
  也不需要 `TIANGUAN EDIT` 标记（对比 `uar_marine_modsuit` 当初是在核心文件里加的 TIANGUAN EDIT 行，
  那种写法在上游改清单时会冲突，本模块不碰核心）。

### 模块化覆盖：

- 无

### Defines：

- `UAR_FORGEABLE_CARDS` / `UAR_FORGEABLE_TRIMS`（本文件内定义，文件末尾 `#undef`）

### 本模块目录外的依赖文件：

- `tgstation.dme`（include 一行）
- 只**读取**既有类型：`/obj/item/card/id/advanced/uar_admin`、`/datum/id_trim/job/uar_inspector`
  （都定义在 `modular_tianguan/modules/uar_officer/code/uar_officer.dm`，本模块不复制、不重声明）

### 测试方式：

- DM 编译：`dm.exe tgstation.dme` → 0 errors，3 warnings（仓库固有 `#warn`）
- 运行时探针（临时文件，未入库；产线构建起服跑一次），在真服里点这两把 action：
  - 外观清单 **19 条**、含 `/obj/item/card/id/advanced/uar_admin`；印花清单 **142 条**、含 `/datum/id_trim/job/uar_inspector`
  - 点「外观 → 行政ID」：`icon=uar_card.dmi`、`icon_state=card_uar_admin`、`assigned_icon_state=assigned_uar_admin`，
    并且 trim 自动跟着变成 `trim_uar_inspector` / `huduar_inspector`（因为该卡的 `trim` 就是这个 trim）
  - 点「印花 → Alliance Inspector」：`trim_state_override=trim_uar_inspector`、`trim_assignment=Alliance Inspector`、`sechud=huduar_inspector`
  - 与真卡（新刷一张 `uar_admin`）逐字段对比：`icon / icon_state / assigned_icon_state /
    trim_icon / trim_state / sechud_icon_state / department_color` **全 1**
  - 菜单显示名：外观「行政ID (uar admin, uar admin)」、印花「Alliance Inspector (uar inspector)」

### 致谢：

- 需求来源：天关玩家反馈（特工卡变不出审查官样式的卡）
