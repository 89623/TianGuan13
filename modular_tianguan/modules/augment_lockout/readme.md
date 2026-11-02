https://github.com/89623/TianGuan13/pull/<!--PR 编号-->

## 开局装配禁选：螳螂刀 / 光学迷彩（隐身）植入体

模块 ID：AUGMENT_LOCKOUT

### 说明：

这两样东西**不在配装（loadout）菜单里**，而是 Nova 的「植入体」偏好（角色设置 → 肢体/植入体页），
选上后开局由 `/datum/preference_middleware/limbs_and_markings` 装进身体。本模块让这三个条目
**对所有人不可选、不可见、也不再发放**：

| 植入体条目 | 游戏内名字 | 花费 | 实际物品 |
| --- | --- | --- | --- |
| `/datum/augment_item/implant/chest/optical_camo` | Optical Camouflage Implant（隐身模块） | 9 | `/obj/item/organ/cyberimp/chest/opticalcamo` |
| `/datum/augment_item/implant/l_arm/mantis_blade_left` | Obsolete Mantis Blade（螳螂刀·左） | 8 | `.../arm/toolkit/armblade/early/l` |
| `/datum/augment_item/implant/r_arm/mantis_blade_right` | Obsolete Mantis Blade（螳螂刀·右） | 8 | `.../arm/toolkit/armblade/early` |

做法：给这三个条目重声明 `ckey_whitelist`（该字段本义是「只有名单里的 ckey 能拿」），填一个
不存在的 ckey ⇒ 对所有玩家关闭。三处判定同时生效：

- **前端过滤**：`tgui/.../PreferencesMenu/CharacterPreferences/LimbsPage.tsx` 的 `isAugAllowed()`
  里有 `if (aug.ckey_whitelist && !aug.ckey_whitelist.includes(ckey)) return false;`，列表渲染前 `.filter()`
  ⇒ 选项**直接不出现**（不是灰掉）；
- **服务端拒绝**：`is_aug_valid_for_prefs()` 的 `if(aug.ckey_whitelist && !LAZYFIND(...)) return FALSE;`，
  `set_bodypart_aug` / `set_internal_implant_aug` 两个动作都先过它 ⇒ 伪造 TGUI 请求也选不上；
- **不再发放**：开局 `apply_to_human()` 走同一个判定 ⇒ 已经选过的老存档，开局不会再装上这两样。

为什么不用「把条目从 `GLOB.augment_items` 注册表里删掉」：`apply_to_human()` 拿
`GLOB.augment_items[存档里的路径]` 直接取实例再读 `.species_blacklist`，删掉后是 null ⇒
**旧存档一开局就在 `is_aug_valid_for_prefs()` 上抛 runtime**。白名单写法既关掉又不炸。

### 核心文件 / Proc 改动：

- 无。只重声明了 Nova 既有类型的变量（DM 里同类型同变量跨文件重复赋值合法，后 include 者生效），
  没有改 `code/` 或 `modular_nova/` 任何文件。

### 模块化覆盖：

- 无

### Defines：

- `AUGMENT_LOCKED_CKEY`（占位 ckey，本文件顶部定义、文件末尾 `#undef`）

### 本模块目录外的依赖文件：

- `tgstation.dme`（include 一行，放在天关 include 块内 ⇒ 天然晚于 `modular_nova`）
- 只读引用 Nova 的三个 `augment_item` 类型（定义在
  `modular_nova/modules/customization/modules/client/augment/implants.dm`），本模块不复制、不重声明其它字段。

### 测试方式：

- DM 编译：`dm.exe tgstation.dme` → 0 errors，3 warnings（仓库固有 `#warn`）
- 运行时探针（临时文件、不入库；产线构建 + 私服 1337 起服跑一次）实测输出：
  - `GLOB.augment_items 条目数=236`（注册表正常，没有把条目摘掉）
  - 三个目标条目全部 `server_blocked=1 ui_hidden=1` ⇒ 服务端判定（`is_aug_valid_for_prefs`）
    与前端判定（`isAugAllowed`）都会把它们挡掉：
    - `/datum/augment_item/implant/chest/optical_camo`（Optical Camouflage Implant）
    - `/datum/augment_item/implant/l_arm/mantis_blade_left`（Obsolete Mantis Blade）
    - `/datum/augment_item/implant/r_arm/mantis_blade_right`（Obsolete Mantis Blade）
  - 对照组未受影响（`whitelist` 仍为空、条目在册）：`chest/nutriment_pump`、
    `l_arm/charging_implant`、`chest/internal_health_analyzer/lite`
- 私服 1337 起服后本模块无 runtime
- 游戏内（玩家侧）：角色设置 → 肢体/植入体页，胸部植入体里没有 Optical Camouflage、左右手臂里没有 Mantis Blade

### 致谢：

- 需求来源：天关维护方（开局装配不允许选螳螂刀与隐身模块）
