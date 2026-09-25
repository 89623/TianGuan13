# 团结联盟背景图 + uar 主题 (TRAITOR_BACKGROUND)

模块 ID：`TRAITOR_BACKGROUND`

### 说明：

给**团结联盟**这个雇主的叛徒信息界面铺一张徽记背景，并配套一个 `uar` tgui 主题
（深红底 + 银白 V 形 + 蓝星的配色）。**其他雇主不受影响** —— 辛迪加 / 纳米传讯那些雇主
照旧用它们自己主题自带的底纹。

铺图条件是 `theme === 'uar'`，而 `theme` 就是雇主的 `ui_theme` 字段。所以：

- 雇主写 `"ui_theme": "uar"` → 带这张图 ✓
- 属于 `uar` 阵营但没写 `ui_theme` 的雇主 → 走兜底主题也是 `uar` → 一样带图 ✓
- 其他雇主 → 完全不带这张图 ✓

⚠️ **别改成无条件铺图**：那样所有雇主（辛迪加/纳米那些）的叛徒都会变成这张 UAR 图，
等于「团结联盟专属背景」这个需求本身被做废了（来回踩过一次）。

配好的雇主条目长这样：

```json
{
  "name": "团结联盟",
  "faction": "uar",
  "outcome": "both",
  "ui_theme": "uar",
  "introduction": "你是{name}的叛徒。"
}
```

### 生效链路（五处联动，改图/换主题时照这个核对）：

| # | 位置 | 作用 |
| --- | --- | --- |
| 1 | `modular_tianguan/modules/traitor_background/icons/background.png` | 图标本体（来源 `uar.png`，436×419）。**换图直接覆盖它再重新构建即可** |
| 2 | `code/traitor_background.dm` 的 `/datum/asset/simple/tianguan_traitor_background` | 注册「`tianguan_traitor_background.png` → 文件」进 asset 缓存 |
| 3 | 同上文件 `/datum/antagonist/traitor/ui_assets()` | 界面打开时把这份资源下发给客户端 |
| 4 | `tgui/packages/tgui/styles/themes/uar.scss` | `uar` 主题配色（+ 关掉主题自带装饰背景）；由 `styles/main.scss` 一行 `@include` 挂进去 |
| 5 | `tgui/.../interfaces/AntagInfoTraitor.tsx` | `theme === 'uar'` 时才铺图，并叠一层黑色渐变压暗 |

**为什么图必须由 TSX 铺、不能在 SCSS 里写死**：tgui 的图片走 BYOND asset 缓存，URL 要运行期
用 `resolveAsset()` 才算得出来（取决于 asset transport），CSS 里拿不到这个 URL。

**为什么下发资源用 `ui_assets()` 而不是全局注册**：tgui 只在界面打开时下发
`src_object.ui_assets(user)` 返回的资源（`code/modules/tgui/tgui.dm` 的 `send_assets()`），
界面 UI 的 `src_object` 就是叛徒的 antag datum。上游 `/datum/antagonist/traitor` 没有定义过
`ui_assets()`（只有 `/datum/` 上的空实现），所以这里能直接扩展，**不用改 DM 核心文件**。

### 调暗：

第 5 处那层 `linear-gradient(rgba(0, 0, 0, 0.45), ...)` 就是压暗层 —— 它作为 `backgroundImage`
的第一个图层盖在徽记上面。**改 `0.45` 就能调明暗**：`0.3` 更亮，`0.6` 更暗（1.0 = 全黑）。
想彻底不要压暗就删掉那层渐变，只留 `url(...)`。

其他可调项都在同一个 style 块里：`backgroundSize: 'cover'` → 保持比例铺满（620×650 窗口对
436×419 的图左右各裁约 6%）；换 `contain` 则整图完整显示、四周留主题底色；`backgroundPosition`
控制位置。

### uar 主题：

`tgui/packages/tgui/styles/themes/uar.scss`，配色取自徽记：`--color-base: #5c0e12`（深红底）、
`--color-primary: #c9cdd6`（银白）、`--button-background-selected: #1f3a8a`（蓝星）。
主题名由 `Layout` 拼成 `theme-uar` 挂到 `document.documentElement` 上
（`tgui/packages/tgui/layouts/Layout.tsx`），所以用 `.theme-uar:root { ... }` 定义变量。

⚠️ 新增主题名叫什么，就得往 **`modular_tianguan/modules/custom_employers/code/custom_employers.dm`
的 `GLOB.tianguan_employer_themes` 白名单**里加什么 —— 那个白名单校验 `ui_theme`，不在表里会被
**静默回退成阵营默认主题**（`uar` 已经加进去了）。

### 核心文件 / Proc 改动：

- **DM 核心：无。** `/datum/antagonist/traitor/ui_assets()` 是上游未定义的 proc，直接在模块里扩展。

### 上游 TGUI 文件改动：

- `tgui/packages/tgui/interfaces/AntagInfoTraitor.tsx` —— 新增 import `resolveAsset`，
  以及 `isUnionTheme` 条件背景块（`// TIANGUAN EDIT ADDITION - TRAITOR_BACKGROUND` 标记）。
- `tgui/packages/tgui/styles/main.scss` —— 在 NOVA 块之后新增 `TIANGUAN EDIT ADDITION` 块加载 `uar.scss`。
- 两者都是**纯追加**，同步上游冲突时保留两侧即可。

### 模块化覆盖：

- 无（未改 `code/`、`modular_nova/` 任何文件）

### Defines：

- `TIANGUAN_TRAITOR_BACKGROUND_ASSET` —— 本模块 `.dm` 内定义，文件底部 `#undef`。

### 本模块目录外的依赖文件：

- `tgstation.dme` —— 一行 `#include` 登记本模块
- `config/tianguan/employers.json` —— 雇主条目里的 `ui_theme: "uar"` 才会触发
- `tgui/packages/tgui/styles/themes/uar.scss` + `styles/main.scss`
- `tgui/packages/tgui/interfaces/AntagInfoTraitor.tsx`

### 构建 / 测试方式：

- **tgui 改动必须重新打包**：`BUILD.cmd`（含 `TguiTarget`）；只跑 `dm.exe tgstation.dme` 只更新 DM 侧。
- ⚠️ `BUILD.cmd` 的 DM 那步是 `spawn('dm.exe')`，**要求 `dm.exe` 在 PATH**，否则报
  `Executable not found in $PATH` —— 本机没配 PATH 时 tgui 那半已产出新 bundle，DM 侧用绝对路径补编。
- 自检：
  - `grep -c theme-uar tgui/public/tgui.bundle.css`（≥1）
  - `grep -c tianguan_traitor_background tgui/public/tgui.bundle.js`（≥1）
  - `cd tgui && bun run tgui:tsc`（退出码 0）
  - 服务器启动日志无 `ERROR: Invalid asset`（资源路径错会 `CRASH("invalid asset sent to asset cache")`）
- 游戏内：抽到 / 用管理员面板发一个**团结联盟**雇主的叛徒，界面应当带徽记背景且整体偏暗；
  抽到其它雇主的叛徒则完全没变。

### 维护备注：

- 同步上游时留意两件事：`/datum/antagonist/traitor` 是否新增了 `ui_assets()`（加了就要改成往上游那份里塞）；
  `AntagInfoTraitor.tsx` 的 `Window.Content` 是否被改写（两处 `TIANGUAN EDIT` 标记就是全部差异）。
- 同一套「注册 asset + ui_assets() 下发 + resolveAsset 引用」的手法适用于任何 tgui 界面的图片资源
  （参考 `NtosRadar` 的 `ntosradarbackground.png`）；主题则照 `clockwork` 的样子加。
