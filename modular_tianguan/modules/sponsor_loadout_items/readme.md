https://github.com/89623/TianGuan13/pull/<!--PR 编号-->

## 天关赞助者配装物品

模块 ID：SPONSOR_LOADOUT_ITEMS

### 说明：

给「赞助者」在配装（loadout）界面开放物品。分三类：

**① 解锁上游的捐赠者私人条目（148 条）**

上游 `modular_nova/modules/loadouts/loadout_items/donator/personal/donator_personal.dm`
里的这些条目原本是 `ckeywhitelist = list("<某位 Nova 捐赠者>")` 的私人配装（那些 ckey 是外服玩家，
天关不会出现，对天关等于白名单死锁）。本模块把它们的白名单清空并设为 `donator_only = TRUE`，
于是赞助者可见、可领。清单在本模块的 `TIANGUAN_SPONSOR_ITEM_PATHS`（148 条 item_path）。

上游条目自带的**职业限定原样保留**（清单内有 19 条带 `restricted_roles`）——
即需求方要的「赞助者专属」叠加上「职业限定」：选上后若当前职业不在限制内，开局发放会被拒并提示。

**② 本模块自建条目（3 条，上游没有对应配装 datum）**

| 物品（显示名） | item_path | 配装页签 |
| --- | --- | --- |
| box of long balloons | `/obj/item/storage/box/balloons` | Toys（上限 3 件） |
| B@L00NY skillchip | `/obj/item/skillchip/job/clown` | Other（上限 3 件） |
| hardlight wheelchair emitter | `/obj/item/holosign_creator/hardlight_wheelchair` | Other（上限 3 件） |

**③ 保持原样、不做任何处理（7 条）**

需求清单里还有 7 件上游**本来就没设任何限制**（无 `ckeywhitelist`、无 `donator_only`，
任何人都能领）的条目：

```
/obj/item/clothing/head/caligram_cap                        Caligram Tan Softcap
/obj/item/clothing/mask/gas/nightlight                      FIR-36 Rebreather
/obj/item/clothing/mask/gas/nightlight/fir22                FIR-22 Full-Face Rebreather
/obj/item/clothing/suit/armor/vest/caligram_parka_vest      Caligram Armored Tan Parka
/obj/item/clothing/suit/jacket/caligram_parka               Caligram Tan Parka
/obj/item/clothing/under/jumpsuit/caligram_fatigues         Caligram Tan Fatigues
/obj/item/holocigarette/masvedishcigar                      Holocigar
```

赞助者本来就能领它们；若加进解锁清单，反而会把它们变成赞助者专属（＝对其他人收回），
因此按需求方要求维持原状。这 7 条也记录在模块文件末尾的「保持原样」段落，避免后人误以为是漏项。

### 捐赠者机制：

- `config/nova/config_nova.txt` 的 `DONATOR_LEGACY_SYSTEM` 开启后，名单从 `config/nova/donators.txt` 读
  （逐行读、跳过空行与 `#` 开头的注释、每项过 `ckey()` 转小写）。
  读取实现：`modular_nova/modules/player_ranks/code/player_rank_controller/donator_controller.dm`
  （`legacy_file_path = "[global.config.directory]/nova/donators.txt"`）
  + `_player_rank_controller.dm` 的 `load_legacy()`。
- `donator_only` 的判定点：`modular_nova/modules/loadouts/loadout_items/_loadout_datum.dm` 的 `can_be_applied_to()`
  （`donator_only && !SSplayer_ranks.is_donator(client)` 则拒绝）。
- 前端还会按 `ckey_whitelist` 隐藏条目（`tgui/.../loadout/ItemDisplay.tsx` 的 `FilterItemList`）：
  「`ckey_whitelist` 非空且不含当前 ckey → 直接不显示」，这也是为什么必须把白名单清空。
- `is_donator()` 默认 `admin_bypass = TRUE`：**管理员等同于捐赠者**，这是 Nova 既有行为，不是本模块引入的。
- 配装界面会自动给这些条目打上「Donator-Only」标记（`get_item_information()`）。
- **名单变动 = 只改 `config/nova/donators.txt` 一处**，不需要改代码、不需要重编。

### 机制实现（为什么这么写）：

- **统一解锁**：本模块覆盖 `/datum/loadout_item/New(category)`（core 版本在
  `code/modules/loadout/loadout_items.dm:65`），创建时若 `item_path` 命中清单就
  `ckeywhitelist = null; donator_only = TRUE`。配装条目由各分类的 `get_items()` 用
  `new found_type(src)` 实例化后登记进 `GLOB.all_loadout_datums`，这里正是那些单例的创建点，
  且变量初值在 `New()` 之前就已就位（最小工程实测）。

- **为什么在 `New()` 里改、而不是在类型体里写 `ckeywhitelist = null`**：
  DM 里跨文件把继承变量赋成 `null` 会**静默失效**（`null` 等于默认值，编译器不记录这次变更）。
  最小工程实测：同一份 `var/list/bar` 由父类声明、上游文件赋 `list("kathrinbailey")`、
  我们的文件赋 `null` → 运行期读出来仍是 `["kathrinbailey"]`；而赋非默认值（如 `flag = TRUE`）正常生效。
  148 条若逐条写类型体 + `New()` 既冗余又容易漏，且上游重命名后无法察觉，故用一处覆盖 + 一张清单。

- **为什么不新建 datum**：配装登记表 `GLOB.all_loadout_datums` 以 `item_path` 为键
  （`code/modules/loadout/loadout_categories.dm:24-26`，撞键会 `stack_trace` 并让后建者覆盖前者），
  同一 `item_path` 只能存在一个 datum，所以只能在既有条目上做覆盖。

- **依赖 `tgstation.dme` 的 include 顺序**：本模块的 include 必须排在 `code/modules/loadout/loadout_items.dm`
  与 `modular_nova` 的相关文件之后（DM 对同一类型同名 proc 的跨文件覆盖取后定义者，`..()` 链到前一份）。

### 核心文件 / Proc 改动：

- 无核心逻辑改动；只覆盖一个 core proc 的模块化写法，代码都在本模块目录内。
- 单元测试 `code/modules/unit_tests/~nova/tianguan_sponsor_loadout.dm`（在 `_unit_tests.dm` 的
  `NOVA EDIT` 块内登记）：逐条确认清单里的 item_path 都落到了已解锁的配装条目上，
  并确认三条自建条目都是 `donator_only`。

### Defines：

- `TIANGUAN_SPONSOR_ITEM_PATHS` —— 本模块内部的解锁清单（148 条 item_path），文件末尾 `#undef`。
  运行期经 `tianguan_sponsor_item_paths()` 惰性建成 `item_path → TRUE` 查找表（proc 内 static，
  不用 `GLOBAL_LIST_INIT`：配装单例本身就在另一个全局的初始化里创建，先后顺序不受控）。

### 本模块目录外的依赖文件：

- `config/nova/donators.txt` —— 赞助者名单，属服务器配置，由部署方自行维护（本 PR 未改 config）。
  使用到的上游资源：core 的物品类型（气球盒、技能芯片）、`modular_nova` 的捐赠者物品与
  `/obj/item/stamp/cat`。

### 测试方式：

- DreamMaker 编译通过（0 errors；`dm.exe tgstation.dme`，BYOND 516.1659）。
- 单元测试 `/datum/unit_test/tianguan_sponsor_loadout` 通过。
- 游戏内用 `config/nova/donators.txt` 里的 ckey 打开配装界面，逐页签确认：
  - 解锁条目都在，且带「Donator-Only」标记；
  - 选上后开局能带到身上；
  - 有职业限定的（如舰长的 `Captain's Dress`、矿工的 `Ahab's Spear Retool Kit`、
    安保的 `Banded Uniform`、NTC 的 hubert 三件与 razurath 两件）用其它职业选上 → 发放被拒并提示 `job restrictions`。
- 用不在名单里的 ckey 复验：配装页**看不到**这些条目（`ItemDisplay.tsx` 的 `FilterItemList`
  对非捐赠者隐藏 `donator_only` 条目）；服务端 `can_be_applied_to()` 另有一道 `donator` 拦截兜底。
- 「保持原样」的 7 条：用任意 ckey（非捐赠者）确认仍可正常领取 —— 验证没有被本模块误变成专属。
- 改 `config/nova/donators.txt` 加一个 ckey 后重启，确认对方能领 —— 验证「名单只改 config」这条。

### 维护备注 / 来源说明：

- 物品来源：需求方提供的清单（`预添加的物品.md`，156 条）。其中 148 条解锁、7 条保持原样、
  1 条（硬光轮椅）上游无条目故自建。需求文件里 `caligram_parkaa` 系笔误，实际类型为 `caligram_parka`。
- 加物品：只在 `TIANGUAN_SPONSOR_ITEM_PATHS` 里加一行即可（上游已有该 item_path 的条目为前提）。
- **上游同步注意**：Nova 若改动 `donator_personal.dm` 中这些条目的 `item_path`／白名单／职业限制，
  或新增同 `item_path` 的条目，需要回来核对本清单。item_path 失配时游戏里不会报错，
  但单元测试 `tianguan_sponsor_loadout` 会点名报出是哪一条。

### 致谢：

- mohu19（发起与需求）
- 名单改为读取 `config/nova/donators.txt`：采纳 89623 维护者的 review 建议（不硬编码 ckey）
