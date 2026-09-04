# 笔的文书快捷输入提示 (Pen Shortcut Hint)

模块 ID：PEN_SHORTCUT_HINT

### 说明：

游戏内写文书（paper）时支持快捷输入：输入 `%s` 插入角色签名、`%d` 插入日期、`%t` 插入时间（实现在 `code/modules/paperwork/paper.dm`）。本模块在**普通书写笔**的检视（examine）界面追加一行提示，让玩家拿到笔检视一下就知道这个用法。

**范围**：仅普通书写笔（黑笔/蓝笔/红笔/四色笔/钢笔/炭笔/隐形笔等）显示提示；伪装/武器类笔（笔刀 edagger、催眠笔 sleepy、爆破笔 destroyer、笔形闪光弹 penbang、uplink 笔）不提示——它们并非用于写文书，显示文书格式提示语义不符。

### 核心文件 / Proc 改动：

- 无（不修改任何核心文件，纯模块 override）。

### 模块化覆盖：

- `modular_tianguan/modules/pen_shortcut_hint/code/pen_shortcut_hint.dm`：
  - `GLOB.pen_shortcut_hint_exempt`（新全局列表：伪装/武器类笔黑名单）
  - `/obj/item/pen/examine()`（override）：非黑名单笔在原有检视内容下追加 `%s输入角色签名 %d输入日期 %t输入时间`。
  - 普通书写笔（黑/蓝/红/四色/钢笔/炭笔等，含未来新增的普通笔）自动获得提示；edagger/sleepy/destroyer/penbang/uplink 等特殊笔不提示。

### Defines：

- 无

### 本模块目录外的依赖文件：

- 无（仅依赖核心 `/obj/item/pen` 与内置 `span_notice`）

### 测试方式：

- DreamMaker 编译通过（0 errors）。
- 游戏内检视任意笔（如普通笔、红笔、钢笔），确认提示行出现在原有介绍下方。
- 确认写文书时输入 `%s`/`%d`/`%t` 分别插入签名/日期/时间。

### 致谢：

- mohu19（作者）
