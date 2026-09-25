# 自定义叛徒雇主 (CUSTOM_EMPLOYERS)

模块 ID：`CUSTOM_EMPLOYERS`

### 说明：

给叛徒（Traitor / Marauder）的「雇主」池加一批**可配置**的雇主。服务器管理员在
`config/tianguan/employers.json` 里按字段填写，重启后这批雇主就参与原有的随机抽取，被抽中的
叛徒在 AntagInfoTraitor 界面（Intro / Employer / Uplink 三个分区）和回合结算里看到管理员填的文本。

上游原有雇主（当克公司、纳米传讯内务部、戈莱克斯掠夺者……）完全不受影响，自定义雇主是**追加**。

> `employers.json` 出厂是空数组 `[]`。JSON 不支持注释，所以**所有讲解都在本文档里**；
> 照着下面的「配置教学」复制改，写进 JSON 时把 `//` 注释行删掉即可。

---

## 配置教学

### 1. 最小可用 —— 两个字段就够了

```jsonc
[
  {
    "name": "极光联合体",                       // 必填。雇主名，也是下面 {name} 的值
    "introduction": "你是{name}的叛徒。"          // 必填。Intro 分区的大字开场白
  }
]
```

其余字段全部有默认值：`faction` 默认辛迪加、`outcome` 默认 `normal`、界面主题按阵营取默认、
`allies`/`goal`/`uplink`/`roundend_report` 用通用中文默认句。

### 2. 全字段

```jsonc
[
  {
    "enabled": true,                            // 可选，默认 true；写 false = 临时停用（等价于注释掉）
    "name": "深空航运工会",                       // 必填，且不能与任何上游雇主重名
    "faction": "syndicate",                     // 可选：syndicate（默认）| nanotrasen
    "outcome": "normal",                        // 可选：normal（默认）| hijack | both —— 见第 4 节
    "ui_theme": "syndicate",                    // 可选：syndicate | neutral | ntos | abductor

    "introduction": "你是{name}的叛徒。",          // Intro 分区
    "allies": "你可以与其他辛迪加特工合作，前提是他们支持我们的目标。",   // Employer 分区「你的盟友」
    "goal": "别搞无谓的屠杀，拿到东西就撤——这是我们的行事风格。",        // Employer 分区「雇主想法」
    "uplink": "你已获得一台标准辛迪加上行链路，用它完成任务。",          // Uplink 分区开场句
    "roundend_report": "曾是{name}的一名特工。"                        // 回合结算里的句子
  }
]
```

- `{name}` 占位符会被替换成该条目的 `name`（不想用占位符就直接把名字写死在句子里）。
- `_说明` 之类自定义键会被忽略，可以留作你自己的备忘。
- 想加多个雇主就照抄对象、用逗号分隔——顶层始终是一个数组。

### 3. 文本字段写什么语言

**直接写最终要显示的语言**（中文服就写中文）。这些文本不进 `strings/i18n/` 目录：i18n 的反查
只会把「目录里登记过的英文」换成译文，中文原文查不到表、原样保留。

### 4. `outcome` 到底怎么选（最容易踩的地方）

`outcome` 决定这个雇主在**哪种结局的局**里会出现：

| 写法 | 含义 | 命中率参考（正式大服） |
| --- | --- | --- |
| `normal`（默认） | 只在**非劫机**局出现（逃脱） | 辛迪加侧约 `40% × 1/6 ≈ 6.7%` |
| `hijack` | 只在**劫机**局出现 | 约 `10% × 30% × 50% ≈ 1.5%` |
| `both` | 两种结局的局都能出现 | 比 normal 略高，劫机局里也有一份 |

⚠️ **劫机局极其稀有，单人测试服上一局都不会有。** `datum_traitor.dm` 要求本局
`GLOB.joined_player_list` 人数 ≥ `HIJACK_MIN_PLAYERS`（**30**）且 `prob(HIJACK_PROB)`（**10%**）
才可能生成劫机结局；人数不足 30 时 `is_hijacker` 恒为 `FALSE`。所以拿 `hijack` 做本地验证必然刷不出来
——想验证就用 `normal` 或 `both`。

⚠️ **不要写成数组**（如 `["normal","hijack"]`）。同时进两张结局表是唯一**必然抽不到**的写法，原因见
下面「结局表是排除名单」。

### 5. 常见错误

| 现象 | 原因 |
| --- | --- |
| 改完没反应 | 文件只在**启动时**读一次，要重启服务器 |
| 某条完全没生效 | 缺 `name` 或 `introduction`、`name` 与上游雇主重名、或 `enabled: false` —— 三种都会在启动日志里写明 |
| 本地怎么刷都不出现 | 用了 `outcome: hijack`，而本局人数不到 30（见上） |
| 报了 JSON 解析失败 | 在 JSON 里写了 `//` 或 `#` 注释、多了尾逗号 —— 复制本文档的示例时记得删掉注释 |
| 界面主题不对 | `ui_theme` 填了白名单外的值，会静默回退成阵营默认（辛迪加 `syndicate` / 纳米传讯 `ntos`） |

---

## 完整示例集（5 条，直接照抄）

下面就是可以整段复制进 `config/tianguan/employers.json` 的示例。**`//` 注释只是讲解，JSON 不支持
注释，写进文件时请删掉注释行**。（`enabled` 是 JSON 里唯一合法的"停用"手段，需要哪条就把它改成 `true`。）

```jsonc
[
  {
    // ① 最小可用：只填两个必填字段，其余全走默认值（辛迪加 / normal / 阵营默认主题）
    "name": "极光联合体",
    "introduction": "你是{name}的叛徒。"
  },
  {
    // ② 全字段示范：显式指定阵营、结局、主题，并写全所有文本字段
    "name": "深空航运工会",
    "faction": "syndicate",          // syndicate（默认）| nanotrasen
    "outcome": "normal",             // normal（默认）| hijack | both
    "ui_theme": "syndicate",         // syndicate | neutral | ntos | abductor
    "introduction": "你是{name}的叛徒。",
    "allies": "你可以与其他辛迪加特工合作，前提是他们支持我们的目标。",
    "goal": "别搞无谓的屠杀，拿到东西就撤——这是我们的行事风格。",
    "uplink": "你已获得一台标准辛迪加上行链路，用它完成任务。",
    "roundend_report": "曾是{name}的一名特工。"
  },
  {
    // ③ 纳米传讯侧 + 不限结局：阵营先按 40%/30%/30% 抽，纳米侧比辛迪加侧少见；both = 两种结局的局都能出现
    "name": "纳米传讯审计署",
    "faction": "nanotrasen",
    "outcome": "both",
    "ui_theme": "ntos",
    "introduction": "你是{name}派来的审计员。",
    "allies": "不要向任何人暴露你的身份，从阴影中行动。",
    "goal": "铲除站内的腐败。你有杀人执照，但多余的破坏会让你的合同被终止。",
    "uplink": "为了撇清关系，你获得了一批缴获的辛迪加装备。",
    "roundend_report": "曾是纳米传讯审计署的一员。"
  },
  {
    // ④ 只在劫机局出现。⚠️ 劫机局要求本局 >=30 人且只有 10% 概率（见教学第 4 节），
    //    人少的测试服一局都不会有，正式大服上也只占约 1/80 个叛徒。想经常看到就用 normal 或 both
    "name": "戈莱克斯敢死队",
    "faction": "syndicate",
    "outcome": "hijack",
    "ui_theme": "syndicate",
    "introduction": "你是{name}的突击手。",
    "allies": "本局只有你一个人被派来，其他自称同僚的一律不信。",
    "goal": "把整艘船连同它的记录一起带走，别留活口去作证。",
    "uplink": "标准的辛迪加上行链路，够你打穿安保部了。",
    "roundend_report": "是{name}的一名突击手。"
  },
  {
    // ⑤ 只填部分字段：没填的自动用通用中文默认句；句子完全不写 {name} 也可以；主题换中立灰
    "name": "联合收割者",
    "faction": "syndicate",
    "outcome": "both",
    "ui_theme": "neutral",
    "introduction": "你受雇于联合收割者。",
    "goal": "收割一切有价值的东西，然后消失在黑暗里。"
  }
]
```

不想要某条就删掉整个对象，或者给它加 `"enabled": false` 留在文件里当草稿——后者更适合
"先存着，以后再用"。

---

## 字段表

| 字段 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- |
| `name` | ✅ | — | 雇主名。随机池的唯一标识，也是文本里 `{name}` 的值 |
| `introduction` | ✅ | — | Intro 分区开场白，上游模板形如 `You are the XXX.` |
| `allies` | ❌ | 通用中文默认句 | Employer 分区「你的盟友」 |
| `goal` | ❌ | 通用中文默认句 | Employer 分区「雇主想法」 |
| `uplink` | ❌ | 通用中文默认句 | Uplink 分区开场句 |
| `roundend_report` | ❌ | `曾是{name}的叛徒。` | 回合结算里的句子，上游模板形如 `was an employee from XXX.` |
| `faction` | ❌ | `syndicate` | `syndicate` / `nanotrasen` / `uar`（第三个是天关加的新阵营，见下节） |
| `outcome` | ❌ | `normal` | `normal` / `hijack` / `both`，见教学第 4 节 |
| `ui_theme` | ❌ | 阵营默认 | 界面主题：`syndicate` / `neutral` / `ntos` / `abductor` / `uar`（`uar` = 团结联盟主题，界面还会额外铺徽记背景） |
| `enabled` | ❌ | `true` | 写 `false` = 临时停用该条（JSON 没有注释，用这个代替） |

---

## 机制：为什么「加个雇主」要动三处数据

上游把「一个雇主」拆成三份互不相干的数据，`/datum/antagonist/traitor/proc/pick_employer()`
要求三者**同时命中**，缺一个的后果各不相同：

| 数据 | 位置 | 缺了会怎样 |
| --- | --- | --- |
| 阵营名表 | `GLOB.syndicate_employers` / `nanotrasen_employers`（`code/__DEFINES/antagonists.dm`） | 永远不进候选池 |
| 结局表 | `GLOB.hijack_employers` / `normal_employers`（同上） | 见下节，进错表会被筛掉 |
| 文本表 | `strings/antagonist_flavor/traitor_flavor.json` | `strings()` 查不到键会直接 `CRASH` |

本模块一次把三处都注入，管理员只需要填文本，不用关心这套三重注册。

## 结局表是**排除名单**，不是包含名单

`pick_employer()` 构造候选池的完整顺序：

1. 候选 = `syndicate_employers` ∪ `nanotrasen_employers`
2. 按本局结局**减掉一张表**：劫机局减 `normal_employers`，非劫机局减 `hijack_employers`
3. 按阵营再**减掉对面那张表**

「减」= 把候选里出现在该表中的名字移除。所以结局表是**排除名单**：

- 名字进 `normal_employers` → 劫机局会把它减掉 → **只在非劫机局出现**
- 名字进 `hijack_employers` → 非劫机局会把它减掉 → **只在劫机局出现**
- 名字**两张表都不进** → 两个分支都不动它 → **两种局都能出现**（即 `outcome: both`）
- 名字**两张表都进** → 两个分支都把它减掉 → **永远抽不到**

上游 14 个雇主恰好铺满这两张表且互不相交，所以「两张都不进」这条口径一直没被用到——
`outcome: both` 就是本模块新增的用法。

`/datum/antagonist/traitor/marauder`（掠夺者）用同一套算法且结束目标恒为「存活」，
所以它只会抽到 `outcome: normal` / `both` 的雇主。

## 三个阵营（faction）

`pick_employer()` 先给每个叛徒**各自**掷一次阵营，再从该阵营的名单里等概率抽一个雇主。上游只有
两个阵营、写死 `prob(75)`，天关把这一掷换成了模块里的加权掷骰：

| `faction` | 名字进哪张表 | 默认权重 |
| --- | --- | --- |
| `syndicate` | 核心 `GLOB.syndicate_employers` | **40** |
| `nanotrasen` | 核心 `GLOB.nanotrasen_employers` | **30** |
| `uar` | 模块自己的 `GLOB.tianguan_uar_employers`（团结联盟） | **30** |

权重表在 `code/custom_employers.dm` 的 `GLOB.tianguan_employer_faction_weights`，`pick_weight` 按比例抽、
**不必凑够 100**（改成 7/2/1 效果一样）。掷定阵营后会把**另外两张名单整个减掉**，所以雇主只可能
出现在自己阵营的那一支里。

阵营还决定 `ui_theme` 没填 / 填了白名单外的值时的兜底主题（`GLOB.tianguan_employer_faction_themes`）：
`syndicate`→`syndicate`、`nanotrasen`→`ntos`、`uar`→`uar`。

⚠️ **`ui_theme` 必须登记进 `strings/i18n/policy.json` 的 `payload_skip_keys`（已登记）。**
服务器的 i18n（`modular_nova/modules/i18n`）会把 flavor 表里的字符串值就地反查翻译，`ui_theme` 原本被翻成
「辛迪加」——于是 tgui 拿到 `theme-辛迪加` 这种类名，**匹配不到任何 CSS**，界面掉回默认蓝（看着像纳米的），
而且完全静默。`ui_theme` 属于「值兼标识符」（前端拿它拼 CSS 类名），正是 `payload_skip_keys` 要挡的那类。

- 以后**再加新主题名不用动 policy.json**：豁免按字段名整类生效。
- 但若哪天改了字段名（不再是 `ui_theme`），记得把新字段名也登记进去。
- 两份副本都要同步：`strings/i18n/policy.json` 与 `tgui/packages/tgui/i18n/policy.json`。
- 启动日志有 `主题抽查 ... → ui_theme=` 行可直接核对，出现中文就是被翻了。

⚠️ **`uar` 阵营的雇主不会出现在掠夺者身上** —— `modular_nova/modules/marauders/marauder.dm` 的
`pick_employer()` 只用辛迪加名单（本模块没改它）。

## 注入时机

GLOB 全局表的初始化 proc 由 `typesof()` 顺序调用，**这个顺序不可依赖**
（`code/controllers/globals.dm`），所以不能在自己的 `GLOBAL_LIST_INIT` 表达式里直接往雇主池追加
——可能追到还没建好的 `null` 上。本模块改用 `SUBSYSTEM_DEF(tianguan_employers)`
（`SS_NO_FIRE`，只跑一次 `Initialize()`）：子系统初始化在 GLOB 之后、任何叛徒生成之前
（见 `code/game/world.dm` 顶部的初始化顺序注释），是唯一既确定又不用改核心文件的位置。

也因此**不需要**覆盖 `pick_employer()`：DM 不允许同一类型上重复定义同一个 proc，
后 include 不会覆盖、只会编译报错，硬接管就得把整份 `datum_traitor.dm` 从清单里摘出来。

## 用法与自检日志

1. 编辑 `config/tianguan/employers.json`（照「配置教学」写，删掉注释）。
2. 重启服务器（文件只在启动时读一次）。
3. 看启动日志（`-log data/server.log` 或 `data/logs/`）：

```
CUSTOM_EMPLOYERS: config/tianguan/employers.json 读到 6 条，启用 1 条，已禁用 5 条 → 团结联盟
CUSTOM_EMPLOYERS: 自检（辛迪加池 9 条 / 纳米传讯池 5 条 / 团结联盟池 1 条）
CUSTOM_EMPLOYERS: 阵营权重 辛迪加 40 / 纳米传讯 30 / 团结联盟 30（相对比例）
CUSTOM_EMPLOYERS: 发牌抽样 2000 次（逃脱局）→ 辛迪加 785 / 纳米传讯 594 / 团结联盟 621 · 空池 0 · 跨阵营 0
CUSTOM_EMPLOYERS: 团结联盟 普通结局可抽=1 劫机结局可抽=1 开场白=你是团结联盟的叛徒。
```

第一行不管有没有启用条目都会打（全禁用时显示 `启用 0 条`），免得看起来像模块没跑。

自检行不是装饰：它把 `pick_employer()` 的池算法原样跑一遍，并按 pick 之后那条 `strings()` 路径
真实取一次文本。所以「可抽=1」就是真的能抽到，「开场白=…」就是玩家会看到的那句话；
写 `both` 的雇主应当两列都是 1。

**`发牌抽样` 那行是回答「池子是不是不刷了」用的**：它把完整流程（阵营掷骰 → 结局筛 → 阵营减集 →
`pick`）跑 2000 次，报实际抽到的雇主属于哪个阵营。三个数应当贴近权重（40/30/30 ± 随机波动），
`空池 0` = 没有任何一支会选出空池，`跨阵营 0` = 没有「掷到辛迪加却抓到纳米雇主」这种减集错误。
游戏里怀疑没刷到某个阵营时，先看这行 —— 这行正常就说明是运气或界面问题，不是池子问题。

## 容错

任何一条目出错都只写日志、跳过该条，不影响启动与其它条目：

- JSON 语法错 / 顶层不是数组 → 整批跳过
- 缺 `name` 或缺 `introduction` → 跳过该条
- `name` 与现有雇主重名 → 跳过该条（**不覆盖**上游文本，避免和 i18n 目录对不上）
- `faction` / `ui_theme` 取值非法 → 回退默认值，不跳过
- `outcome` 误写成数组 → 取第一个元素并记日志提示（多值必然是笔误）
- `enabled: false` → 静默跳过并计入「已禁用」条数

## 核心文件 / Proc 改动

**有，只有一处：`code/modules/antagonists/traitor/datum_traitor.dm`**（要加第三个阵营就绕不过去）：

- 顶部新增 `#define FLAVOR_FACTION_UAR "uar"`（与另外两个阵营定义并排；文件底部同样 `#undef`）
- `pick_employer()` 三处：阵营掷骰改成调用模块的 `tianguan_roll_employer_faction()`；候选池并进
  `GLOB.tianguan_uar_employers`；`switch(faction)` 增加 `uar` 分支（另两个分支各加一行「减掉 uar 名单」）
- 全部带 `TIANGUAN EDIT` 标记：能写一行的写在同一行（并附 `ORIGINAL:`），多行的用 start/end 包起来

**为什么不能模块化**：DM 不允许在同一个类型上重复定义同一个 proc —— 后 include 不会覆盖、只会
`duplicate definition` 编译报错，所以模块里没法 override `pick_employer()`。唯一纯模块的替代是
把整份 349 行的 `datum_traitor.dm` 从清单里摘掉、用 `modular_tianguan/master_files/` 整份接管，
为「多一个阵营分支」背整份文件的上游同步债不划算，所以选了最小核心改动。

**同步上游时注意**：三处都标了 `TIANGUAN EDIT`，冲突时保留两侧；若上游重写了 `pick_employer()`，
要把 uar 分支重新加回去（否则 `GLOB.tianguan_uar_employers` 里的雇主永远抽不到）。另外
`tianguan_roll_employer_faction()` 与 `GLOB.tianguan_uar_employers` 都定义在本模块里 ——
**本模块被移除而核心那句调用还在的话会运行时报错**，两者是一套的。

## 模块化覆盖

- 无

## Defines

- `TIANGUAN_CUSTOM_EMPLOYERS_FILE`、`TIANGUAN_EMPLOYER_NAME_TOKEN`、
  `TIANGUAN_EMPLOYER_FACTION_SYNDICATE`、`TIANGUAN_EMPLOYER_FACTION_NANOTRASEN`
  —— 均在本模块 `.dm` 文件内定义，文件底部 `#undef`，不污染全局编译上下文。

## 本模块目录外的依赖文件

- `config/tianguan/employers.json` —— 管理员填写的数据（与 medical_blanks 的 `blanks.json` 同目录同风格）
- `tgstation.dme` —— 新增一行 `#include` 登记本模块

## 测试方式

- DM 编译通过（0 errors）。
- 启动本地服务器看上面那几行日志：条数统计 + 池大小 + 每个雇主的结局归属 + 真实取到的开场白。
- 游戏内抽一局叛徒（等概率 pick，想快点看到就多填几条），界面显示自定义雇主的开场白 / 盟友 /
  雇主想法 / 上行链路文本。**本地验证别用 `outcome: hijack`**，见教学第 4 节。

## 维护备注

- 同步 Nova 上游时，只需留意 `code/__DEFINES/antagonists.dm` 的四张雇主表、
  `datum_traitor.dm` 的 `pick_employer()` 是否改了筛选方式，以及
  `strings/antagonist_flavor/traitor_flavor.json` 的键名是否变化——模块只按名字追加、按上游键名写
  flavor，不复制任何上游内容。
- 同一套机制也适用于故障 AI（`GLOB.ai_employers` + `malfunction_flavor.json`），本模块暂不涉及；
  如需扩展，照「三处同时注入」的思路加一组 `ai_` 池即可。
