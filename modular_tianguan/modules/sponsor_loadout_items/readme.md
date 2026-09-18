https://github.com/89623/TianGuan13/pull/24

## 天关赞助者配装物品

模块 ID：SPONSOR_LOADOUT_ITEMS

### 说明：

给赞助者玩家在配装（loadout）界面开放三件物品：

| 物品（显示名） | item_path | 配装页签 | 白名单 |
| --- | --- | --- | --- |
| box of long balloons | `/obj/item/storage/box/balloons` | Toys（上限 3 件） | 19 位赞助者 |
| B@L00NY skillchip | `/obj/item/skillchip/job/clown` | Other（上限 3 件） | 19 位赞助者 |
| Official Cat Stamp | `/obj/item/stamp/cat` | Inhand（上限 1 件） | 19 位赞助者（顶掉上游白名单，见下） |

三件分属三个页签，所以赞助者可以一次把三件都带上；若全塞进 Inhand，则受该页签「一次只能选 1 件」
的限制，只能三选一 —— 页签的容量与去重逻辑见 `code/modules/loadout/loadout_categories.dm`
与 `code/modules/loadout/categories/pocket.dm`、`modular_nova/modules/loadouts/loadout_items/loadout_datum_toys.dm`。

写法对齐 Nova 上游的捐赠者配装（`modular_nova/modules/loadouts/loadout_items/donator/personal/donator_personal.dm`）：
一件物品一个 `/datum/loadout_item` datum，用 `ckeywhitelist` 指定可领取的 ckey，分类按物品本身性质选
（上游 199 条捐赠者条目的分布就是 under 46 / suit 39 / pocket_items 31 / toys 28 / inhand 5 …）。

不使用 `donator_only = TRUE`：那是 Nova 的「捐赠者等级」总开关，一次会放开全部捐赠者物品，
且要维护 `config/nova/donators.txt` 或走 player_ranks 接口；本模块只需要给这 19 人开这 3 件，
所以逐件 `ckeywhitelist`。

三件物品的英文名在汉化目录里都已有译文（`box of long balloons`→「一盒长气球」、
`B@L00NY skillchip`→`B@L00NY 技能芯片`、`Official Cat Stamp`→「官方猫印章」），
`/datum/loadout_item` 的 `name` 已由 `tools/i18n/src/labels.rs` 的 `TYPE_VAR_RULES` 桥进前端目录，
所以界面按 locale 显示中文；不必新增译文条目。

### 核心文件 / Proc 改动：

- 无（不改任何核心文件，纯模块）。

### 模块化覆盖：

- `/datum/loadout_item/inhand/officialcat`（定义在 `modular_nova/modules/loadouts/loadout_items/donator/personal/donator_personal.dm:748`）
  — `ckeywhitelist` 由上游的 `list("kathrinbailey")` 顶掉为 19 位赞助者（`TIANGUAN_SPONSOR_CKEYS`）。

  > 上游那条白名单只有 `kathrinbailey` —— Nova 外服的捐赠者，天关是国服、这人不会出现，
  > 所以直接顶掉而不是合并（顶掉只需 1 行、名单仍只有顶部 define 一处可改）。
  > 若以后此人来天关，把 ckey 加进顶部 `TIANGUAN_SPONSOR_CKEYS` 即可。

  为什么不新建一条 datum：配装系统的登记表 `GLOB.all_loadout_datums` 以 `item_path` 为键
  （`code/modules/loadout/loadout_categories.dm:24-26`，撞键会 `stack_trace` 并让后建者覆盖前者），
  同一 `item_path` 只能有一个 datum —— 再建一条 `/obj/item/stamp/cat` 的 datum 会与上游那条
  互相覆盖，必有一方拿不到猫印章，因此选择在既有条目上重声明白名单。

  > 本覆盖依赖 `tgstation.dme` 的 include 顺序：本模块排在 `modular_nova` 之后才生效
  > （DM 对同一类型同一变量的跨文件重复赋值不报错，后 include 者生效）。

### Defines：

- `TIANGUAN_SPONSOR_CKEYS`（19 位赞助者 ckey）—— 仅本模块文件内使用，文件底部 `#undef`。
  用 define 而不是共享的全局 list：loadout 建表时会对 `ckeywhitelist` 逐项就地 `ckey()` 改写
  （`code/modules/loadout/loadout_categories.dm:50-52`），共享同一个 list 对象会让几个 datum 互相污染。

### 本模块目录外的依赖文件：

- 无新增。使用到的上游资源：`/obj/item/skillchip/job/clown`（core）、`/obj/item/storage/box/balloons`（core）、
  `/obj/item/stamp/cat`（modular_nova）。

### 测试方式：

- DreamMaker 编译通过（0 errors；`dm.exe tgstation.dme`，BYOND 516.1659）。
- 游戏内用赞助者 ckey 打开配装界面，确认 Toys 页出现 `box of long balloons`、Other 页出现 `B@L00NY skillchip`、
  Inhand 页出现 `Official Cat Stamp`，且三件可同时选中并在开局带到身上（气球盒与技能芯片在背包，印章在手上）。
- 用不在名单里的 ckey 复验：三件物品仍会显示在列表里（配装页不按 ckey 隐藏条目），但选中后开局发放会被拦下并提示
  `CKEY whitelist`（判定点在 `modular_nova/modules/loadouts/loadout_items/_loadout_datum.dm` 的 `can_be_applied_to()`）。
- 猫印章条目被本模块顶掉白名单：确认 19 位赞助者能领，其他 ckey（含上游 `kathrinbailey`）会被
  `CKEY whitelist` 拦下 —— 这是预期行为。

### 维护备注 / 来源说明：

- 名单变动时只改本文件顶部的 `TIANGUAN_SPONSOR_CKEYS` 一处，三条条目共用它。
- 上游同步注意：Nova 若改动 `officialcat` 的白名单或新增同 `item_path` 的条目，需要回来核对本覆盖。

### 致谢：

- mohu19（发起与需求）
