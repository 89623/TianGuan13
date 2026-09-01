# 笔的文书快捷输入提示 (Pen Shortcut Hint)

模块 ID：PEN_SHORTCUT_HINT

### 说明：

游戏内写文书（paper）时支持快捷输入：输入 `%s` 插入角色签名、`%d` 插入日期、`%t` 插入时间（实现在 `code/modules/paperwork/paper.dm`）。本模块在**所有笔**的检视（examine）界面追加一行提示，让玩家拿到笔检视一下就知道这个用法。

### 核心文件 / Proc 改动：

- 无（不修改任何核心文件，纯模块 override）。

### 模块化覆盖：

- `modular_tianguan/modules/pen_shortcut_hint/code/pen_shortcut_hint.dm`：
  - `/obj/item/pen/examine()`（override）：在原有检视内容下追加 `%s输入角色签名 %d输入日期 %t输入时间`。
  - 通过 override 笔基类，覆盖全部 58 个笔类型（含 fountain/sleepy/parapen/edagger 等子类），无需逐个修改 desc。

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
