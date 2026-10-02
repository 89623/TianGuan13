https://github.com/89623/TianGuan13/pull/<!--PR 编号-->

## 团结联盟：人类物种介绍与背景（捏人面板）

模块 ID：UAR_HUMAN_LORE

### 说明：

把角色创建面板（捏人面板）中「人类」的**介绍**与**背景**替换为团结联盟共和国设定下的文本：

- 介绍（一段）：放射尘与核冬天的黑暗严冬下，不屈的人类崛起……在群体的力量下冲出引力井。
- 背景（两段）：以传统人类的风格，他们从大地到终极边疆……／人类的机会和进取精神以巅峰形式延续：超级公司……

文案取自用户提供的设定稿，逐字照搬、不做字词改动。

**前端无需任何改动**：物种页面本来就读这两个 proc —— `code/modules/client/preferences/species.dm`
里 `data[species_id]["desc"] = lang_reverse_text_or_list(species.get_species_description())`，
介绍与背景分别由 `get_species_description()` / `get_species_lore()` 提供。

### 核心文件 / Proc 改动：

- `code/modules/mob/living/carbon/human/species_types/humans.dm`
  - `/datum/species/human/get_species_description()`：开头加钩子（`uar_species_description` 非空则返回它）—— `TIANGUAN EDIT ADDITION`
  - `/datum/species/human/get_species_lore()`：开头加钩子（`uar_species_lore` 非空则返回它）—— `TIANGUAN EDIT ADDITION`
  - **为什么不能完全模块化**：这两个 proc 在该文件里是硬编码 `return`，而 DM 中「同类型同 proc 重复定义」
    会直接 `duplicate definition` 编译报错，故只能走最小钩子路线。钩子**带优雅回退**：
    变量为空时行为与改动前完全一致（即便本模块被移除也能正常编译运行）。

### 模块化覆盖：

- 在 `/datum/species/human` 上**新增两个 var**（`uar_species_description` / `uar_species_lore`）——
  DM 允许跨文件给既有类型追加 var，因此这一步**不算核心改动**，也无需标记。

### Defines：

- 无

### 本模块目录外的依赖文件：

- 无（仅需 `tgstation.dme` 一行 include：`modular_tianguan\modules\uar_human_lore\code\uar_human_lore.dm`）

### 测试方式：

1. 编译：`dm.exe tgstation.dme` ⇒ `0 errors`；
2. 游戏内：进入角色创建面板 → 物种 → **人类**，核对「介绍」与「背景」两处文案为本模块文本；
3. 回退验证：把模块里两个 var 置空后（或移除 include）应显示核心原文案，行为无回归。

### 致谢：

- 文案：用户提供的设定稿
