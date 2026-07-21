https://github.com/89623/TianGuan13/pull/14

## 上行链路物品补充

模块 ID：UPLINK_ITEM

### 说明：

给叛徒上行链路增加「辛迪加独立旅传呼密信」（210 TC，`cant_discount`），内容物是一个套件盒：
战列巡洋舰坐标上传卡 ×1、辛迪加耳机密钥 ×4、中文使用指南 ×1。

召唤机制本身是上游 tgstation 已有的：坐标卡在通讯控制台上当 emag 使用
（`code/game/machinery/computer/communications.dm` 的 `emag_act`，要求使用者是叛徒且一局仅限一次），
随后 `summon_battlecruiser()`（`code/modules/shuttle/mobile_port/variants/battlecruiser_starfury.dm`）
向 ghost 招募船员并加载 `_maps/templates/battlecruiser_starfury.dmm`。本模块不新增任何图标、地图或机制代码。

耳机密钥是必需品：船员是独立的 ghost 玩家，召唤者不与他们通信就会被当作站员击杀。

另外恢复了两件被 modular_nova 禁售的上游物品（TTV 大炮、蓝空公文包）的购买选项。

### 核心文件 / Proc 改动：

- 无

### 模块化覆盖：

- `/datum/uplink_item/role_restricted/blastcannon` — `purchasable_from` 由 `modular_nova` 的 `NONE` 恢复为上游默认 `ALL`
- `/datum/uplink_item/device_tools/briefcase_launchpad` — 同上

> 这两处覆盖依赖 `tgstation.dme` 的 include 顺序：本模块必须排在 `modular_nova` 之后。
> DM 对同一类型同一变量的跨文件重复赋值不报错，后 include 者生效。

### Defines：

- 无

### 本模块目录外的依赖文件：

- 无

### 致谢：

Secai524（原始实现，PR #14）
