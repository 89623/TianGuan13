https://github.com/89623/TianGuan13/pull/<!--PR 编号-->

## 非盲人专用眼罩（外观眼罩）

模块 ID：BLINDFOLD_COSTUME

### 说明：

配装（loadout）菜单的 Glasses 页签原本只有上游那条「眼罩 - 盲人专用」
（`/datum/loadout_item/glasses/blindfold/color` → `/obj/item/clothing/glasses/blindfold/color`，
白色灰阶、按瞳色染色、玩家可自改色），戴上必定失明。玩家反馈想要**同款外观**但不影响视野的一件，
因此本模块新增两样东西：

- 物品 `/obj/item/clothing/glasses/blindfold/color/cosmetic`，局内名字「眼罩」（区别于上游的盲人眼罩）
  - 直接派生自 `/obj/item/clothing/glasses/blindfold/color` ⇒ 精灵图件件相同：
    `icon` / `icon_state` / `post_init_icon_state` / `greyscale_config`(`_worn`) / `worn_icon` /
    `greyscale_colors` / `flags_1 = IS_PLAYER_COLORABLE_1`（玩家仍可自改颜色）/
    `visual_equipped()`（戴上时按瞳色染色）全部原样继承
  - `tint = 0`：父类是 `INFINITY`，靠 `update_tint()` 累加后 `become_blind(EYES_COVERED)` 致盲；给 0 即不再致盲
  - `flash_protect = FLASH_PROTECTION_NONE`：父类顺带有焊接/闪光防护，纯外观件不送这份防护
  - 检视只留**一句** desc（`和盲人眼罩同款，但戴上不影响视野。`），不覆写 `examine()`
- 配装条目 `/datum/loadout_item/glasses/cosmetic_blindfold`，显示名「眼罩 - 非盲人专用」
  - 落在 Glasses 页签、紧挨上游「眼罩 - 盲人专用」；无 `donator_only`、无职业限制 ⇒ 所有玩家可领

### 核心文件 / Proc 改动：

- `tgstation.dme`：天关模块 include 区新增 1 行（唯一的核心文件改动）。

### 模块化覆盖：

- 无

### Defines：

- 无

### 本模块目录外的依赖文件：

- `tgstation.dme`（include 一行）

### 测试方式：

- DM 编译：`dm.exe tgstation.dme` → 0 errors，3 warnings（仓库固有的 DreamMaker `#warn`）
- 运行时探针（临时文件，未入库；在**产线构建 + 私服 1337** 上起服跑一次），与「眼罩 - 盲人专用」逐字段对比：
  - 参考件：`tint=1e+31`（INFINITY）、`flash_protect=2`（WELDER）、`icon_state=blindfoldcolor`、
    灰阶生成图 `tmp/gags/icons/gags-blindfold-#ffffff.dmi`
  - 外观件：`tint=0`、`flash_protect=0`；`icon` / `icon_state` / `post_init_icon_state` / `worn_icon` /
    `greyscale_config_worn` / `greyscale_colors` / `IS_PLAYER_COLORABLE_1` 与参考件**逐项相等**
    （探针输出「精灵图一致: icon=1 icon_state=1 post=1 worn=1 grey_worn=1 grey=1 colorable=1」）
  - 穿上后 `is_blind()` 为空（不瞎）；**对照组**穿「眼罩 - 盲人专用」仍返回
    `/datum/status_effect/grouped/blindness` ⇒ 上游那件的行为一行没动
  - `GLOB.all_loadout_datums[/obj/item/clothing/glasses/blindfold/color/cosmetic]` 命中，显示名
    「眼罩 - 非盲人专用」⇒ 配装菜单的 Glasses 页签里确实会出现
  - 检视（`examine()`）输出：物品名「眼罩」+ 那一句 desc，没有多余条目
- 私服 1337：起服 101.7s 初始化完成，全程没有本模块相关的 runtime
- 实机（玩家侧）：配装 Glasses 页签领「眼罩 - 非盲人专用」，戴上视野正常，颜色随瞳色、也可自改

### 致谢：

- 需求来源：天关玩家反馈（配装里只有盲人版眼罩，戴上就看不见）
