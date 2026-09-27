https://github.com/89623/TianGuan13/pull/<!--PR 编号-->

# 团结联盟海军陆战队第四代模块服 + 武装部 ID 卡 (UAR Marine MODsuit)

模块 ID：`UAR_MARINE_MODSUIT`

### 说明：

新增团结联盟阵营的第四代模块服，以及配套的武装部 ID 卡：

1. **`/datum/mod_theme/uar_marine`**（skin 名 `uar_marine`）—— 第四代全环境防护服：
   - 描述 / 深层描述按需求方给的文案；
   - **移速 `slowdown_deployed = 0.75`**，与死亡小队（秘典 apocryphal）一致（基类默认就是 0.75，这里显式写出，免得基类哪天改了默认值跟着漂）；
   - **护甲九项全部 100**（近战/子弹/激光/能量/爆炸/生物/耐热/耐酸/创伤）；
   - 其余档位与死亡小队/陆战队同档：`FIRE_PROOF|ACID_PROOF`、`FIRE_IMMUNITY_MAX_TEMP_PROTECT`、`siemens_coefficient = 0`、`complexity_max = DEFAULT_MAX_COMPLEXITY + 10`、耳部防护正常档；胸甲储物允许手电/气罐/弹匣/弹药盒/手铐/闪光弹/电棍/球枪。
2. **`/obj/item/mod/control/pre_equipped/uar_marine`** —— 可直接刷出的整套：**蓝空电池**（`/obj/item/stock_parts/power_store/cell/bluespace`）+ **17 个内置模块**（清单与 `modular_z121/code/modules/modsuit/contain_mod` 参考逐项一致，合计 complexity **22** ≤ 本主题上限 **25**，装得下且还能再加 3 点）+ 喷气包进 `default_pins`（快捷栏固定）。模块清单与复杂度核算写在代码注释里。
3. **启动音效**：需求方给的 `启动.ogg` → `sound/uar_marine_start.ogg`（ASCII 文件名），由 `activation_sound` 在**套装启动完成那一刻**播放（见下面「核心文件改动」）。
4. **武装部 ID 卡**：`/obj/item/card/id/advanced/uar_marine` + `/datum/id_trim/uar_marine`
   - 卡本体名 = **团结联盟武装部**；trim 的 `assignment`（卡面上那行「印花」）= **海军陆战队**
   - `card_uar` —— 整张卡面（红卡 + 屏幕 + UA + 绿条 + 金触点）
   - `trim_uar` —— 卡面徽记（红眼骷髅），即需求方说的「id卡卡面」
   - `huduar` —— secHUD 图标（红底 UAR 徽），挂在 trim 的 `sechud_icon` / `sechud_icon_state` 上
   - 部门色块 = 卡面自身的红（`#b00c28`），副部门条 = 团结联盟蓝星（`#1f3a8a`，取自 `tgui/styles/themes/uar.scss`）
   - **全权限**：按需求「要有所有地方的权限」，`New()` 里给 `SSid_access.get_region_access_list(list(REGION_ALL_GLOBAL))`（= 上游 debug/admin 卡那句 "Has every single access in the game"，实测覆盖 98 个区域门禁：站点 74 + 中央/辛迪加/远离站/邪教 24），再加 4 个不在任何区域里的真实门禁 `ACCESS_ROROCO` / `ACCESS_ROROCO_SECURE` / `ACCESS_HERETIC` / `ACCESS_HUNTER`。
   - **特工卡（agent card）能伪装成这张卡**：外观菜单（Change ID Card Appearance）与身份菜单（Change ID Trim）里都有它，见下面「核心文件 / Proc 改动」那 2 行；伪装只换外观不换权限。

### 素材来源与落点（改图前先看这一段）：

美术素材由需求方提供 36 张 32×32 PNG。其中**穿戴态（mob）素材是每个部件各自居中导出的**，直接塞进 32×32 人形网格会出现「头盔压在胸口、靴子在腰上、背包糊在身上」——所以除物品态之外，每个部件都按**上游同类部件的槽位**做了对齐位移（位移量 = 上游参考槽位左上角 − 素材原槽位左上角，逐部件量出来）。物品态（obj）素材本来就是按槽位画的，除胸甲外全部原样使用。

**对齐判据（以后再微调照这个来，不要只看包围盒左上角）**：参照物取**人体本身**，不是别的套装 —— 人体躯干层 `icons/mob/clothing/under/color.dmi` 的 `jumpsuit`(d0) 占 **x7..23（中心 15.0）**、`y10..28`。
- **头盔**：bbox 中心与质心都要落在 **x=15.0**（上游所有模块服头盔 d0/d1 都正好如此；侧视 d2/d3 因素材 10px 宽落在 15.5）；
- **手套**：**两只手套成对中心**落在 **x=15.0**，且每只盖住手臂列 7-10 / 20-23；
- **背包**：分两种朝向，判据不一样 ——
  - **背面（d1）**：包体（该行不透明像素 ≥4 的第一行）**顶边 = y10、底边 = y21**（上游 syndicate / magnate 就是 10→21，deepspace 10→22），细天线允许冒到 y9 以上。早前一版包体落在 y14..25 被判定"几乎不在背上"。
  - **侧面（d2/d3）**：侧视素材矮（我们只有 10px，上游 12px），**不能按包体顶对齐** —— 顶对齐会把整包顶到肩线上（实测包体 10..15、中心 12.5，用户反馈"又太高了"）。正确判据是**垂直中心**：上游侧包中心 15.5（syndicate/magnate）/16.0（deepspace），我们取 **14..19、中心 16.5**（差 1px）即视觉正确。

| 目标状态（模块内 dmi） | 源素材 | 落点处理 |
| --- | --- | --- |
| `mod_clothing.dmi`：`uar_marine-control` | 模块服关机.png | 原样 |
| `mod_clothing.dmi`：`uar_marine-control-sealed`（**3 帧，0.5 秒/帧循环**） | 模块服动画1/2/3.png | 原样，帧序 1→2→3 |
| `mod_clothing.dmi`：`uar_marine-helmet` / `-helmet-sealed` | 头盔关机.png / 头盔启动.png | 原样 |
| `mod_clothing.dmi`：`uar_marine-chestplate` / `-chestplate-sealed` | 国家模块服胸部.png | 原样（**物品态胸甲没有单独素材**，按需求方要求用穿戴态正面图充当） |
| `mod_clothing.dmi`：`uar_marine-gauntlets` / `-gauntlets-sealed` | 穿戴手.png | 原样 |
| `mod_clothing.dmi`：`uar_marine-boots` / `-boots-sealed` | 穿戴足.png | 原样 |
| `mod_clothing_worn.dmi`：`uar_marine-control`（d0/d1/d2/d3） | 国家模块服关机.png / 模块服关机侧面.png / 模块服侧面关机2.png | d0 由 d1 的 y8-10 裁剪派生（正面只露肩线上方）；**d1 0x−2y**（包体顶对齐 y10）；**d2 −6x−1y；d3 +6x−1y**（侧视素材矮，按垂直中心对齐，见「对齐判据」） |
| `mod_clothing_worn.dmi`：`uar_marine-control-sealed`（d0-d3） | 国家模块服.png / 模块服开机侧面.png / 模块服侧面开机2.png | 同上（密封态 = 点亮的背包） |
| `mod_clothing_worn.dmi`：`uar_marine-helmet`（d0-d3） | 关机头正面 / 国家模块服背头 / 关机头侧面2 / 侧面关机头 | 各 **0x−10y** |
| `mod_clothing_worn.dmi`：`uar_marine-helmet-sealed`（d0-d3） | 国家模块服头盔 / 国家模块服背头 / 团结联盟侧面头盔 / 国家模块服侧面2 | 各 **0x−10y**（背头图两态共用） |
| `mod_clothing_worn.dmi`：`uar_marine-helmet-visor`（d0-d3） | 由密封态头盔图的面罩色带提取 | 上游该状态只给狂欢/等离子模块当发光模板，d1 为空与上游一致 |
| `mod_clothing_worn.dmi`：`uar_marine-chestplate`(`-sealed`) | 国家模块服胸部 / 背面 / 侧面胸部 / 胸侧面2 | −1x+3y；0+3y；0+3y；0+3y |
| `mod_clothing_worn.dmi`：`uar_marine-gauntlets`(`-sealed`) | 国家模块服手部 / 背手 / 手侧面 / 手侧面2 | **0x+4y；0x+4y；−2x+4y；+3x+4y**（成对中心对齐人体中心 x=15.0） |
| `mod_clothing_worn.dmi`：`uar_marine-boots`(`-sealed`) | 国家模块服足部 / 背足 / 侧面足部 / 足侧面2 | 0+14y；0+14y；+1x+14y；0+14y |
| `card.dmi`：`card_uar` | 团结联盟武装部ID.png | 原样 |
| `card.dmi`：`trim_uar` | 团结联盟海军陆战队.png（骷髅） | **−5x0y**：原图偏右会压到卡框；落点 **(8,12)-(13,19)** —— 与上游同尺寸（5×7）徽记 `trim_blueshield` **逐像素同槽**。注意上游小徽记是在 9×9 槽 `(6,11)-(15,20)` 里**居中**摆放（`trim_customs` 等同类），不是左上角对齐 |
| `card.dmi`：`department` / `departmenthead` / `subdepartment` | 上游 `icons/obj/card.dmi` | 逐像素相同的通用色块；因为 `trim_icon` 指向本模块文件，这三块必须同文件 |
| `card.dmi`：`assigned_uar` | — | 空帧（与上游 solfed 卡同做法：卡面已含全部设计，不叠「已登记」涂鸦） |
| `hud.dmi`：`huduar` | 团结联盟海军陆战队HUD.png | **−12x−4y**：全仓 85 个 secHUD 图标都落在 (0,8)，原图居中会与所有图标错位 |
| `sound/uar_marine_start.ogg` | 启动.ogg | 换 ASCII 文件名（中文名进 DM 资源路径不稳妥） |

贴图里的 `uar_marine-helmet` / `-helmet-sealed` 两套素材对应需求方的「关机头*」与「国家模块服头盔/团结联盟侧面头盔」；背头图只有一张，两态共用（正面三向才是区分点）。`control` 与 `control-sealed` 的关机/开机图按素材点亮的差异区分（关机图 cyan/orange 像素为 0）。

### 核心文件 / Proc 改动：

- `code/modules/mod/mod_activation.dm`：1 行 `TIANGUAN EDIT CHANGE`
  - 原：`wearer.playsound_local(get_turf(src), 'sound/vehicles/mecha/nominal.ogg', 50)`
  - 现：`wearer.playsound_local(get_turf(src), activation_sound || 'sound/vehicles/mecha/nominal.ogg', 50)`
  - **为什么不能模块化**：上游在激活流程里直接写死 `playsound`，既没有 proc 可 override 的平台（`/obj/item/mod/control` 的 `Initialize()` 已被核心与 `mod_link.dm` 定义，挂不上），也没有对应的信号（`COMSIG_MOD_TOGGLED` 在 `nominal.ogg` 之后才发出，用它只能"跟着再响一声"而不是替换）。`activation_sound` 这个 var 本身是本模块新增的（**加 var 不需要动核心文件**），所以核心足迹就是这一行。
  - 同步上游时注意：冲突时保留 `activation_sound ||` 前缀即可；若上游哪天自己加了启动音效 var，按标记块合并。
- `code/modules/clothing/chameleon/chameleon_action_subtypes.dm`：2 行 `TIANGUAN EDIT ADD`（让**特工卡**能伪装成团结联盟武装部卡）
  - `/datum/action/item_action/chameleon/change/id/initialize_disguises()` 末尾加 `add_chameleon_items(/obj/item/card/id/advanced/uar_marine, only_root = TRUE)`
  - `/datum/action/item_action/chameleon/change/id_trim/initialize_disguises()` 的候选白名单里加 `/datum/id_trim/uar_marine`
  - **为什么不能模块化**：特工卡的外观候选是上游**硬编码的白名单**（不是 `subtypesof` 自动收集）；`initialize_disguises()` 已经被上游定义（同类型再定义 = duplicate definition），而动作实例是 `/obj/item/Initialize` 里 `INVOKE_ASYNC(..., add_item_action)` **异步**创建的，所以也不能在我们的模块里派生/挂钩去补。
  - **安全影响**：伪装只复制**外观**——`_chameleon_action.dm` 的 `update_item()` 只搬 name/desc/icon/icon_state/worn 图标，`SSid_access.apply_trim_override()` 只写 `trim_icon_override` / `trim_state_override` / `sechud_icon_state_override` / 部门配色这些展示字段，**不碰 `access`**。所以"用特工卡伪装成这张卡"不会白送全权限。

### 模块化覆盖：

- 无（未改 `code/`、`modular_nova/` 任何文件；主题靠 `valid_subtypesof(/datum/mod_theme)` 自动注册，贴图靠 `variants` 里的 `MOD_ICON_OVERRIDE` / `MOD_WORN_ICON_OVERRIDE` / `MOD_DIGITIGRADE_ICON_OVERRIDE` / `MOD_SNOUT_ICON_OVERRIDE`）

### Defines：

- 8 个单文件 define（图标路径 ×4、音效路径、`SECHUD_UAR`、两个配色），文件末尾全部 `#undef`。

### 本模块目录外的依赖文件：

- `tgstation.dme` —— 一行 `#include "modular_tianguan\modules\uar_marine_modsuit\code\uar_marine_modsuit.dm"`

### 构建 / 测试方式：

- **DreamMaker 编译实测**（`DM compiler version 516.1685`）：
  ```text
  loading _uar_check.dme
  code\_compile_options.dm:200:warning: #warn Building with Dream Maker is no longer supported and will result in errors.
  code\_compile_options.dm:201:warning: #warn In order to build, run BUILD.cmd in the root directory.
  code\_compile_options.dm:202:warning: #warn Consider switching to VSCode editor instead, where you can press Ctrl+Shift+B to build.
  loading interface/skin.dmf
  loading _maps/map_files/generic/CentCom.dmm
  saving _uar_check.dmb (DEBUG mode)
  _uar_check.dmb - 0 errors, 3 warnings
  Total time: 1:26
  ```
  3 条 warning 全是 `code/_compile_options.dm` 里既有的「别用 DreamMaker 编译」提示，与本次改动无关；**0 errors**。
- **为什么用临时 `_uar_check.dme` 编**：本机 `tgstation.rsc` 被正在跑的 DreamDaemon（1337 私服）占着，直接编 `tgstation.dme` 会撞上
  `BUG: The file ...\tgstation.rsc is locked up!`，并连带把**所有资源**报成 `cannot find file`（连树里真实存在的 `icons/obj/fluff/map_previews.dmi` 也报），那种输出不是代码问题。
  把 `tgstation.dme` 复制成 `_uar_check.dme` 再编，产物是 `_uar_check.dmb/.rsc`，既不动正在服务的 `tgstation.*`，又能拿到真实错误表。核对完删掉临时三件套即可。
- **贴图自检**：四个 dmi 用脚本回读（cell 32×32、状态数/朝向数/帧数/包围盒逐条断言）：
  - obj 10 状态 12 帧；worn 11 状态 44 帧（每状态 4 朝向）；card 6 状态；hud 1 状态；
  - 关键包围盒与上游同槽位一致：`uar_marine-chestplate` 穿戴态 `(6,10,25,29)`＝上游同槽位、`uar_marine-boots` 穿戴态 `(9,27,22,32)` ＝上游同槽位、`huduar` `(0,8,8,16)` ＝全仓 85 个 secHUD 图标的统一槽位；
  - 单独用一个只引用这四个 dmi + 音效的最小工程编译 → `0 errors, 0 warnings`（排除资源本身有问题）。
- **游戏内自检清单**（停掉旧服重新编译后，管理员刷一套 `/obj/item/mod/control/pre_equipped/uar_marine`）：
  1. 四部件（头盔/胸甲/手套/靴子）物品图标正常，不是空白或错图；
  2. 穿全套后四个朝向都正常：正面头盔在头顶、靴子在脚底；背面能看见背包；左右侧面背包在身侧；
  3. 启动：动作 `Activate` 完成后应播放 `uar_marine_start.ogg`（不再播放核心默认的 mecha nominal）；密封/未密封切换时头盔、背包（关机→点亮）四朝向都对；
  4. 物品态背包（丢地上）三帧彩灯按 0.5 秒/帧循环闪烁；
  5. ID 卡：`card_uar` 卡面 + 骷髅徽记落在卡面左侧面板内、部门色块为卡面红、副部门条为蓝；
  6. 戴安全目镜（secHUD）看该 ID 的持有者：应显示 `huduar` 红底 UAR 图标，且与其它职业图标位置一致。

### 维护备注：

- **ID 卡权限**：已是全权限（见上「武装部 ID 卡」小节）。要收权限就在 `/datum/id_trim/uar_marine/New()` 里减，例如 `access -= list(ACCESS_CHANGE_IDS)`（改 ID 机权限）、`access -= list(ACCESS_CENT_SPECOPS)` 之类。
- **ID 卡还没有配发途径**：只做了「物品本身」（卡 + trim + secHUD + 全权限），没有接任何 outfit / ERT 出动表 / 雇主配装。
  后续要接的时候：把 `/obj/item/mod/control/pre_equipped/uar_marine` 与 `/obj/item/card/id/advanced/uar_marine` 塞进对应 outfit 的 `back` / `id` 槽即可。
- **非人类种族**：本主题没有另外画蜥蜴人（digitigrade）/兽吻（snouted）变体，`MOD_DIGITIGRADE_ICON_OVERRIDE` / `MOD_SNOUT_ICON_OVERRIDE` 指向同一份人类穿戴图 —— 宁可腿型和人类一致，也好过部件整片不可见。以后要单独画，另建 `mod_clothing_mutant.dmi` 并把这两行指过去。
- **物品态胸甲**、**头盔背向的密封态**、**物品态手套/靴子的密封态**都是复用同一张素材（需求方没给对应素材），游戏内这两态的差别本来也很小；有素材后按上表替换即可。
- 素材落点规则见上表：**穿戴态素材必须按槽位对齐**，不要直接按原图坐标放；判据见上面「对齐判据」小节。
- **手套素材每只比上游宽 1px**（5px vs 上游 4px），所以只能做到"成对中心对齐 x=15"，左右各外露 1px（占 x6..24，上游是 7..23）。要完全贴合手臂列得重画或裁窄素材。
- **「厚重」tag 核实结论（2026-09）**：游戏里**没有**叫「厚重」的独立 tag。模块服上看到的 **「笨重」是重量级 tag**：`items.dm:441` `parent_tags.Insert(1, weight_class_to_text(w_class))`，`/obj/item/mod/control` 的 `w_class = WEIGHT_CLASS_BULKY` → "bulky"，自动显示、不是可配置项。而 **「厚实的」/thick 是衣物 tag**：`clothing.dm:371` `if(clothing_flags & THICKMATERIAL)` → `.["thick"]`（中文名见 `strings/i18n/zh-Hans/_examine_tags.json` 的 `tag_thick`）。本主题**头盔（密封态）+ 胸甲/手套/靴（非密封态）已经带 `THICKMATERIAL`**，与死亡小队秘典逐行同写法 ⇒ **不用再加**。若希望**密封态的胸甲/手套/靴也显示「厚实的」**（上游密封态只剩「抗压的」），把对应的 `SEALED_CLOTHING` 改成 `THICKMATERIAL|STOPSPRESSUREDAMAGE` 即可。
- 上游新增 `mod_theme` 变量/proc 时的落点：主题子类型只 override 数据，不重定义 proc；若上游给 `/obj/item/mod/control` 加了 `activation_sound` 同名 var，改成复用上游那个。

### 致谢：

- mohu19（美术素材 + 需求）
