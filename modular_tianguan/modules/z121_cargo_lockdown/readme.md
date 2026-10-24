https://github.com/89623/TianGuan13/pull/<!--PR 编号-->

## z121 武器 / 弹药退出货舱订购

模块 ID：Z121_CARGO_LOCKDOWN

### 说明：

`modular_z121` 在 `code/modules/Company_imports/interns_project_emporium.dm` 里把一批武器和弹药挂进了
货舱公司订购目录（★ Ballistic Weapons / ★ Energy Weapons / ★ Magazines and Ammo）。本模块把这些供货包
**从可购买列表里移除**——但**不改 z121 的任何一行代码**。

做法（模块化拦注册，零改动、可逆）：

- `/datum/controller/subsystem/shuttle/Initialize()` 建包流程是
  `pack = new pack` → `generate_supply_packs()` → **`if(!pack.contains) continue`** → `supply_packs[pack.id] = pack`。
- 本模块覆写 `/datum/supply_pack/New()`（先 `..()` 让 core 的 `id = type` 和 Nova 的 `auto_name` 照常跑完），
  命中黑名单的类型在**运行期**把 `contains` 置空 ⇒ 它进不了 `SSshuttle.supply_packs`，
  订购台、快递台、流散货箱（stray cargo）事件都看不到它。
- 注意：`contains = null` 只能写在**运行期**——DM 的类型定义里赋 `null` 等价于没写，所以不能用重声明子类型的方式。

### 移出清单（共 21 个供货包）

**武器 10 个**（原价，`PAYCHECK_COMMAND = 100` 信用点）：

| 供货包 | 物品 | 原价 |
| --- | --- | --- |
| `companies/ballistics/intern_project/sidearm/sofap` | SOFAP 自动手枪 | 400 |
| `.../sidearm/tac9` | TAC-9 战斗手枪 | 400 |
| `.../sidearm/bfr500` | BFR-500 单动式左轮 | 600 |
| `companies/ballistics/intern_project/primary/crossbow` | 十字弩 | 600 |
| `.../primary/aa12` | AA12 全自动霰弹枪 | 1600 |
| `.../primary/evo` | EVO-13 冲锋枪 | 1000 |
| `.../primary/europa` | europa 通用机枪 | 2000 |
| `.../primary/dex4` | DEX-4 智能霰弹枪 | 1200 |
| `.../primary/solstice` | Solstice 重型狙击枪 | 1600 |
| `companies/energy/intern_project/photon_sniper` | 光子狙击步枪 | 800 |

**弹药 / 弹匣 11 个**（原价，`PAYCHECK_CREW = 50` 信用点）：

| 供货包 | 物品 | 原价 |
| --- | --- | --- |
| `companies/mags_and_ammo/intern_project/c20nuoli` | .20 Nuoli 致命弹 ×200 | 100 |
| `.../c20nuoli_smart` | .20 Nuoli 智能弹 ×200 | 100 |
| `.../c20nuoli_breacher` | .20 Nuoli 反器材弹 ×200 | 100 |
| `.../bolt` | 钢制弩箭 | 50 |
| `.../tac9` | TAC-9 空弹匣 | 50 |
| `.../bfr500` | BFR-500 快速装弹器 | 50 |
| `.../aa12_mag` | AA12 空弹匣 | 50 |
| `.../aa12_drum` | AA12 空弹鼓（15 发） | 150 |
| `.../evo_mag` | EVO-13 空弹匣 | 50 |
| `.../europa_mag` | europa 空弹盒 | 50 |
| `.../dex4_mag` | DEX-4 空弹匣 | 50 |

### 没有动的东西（本模块范围外）

`interns_project_emporium.dm` 里还有医疗、模块、donk 食品、收纳包等供货包，**全部保持原样可购买**。
另外这两条**非货舱**的获取渠道也不受影响（要一起关掉得另做模块）：

- 采矿订购终端：原动能机枪 1250 点、矿用霰弹枪 5000 点、狩猎独头弹 400 点
  （`modular_z121/code/modules/orders/mining.dm`）
- 比特运行软盘：2000 点买「比特运行装备：枪械」，含 7 个枪箱
  （`modular_z121/code/modules/orders/bitrunning.dm`）

### 核心文件 / Proc 改动：

- 无核心文件改动。唯一被覆写的 proc 是 `/datum/supply_pack/New()`（`..()` + 追加判断），
  当前该 proc 有 core（`code/modules/cargo/packs/_packs.dm:36`，只写 `id = type`）与
  Nova master_files（`auto_name` 取名）两份，本模块排在它们之后、链式调用 `..()`，不影响两者行为。

### 模块化覆盖：

- 无（`master_files/` 下没有文件）

### Defines：

- `GLOBAL_LIST_INIT(tianguan_z121_blocked_supply_packs, …)` —— 下架名单（typecache），本文件内定义。

### 本模块目录外的依赖文件：

- `tgstation.dme`（include 一行）
- 只读引用：`modular_z121/code/modules/Company_imports/interns_project_emporium.dm` 里那 21 个类型路径。

### 测试方式：

- DM 编译：`dm.exe tgstation.dme` → 0 errors，3 warnings（仓库固有 `#warn`）
- 运行时探针（临时文件、不入库；产线构建 + 私服 1337 起服跑一次）实测输出：
  - `下架名单=21 项；仍出现在 SSshuttle.supply_packs 的=0 项`
  - `SSshuttle.supply_packs 总包数=1049`（`subtypesof(/datum/supply_pack)` = 1192，差集里含 21 个下架包与无 `contains` 的抽象/父类）
  - 对照组全部仍在列表：`companies/mags_and_ammo/c35_mag`、`companies/ballistics/nt/double_barrel`、
    `materials/plastic50` 均 = 1 ⇒ 只精准摘掉这 21 个，没误伤别的包
- z121 文件零改动：`git diff -- modular_z121/` 为空（数据没被删，只是没注册）
- 私服 1337 起服后本模块无 runtime

### 致谢：

- 需求来源：天关维护方（z121 的枪和弹不该在货舱买到）
