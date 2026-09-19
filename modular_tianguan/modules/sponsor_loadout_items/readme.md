https://github.com/89623/TianGuan13/pull/<!--PR 编号-->

## 天关赞助者配装物品

模块 ID：SPONSOR_LOADOUT_ITEMS

### 说明：

给「赞助者」在配装（loadout）界面开放三件物品：

| 物品（显示名） | item_path | 配装页签 |
| --- | --- | --- |
| box of long balloons | `/obj/item/storage/box/balloons` | Toys（上限 3 件） |
| B@L00NY skillchip | `/obj/item/skillchip/job/clown` | Other（上限 3 件） |
| Official Cat Stamp | `/obj/item/stamp/cat` | Inhand（上限 1 件） |

三件分属三个页签，所以赞助者可以一次把三件都带上；若全塞进 Inhand，则受该页签「一次只能选 1 件」
的限制，只能三选一 —— 页签容量与去重逻辑见 `code/modules/loadout/loadout_categories.dm`、
`code/modules/loadout/categories/pocket.dm`、`modular_nova/modules/loadouts/loadout_items/loadout_datum_toys.dm`。

**名单不写进代码**：三条条目都用 Nova 的捐赠者机制 `donator_only = TRUE`，
可领取的 ckey 由 **`config/nova/donators.txt`** 决定。

### 捐赠者机制：

- `config/nova/config_nova.txt` 的 `DONATOR_LEGACY_SYSTEM` 开启后，名单从 `config/nova/donators.txt` 读
  （逐行读、跳过空行与 `#` 开头的注释、每项过 `ckey()` 转小写）。
  读取实现：`modular_nova/modules/player_ranks/code/player_rank_controller/donator_controller.dm`
  （`legacy_file_path = "[global.config.directory]/nova/donators.txt"`）
  + `_player_rank_controller.dm` 的 `load_legacy()`。
- `donator_only` 的判定点：`modular_nova/modules/loadouts/loadout_items/_loadout_datum.dm` 的 `can_be_applied_to()`
  （`donator_only && !SSplayer_ranks.is_donator(client)` 则拒绝）。
- `is_donator()` 默认 `admin_bypass = TRUE`：**管理员等同于捐赠者**，这是 Nova 既有行为，不是本模块引入的。
- 配装界面会自动给这三条打上「Donator-Only」标记（`get_item_information()`）。
- **名单变动 = 只改 `config/nova/donators.txt` 一处**，不需要改代码、不需要重编。
- 三件物品的英文名在汉化目录里都已有译文（`box of long balloons`→「一盒长气球」、
  `B@L00NY skillchip`→`B@L00NY 技能芯片`、`Official Cat Stamp`→「官方猫印章」）；
  `/datum/loadout_item` 的 `name` 已由 `tools/i18n/src/labels.rs` 的 `TYPE_VAR_RULES` 桥进前端目录，
  界面按 locale 显示中文，不必新增译文条目。

### 核心文件 / Proc 改动：

- 无（不改任何核心文件，纯模块 + 一个 config 数据文件）。

### 模块化覆盖：

- `/datum/loadout_item/inhand/officialcat`（定义在 `modular_nova/modules/loadouts/loadout_items/donator/personal/donator_personal.dm:748`）
  — 覆盖两处：类型体里 `donator_only = TRUE`（非默认值，跨文件覆盖有效），
  并在 `New()` 里运行期把 `ckeywhitelist` 清成 `null`。

  上游那条只放行 `list("kathrinbailey")`（Nova 外服的捐赠者，天关不会出现）。而
  `can_be_applied_to()`（服务端发放）与 `ItemDisplay.tsx` 的 `FilterItemList`（前端列表）
  都按「`ckey_whitelist` 非空且不含当前 ckey → 隐藏/拒绝」处理，只加 `donator_only` 不清白名单，
  赞助者会**在配装页里根本看不到猫印章** —— 所以白名单必须一起清掉。

  > **为什么必须在 `New()` 里清、不能写成 `ckeywhitelist = null`**：DM 里跨文件把继承变量
  > 赋成 `null` 会**静默失效**（`null` 等于默认值，编译器不记录这次变更）。最小工程实测：
  > 同一份 `var/list/bar` 由父类声明、上游文件赋 `list("kathrinbailey")`、我们的文件赋 `null`
  > → 运行期读出来仍是 `["kathrinbailey"]`；同一文件里 `flag = TRUE`（非默认值）则正常生效。
  > 所以 `ckeywhitelist` 只能在 `New()` 里运行期清空。

  为什么不新建一条 datum：配装登记表 `GLOB.all_loadout_datums` 以 `item_path` 为键
  （`code/modules/loadout/loadout_categories.dm:24-26`，撞键会 `stack_trace` 并让后建者覆盖前者），
  同一 `item_path` 只能有一个 datum，所以只能在既有条目上覆盖。

  > 本覆盖依赖 `tgstation.dme` 的 include 顺序：本模块排在 `modular_nova` 之后才生效
  > （DM 对同一类型同一变量的跨文件重复赋值不报错，后 include 者生效）。

### Defines：

- 无（名单不再以 define / 字面量形式出现在代码里）。

### 本模块目录外的依赖文件：

- `config/nova/donators.txt` —— 赞助者名单（本项目变更里一并更新，19 个 ckey）。
  使用到的上游资源：`/obj/item/skillchip/job/clown`（core）、`/obj/item/storage/box/balloons`（core）、
  `/obj/item/stamp/cat`（modular_nova）。

### 测试方式：

- DreamMaker 编译通过（0 errors；`dm.exe tgstation.dme`，BYOND 516.1659）。
- 游戏内用 `config/nova/donators.txt` 里的 ckey 打开配装界面，确认 Toys 页出现 `box of long balloons`、
  Other 页出现 `B@L00NY skillchip`、Inhand 页出现 `Official Cat Stamp`，三件可同时选中并在开局带到身上
  （气球盒与技能芯片在背包，印章在手上），且条目带「Donator-Only」标记。
- 用不在名单里的 ckey 复验：条目仍显示（配装页不按 ckey 隐藏条目），选中后开局发放会被拦下并提示
  `donator`（判定点在 `_loadout_datum.dm` 的 `can_be_applied_to()`）。
- 改 `config/nova/donators.txt` 加一个 ckey 后重启，确认对方能领 —— 验证「名单只改 config」这条。

### 维护备注 / 来源说明：

- 赞助者名单：`config/nova/donators.txt`（19 人）；物品名单：`物品名单.txt`（3 件，需求方提供）。
- 上游同步注意：Nova 若改动 `config/nova/donators.txt`（该文件在上游也会更新），
  或改动 `officialcat` 的这两个变量／新增同 `item_path` 的条目，需要回来核对本覆盖。

### 致谢：

- mohu19（发起与需求）
- 名单改为读取 `config/nova/donators.txt`：采纳 89623 维护者的 review 建议（不硬编码 ckey）
