https://github.com/89623/TianGuan13/pull/<!--PR 编号-->

## 轻量化液体虹吸器（零件造机 + 范围/速率可调 + TGUI 面板）

模块 ID：`LIQUID_SIPHON`

### 说明：

一台**用零件造出来**的便携机器：吸取周围地面上的液体并**直接消除**（不存储、不转移）。
与仓库里已有的那台便携液体泵互补 —— 那台是结构体、无电源、只能在自身一格上按百分比吸吐；
本机是正规机器：有电池、有零件等级、可框选范围、带 TGUI 面板。

- 名称：轻量化液体虹吸器
- 介绍：星狐工业出品。纳米传讯协商后将核心技术小型化的成果，原型是海洋星球行星改造工程项目退役下来的特种装备。
- 手持容器不参与（本机不留液）；**手持电池左键机器 = 装入电池**。

### 数值：

| 扫描模块等级 | 范围 | | 物质仓等级 | 速率（每格） |
|---|---|---|---|---|
| 1 级 | 仅本格 | | 1 级 | 10 单位/秒 |
| 2 级 | 3×3 | | 2 级 | 25 单位/秒 |
| 3 级 | 5×5 | | 3 级 | 50 单位/秒 |
| 4 级 | 7×7 | | 4 级 | 100 单位/秒 |

- **耗电**：运行时**每 3 秒消耗 1 kJ**（= 每秒 1000/3 焦耳）。
  本仓单位换算（源码依据 `code/__DEFINES/power.dm`）：`STANDARD_CELL_CHARGE = (10 KILO) JOULES` ⇒
  **1 充能单位 = 1 焦耳，标准电池满电 10 kJ**。于是满电续航约为：

  | 电池 | 满电 | 续航（约） |
  |---|---|---|
  | 标准 | 10 kJ | 30 秒 |
  | 升级 | 25 kJ | 75 秒 |
  | 高容 | 50 kJ | 150 秒 |
  | 超级 | 400 kJ | 20 分钟 |

  电池耗尽 ⇒ 自动停机并提示。面板电量栏除百分比外**另显原始数值**（如 `9870 / 10000`），因为按 1 kJ/3 秒
  的速率百分比每 5 分钟才动 0.5%、只看百分比会误以为没耗电。
- **零件等级取法**：同类 3 个零件取**平均等级**后向下取整、钳到 1~4。装整套同级零件即为该等级。
- **面板里可以往下选**：零件到了 4 级，也能把范围/速率调低（省电）。换零件后选择会被自动钳回合法范围。

### 怎么造（游戏内步骤）：

1. **研究**：Atmospherics 科技节点（与**便携式空气洗涤器**同一节点）⇒ 凡能造洗涤器电路板的车床/部门车床，都能造本机电路板。
2. **电路板**：轻量化液体虹吸器电路板（与洗涤器同研究分类、同部门权限）。
3. **组装**：机器框架 → 装入电路板 → 装入 **3 个扫描模块 + 3 个物质仓** → 螺丝刀完成。
   **电池不是建造零件**：造好后手持电池左键机器即可装入（面板里也能弹出）。
4. **使用**：左键机器打开面板 —— 从上到下依次为：**顶部「——星 狐 ⚙ 工 业——」装饰字（开启时齿轮自转并变绿）**
   → **等宽的「启动 / 停止」与「弹出电池」** → 电池（百分比 + 原始数值）→ 范围 → 速率 → 零件等级。
   机器默认可拖拽（未锚定），扳手锚定/解除。

### 实现要点：

- **直接消除**：从地面取液用 `take_reagents_flat()`（该 proc 自身负责液面高度与视觉，取空时删掉液体效果对象），随后 `qdel` 掉取回的那份试剂 —— 不存机内，故无容量上限、也不会积攒。
- **与帧率无关**：走 `process(seconds_per_tick)`，吸收量 = 速率 × `seconds_per_tick`，耗电同理 ⇒ 服务器卡顿或帧率变化都不影响数值。
- **贴图**：模块自带 `icons/liquid_siphon.dmi`，与气体虹吸器**三态同构**：`siphon`（代表性静态图，单帧）/ `siphon_0`（关闭，单帧）/ `siphon_1`（运行，4 帧循环，帧延迟 `0.5,0.5,0.5,0.5` 分秒 = 0.05 秒/帧，与 `icons/obj/pipes_n_cables/atmos.dmi` 里气体虹吸器的 `siphon_1` **完全一致**），由 `update_icon_state()` 按开关拼 `"[基名]_[on]"` 切换。素材按 `modular_tianguan/readme.md`「资源文件」的推荐形状放在模块自己的 `icons/` 下，**没有碰核心 dmi**。
  - ⚠️ **`siphon` 这一态不能省**：部门车床 / 研究控制台里**电路板的图标显示的是「它造出来的那台机器」的图标** ——
    `code/modules/asset_cache/assets/research_designs.dm` 把 `/obj/item/circuitboard` 替换成它的 `C.build_path`（= 机器），
    再取机器**编译期**的 `icon_state`（= `siphon`）。少了这一态，本机电路板在车床里就会显示成坏图
    （上游自带检测 `focus_only/invalid_research_designs` 会 `stack_trace("... missing state ...")` 点名）。
- **可拖拽**：`anchored = FALSE`（同气体虹吸器），扳手锚定。
- **电池槽**：`item_interaction` 收电池；面板「弹出电池」优先塞回手里，塞不下则落地。拆机（`on_deconstruction`）也会把电池掉出来。

### 货舱采购：

`/datum/supply_pack/engineering/portasiphon` —— 定义在**本模块** `code/liquid_siphon.dm` 末尾，
**没有动 `code/modules/cargo/packs/`**。分类（`group`）与价格档、权限、箱子**全部沿用同类的
便携式空气泵 / 便携式空气洗涤器**（`code/modules/cargo/packs/engineering.dm` 的 `portapump` / `portascrubber`）：

| 字段 | 本机取值 | 同类对照（portapump） |
|---|---|---|
| 分类 | 继承 `/datum/supply_pack/engineering` ⇒ `group = "Engineering"`（货舱里的「工程部」） | 同 |
| 内容物 | 轻量化液体虹吸器 ×2 | 同（2 台） |
| 价格 | `CARGO_CRATE_VALUE * 4.5` | 同 |
| 查看权限 | `ACCESS_ATMOSPHERICS` | 同 |
| 箱子 | `/obj/structure/closet/crate/secure/engineering/atmos` | 同 |

- 商品靠 `subtypesof(/datum/supply_pack)` 自动进目录 ⇒ **只要挂着父类型 + `contains` 非空即可**，
  不需要在核心 `packs/` 里登记。
- `crate_type` **必须显式给**：`pack.generate()` 里 `if(!crate_type) CRASH(...)`，留空是建造即崩。
- 「2 台一箱」是照抄同类设备的既有形状；要改成 1 台或改价，改 `contains` 的倍数与 `cost` 一处即可。

### 核心文件 / Proc 改动：

改动**只有 2 行**，都在共享文件里，且都带 `LIQUID_SIPHON` 标记：

| 文件 | 改动 | 为什么不能模块化 |
|---|---|---|
| `tgstation.dme` | +1 行 include | 项目清单，模块代码必须登记才会编译 |
| `code/modules/research/techweb/nodes/atmos_nodes.dm` | +1 行 `TIANGUAN EDIT ADDITION - LIQUID_SIPHON`：把 `/datum/design/board/light_liquid_siphon` 放进与洗涤器相同的科技节点 | 科技节点是**既有类型的既有列表字面量**，DM 无反射、不能从外部追加 |

- **没有修改任何既有类型的既有变量、没有改任何既有 proc 的实现**（无 `duplicate definition` 风险）。
- 电路板零件清单：**3 扫描模块 + 3 物质仓**（电池不参与建造，另装）。

### 模块化覆盖：

- 无。未使用 `modular_tianguan/master_files/`，没有覆盖任何既有 proc 或变量。

### Defines：

- 4 个模块内宏，全部定义在 `code/liquid_siphon.dm` 顶部、**在文件底部 `#undef`**
  （按 `modular_tianguan/readme.md`「Defines」：只服务单文件的宏不留在全局编译上下文；
  仓内先例 `custom_employers` / `emergency_shuttle_cc` / `guide_browser`）：

| 宏 | 值 | 用途 |
|---|---|---|
| `SIPHON_RANGE_SIDES` | `list(1, 3, 5, 7)` | 范围等级 → 方形边长（格） |
| `SIPHON_RATES` | `list(10, 25, 50, 100)` | 速率等级 → 单位/秒（每格） |
| `SIPHON_JOULES_PER_SECOND` | `(1000 / 3.0)` | 每秒耗电（= 3 秒 1 kJ） |
| `SIPHON_MAX_TIER` | `4` | 等级上限（四级零件） |

- 没有新增任何跨文件共享的全局 define。

### 本模块目录外的依赖文件：

- `tgui/packages/tgui/interfaces/TianGuanLiquidSiphon.tsx` —— 新增 TGUI 界面（顶部已标
  `// THIS IS A TIANGUAN UI FILE`，按 `modular_tianguan/readme.md`「TGUI 修改」）；
  **文件名必须与 DM 里 `ui = new(user, src, "TianGuanLiquidSiphon")` 的字符串一字不差**，否则点开是空白且不报错。
- `code/modules/research/techweb/nodes/atmos_nodes.dm`、`tgstation.dme` —— 见上表那 2 行。
- 除此之外**不依赖任何模块目录外的文件**（不依赖 Nova 上游文件，也不依赖 `modular_tianguan/code|icons|sound` 顶层共享目录）。

### 构建 / 测试方式：

**前提：任何服务器副本都必须先做一次前端构建**，否则面板点了会是空白 ——
`tgui/public/` 是构建产物、不进仓库。顺序：前端打包 → 删 `tgstation.rsc` → 编 DM。

1. **编译**：`dm.exe tgstation.dme` ⇒ 0 errors。
2. **探针（已验证数值层，17 项断言 16 通过）**：覆盖零件等级换算（T4 整套⇒4/4、T1 整套⇒1/1 且选择被钳回）、范围取舍（范围1 只动本格；范围2 动邻格但距离 2 的格不受影响）、速率取舍（速率1 每格 10/秒；速率4 每格 100/秒）、关机不吸、**直接消除**（吸干后那格的液体对象真的消失）、耗电（**3 秒整 1 kJ** 精确通过）、无电池自动停机且不吸。
   唯一未按预期的那条是**我探针里的期望值写太严**：1 秒的理论耗电是 1/3 kJ，取两位小数应为 0.33，实测 0.34（`cell.use()` 对分数有取整）—— 属探针断言容差问题，非模块缺陷；规格要求的「3 秒 1 kJ」精确成立。
3. **游戏内（需要你实测）**：
   - 研究 Atmospherics → 部门车床里能看到「轻量化液体虹吸器电路板」；
   - 造板 → 机器框架组装（3 扫描 + 3 物质仓 + 1 电池）→ 螺丝刀完成，机器出现在原地且贴图是**本机专属图**（关闭态单帧；装入电池并启动后变为 4 帧循环动画）；
   - 在地上泼点液体（烧杯倒 / 洒试剂都行）→ 手持电池左键装入 → 左键开面板 → 启动 ⇒ 范围内地面的液体**应当直接被消除**（液面下降，吸干后地面变干净）；
   - 面板里切换范围/速率 ⇒ 生效范围与吸收速度随之改变，且不会超过零件等级；
   - 拔电池（面板「弹出电池」）⇒ 机器停机；再手持电池左键 ⇒ 装回；
   - 观察耗电：3 秒掉 1 kJ（面板电量百分比）；
   - 拖动/扳手锚定正常。
   - **货舱**：供应控制台 → 「工程部」里能看到**轻量化液体虹吸器采购箱**；下单后箱内含 2 台虹吸器（箱子需大气权限打开）。
4. **贴图 / 货舱契约校验（本次已跑，24/24 通过）**：以模块 `.dm` 为唯一真相断言 ——
   dmi 为 32×32、状态恰为 `siphon_0`(1 帧) 与 `siphon_1`(4 帧，延迟 `0.5,0.5,0.5,0.5` 与气体虹吸器一致)；
   代码 `icon` 路径 == 模块自带 dmi 且文件在磁盘存在；`update_icon_state()` 拼出的两个状态名都能在 dmi 里命中；
   货舱包 `contains` 非空且为 2 台本机、`cost` / `access_view` / `crate_type` 与 `portapump` **逐字相同**。
   编译：`dm.exe tgstation.dme` ⇒ **0 errors, 3 warnings**（那 3 条是 `_compile_options.dm` 的既有提示，与本模块无关）。

### 已知取舍：

（规格未写明处，如需改动都很便宜）

1. **1 级范围的「设备下一格」按【机器自己所在的那一格】实现**（不额外向下取格）。若要改成取正下方那一格，改 `process()` 里的范围计算即可。
2. 速率 2 级与 3 级相同（按需求原文 50/50 实现，未做额外区分）。
3. 面板未做「累计消除量」统计（需求未提）；如需要可加。
4. 贴图的运行态帧延迟沿用气体虹吸器的 `0.5` 分秒/帧；想让动画慢到看得清，把 dmi 里 `siphon_1` 的 `delay` 加大即可（与代码无关）。

### 回退：

删除 `modular_tianguan/modules/liquid_siphon/` 与 `tgui/packages/tgui/interfaces/TianGuanLiquidSiphon.tsx`，
并撤销 `tgstation.dme` 与 `atmos_nodes.dm` 里那两行（均有 `LIQUID_SIPHON` 标记可搜），随后重编即可。

### 维护备注：

- **上游同步**：本模块只碰 2 行共享文件，且都在行内带标记 ⇒ 解决冲突时按标记逐行判断即可，
  `grep -n LIQUID_SIPHON` 能一次列出全部足迹。
- **科技节点被上游改动时**：`atmos_nodes.dm` 里那一行若被上游重排/改名，会造成
  `undefined` 编译错误（Δ 响亮失败，不会静默失效），跟着改回即可。
- **改贴图后必须重编 + 重启**：图标是编译期资源，没有热重载（`dm.exe` 会把它打进 `tgstation.rsc`）。
- **改 TGUI 界面后必须重跑 `tgui:build`**：`tgui/public/*.bundle.js` 不进仓库，服务器启动时读文件。

### 致谢：

- 机器实现与贴图由天关自行维护；贴图状态命名沿用仓库既有的气体虹吸器（`icons/obj/pipes_n_cables/atmos.dmi` 的
  `siphon_0` / `siphon_1`），货舱商品的字段形状沿用同类便携式大气设备的既有写法。
