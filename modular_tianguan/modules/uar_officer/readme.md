# UAR_OFFICER — 团结联盟审查官服饰与装备

模块 ID：`UAR_OFFICER`　｜　目录：`modular_tianguan/modules/uar_officer/`
配套模块：`uar_department`（部门「团结联盟」+ 职业「团结联盟审查官」本体的注册在那里）

给团结联盟审查官配齐一整套：制服 / 公务员帽 / 行政手套 / 祖国靴 / 两个战术耳机 /
行政ID 卡（卡面 + 审查官徽记 + secHUD 图标）/ 两面旗帜（墙上态 + 折叠态 + 货舱订购）。
制服**防火防酸**；帽 / 手套 / 靴 **激光·实弹·爆炸三级防护**（护甲读数 `30`，等级 = 数值/10 的罗马数字）。

## 一、三种「零核心改动」的挂法

| 手法 | 用在哪 | 说明 |
|---|---|---|
| ① 新子类型 | 全部衣物 / 两个耳机 / ID卡 / id_trim / 两面旗帜 / 两条货舱补给包 | 定义即生效；补给包由 `code/controllers/subsystem/shuttle.dm:162` 的 `subtypesof(/datum/supply_pack)` 自动收录 |
| ② 重声明既有类型的**变量** | `/datum/outfit/job/uar_inspector`（职业套装）、`/obj/machinery/vending/wardrobe/cent_wardrobe`（`products`） | DM 允许同类型同 var 跨文件重复赋值，**后 include 者生效**；本模块在 `tgstation.dme` 里排在 `uar_department` 之后 |
| ③ 完全不碰 | `code/**`、`modular_nova/**` | 本模块只新增自己的文件 + `tgstation.dme` 一行 include |

> ⚠️ 手法② 里 `products` 是**整表覆盖**：改这里必须连带把上游原有 16 条一起写上，否则指挥售货机会少货。
> ⚠️ dmi 路径必须写**完整字面量**（`'dir/file.dmi'`）：DM 里 `'dir/' + "file.dmi"` 不是常量表达式，编译期直接报 `invalid expression`。

## 二、物件与贴图落点

`icons/uar_clothing_obj.dmi`（物品图标）/ `uar_clothing_worn.dmi`（穿戴态，5 状态 × 4 朝向）：

⚠️ **穿戴 dmi 的状态名必须与物件的 `icon_state` 同名**（`uar_uniform` / `uar_hat` / `uar_gloves` / `uar_boots` / `uar_headset`），
且**不要写 `worn_icon_state`**。原因（实测出的坑，2026-09-30）：本 fork 的 `update_worn_undersuit()` 里
`var/target_overlay = uniform.icon_state`，随后 `override_state = target_overlay` 传给 `build_worn_icon()`
（`code/modules/mob/living/carbon/human/human_update_icons.dm:84,144`）—— 制服槽位的状态名**只看 `icon_state`**；
其余槽位用 `worn_icon_state || icon_state`。两套口径只有在"状态名 == icon_state"时才同时成立，
否则会出现「物品栏能看到、小人身上空白」。

| 物件 | 类型路径 | 状态名 | 穿戴落点（d0/d1/d2/d3） |
|---|---|---|---|
| 团结联盟行政装 | `/obj/item/clothing/under/uar_uniform` | `uar_uniform` / `uar_uniform_worn` | (7,10,24,29) / (7,10,24,29) / (11,10,20,29) / (12,10,21,29) |
| 团结联盟公务员帽 | `/obj/item/clothing/head/uar_cap` | `uar_hat` / `uar_hat_worn` | (10,0,21,6) / (10,0,21,6) / (10,0,22,6) / (10,0,22,6) |
| 行政手套 | `/obj/item/clothing/gloves/uar_gloves` | `uar_gloves` / `uar_gloves_worn` | (7,18,24,22) / (7,18,24,22) / (12,18,21,22) / (11,18,20,22) |
| 祖国靴 | `/obj/item/clothing/shoes/uar_boots` | `uar_boots` / `uar_boots_worn` | (9,27,22,32) / (9,27,22,32) / (13,29,20,32) / (12,29,19,32) |
| 团结联盟战术耳机 | `/obj/item/radio/headset/heads/uar_inspector`（`/alt` = 防闪 bowman） | `uar_headset` / `uar_headset_worn` | (15,5,21,10) / (11,5,13,9) / (14,5,19,10) / (13,5,18,10) |

其余：`uar_card.dmi`（`card_uar_admin` / `assigned_uar_admin` / `trim_uar_inspector` + 上游样式三态）、
`uar_hud.dmi`（`huduar_inspector`，10×10 原图居中裁到 8×8 放 (0,8)）、
`uar_flags.dmi`（`flag_uar`/`folded_uar`/`flag_wsr`/`folded_wsr`）。

## 三、贴图对齐与素材改绘记录（**改回去前先读这一节**）

所有对齐的锚点都是**人体剪影**（`icons/mob/human/bodyparts_greyscale.dmi`）与上游同槽位服装，不是"看着差不多"：

1. **整体平移**：全部穿戴态素材是"各部件在画布内居中导出的"，需要搬到对应槽位（制服 +4y、帽 −13y、手套 +4y、靴子底边贴 y32）。
2. **正面/侧面用反**（2026-09-29 用户实测）：`团结联盟战术耳机正面.png` 与 `...侧面.png` 的文件名与实际朝向不符 ——
   横向长条那张才是**正面**（正面看到的是横跨面部的麦克风杆），小方块那张才是**侧面**。映射已对调。
3. **左右侧对调**（2026-09-29 用户实测）：d2/d3 两个侧向帧互换（镜差仍为 0）。
4. **耳机素材少画一行 → 已改绘**：`团结联盟战术耳机侧面.png` 原始 bbox `(12,14,19,18)` 只有 **4 行**，
   而另两张是 5 行（红点→麦克风距离 2 行 vs 3 行）⇒ 耳麦对齐了麦克风就差一格，**整帧平移无法同时对齐**。
   改绘方式：底部麦克风行下移 1px、中间用上一行接成连续的杆（只增不删、颜色全部取自素材自身像素）。
   改绘后该帧 5 行，红点与麦克风**同时**对齐（四朝向红点行统一为 y6）。
   **原始素材已备份**在 `Desktop/Hermes/projects/uar_officer/backup_素材原图/`（33 张，`cp -n` 生成，不会被覆盖）。
5. **侧视 1px 东西向错位**：上游与人体的侧视两帧本来就差 1px（`human_chest_m` d2=(11,10,20,23)/d3=(12,10,21,23)；
   双手并集 d2=x12..21/d3=x11..20）。我们原来两帧 bbox 相同 ⇒ 补上：制服 `d3 +1x`、手套 `d2 +1x`、靴子 `d2 +1x`。
   改后与上游逐项一致：制服 (11,10,20,29)/(12,10,21,29)、手套 (12,18,21,22)/(11,18,20,22) ✓
6. **帽子**核过**没有坏帧**：两对镜差都是 0，且该素材在画布里左右对称（10..22，中心 15.5），两个侧向帧 bbox 相同是正确的。

自检口径（每次重跑构建脚本都会打印）：**侧视镜差 `d2 vs mirror(d3)` 必须 = 0**（上游同槽也是 0）。

## 四、权限与 ID

`/datum/id_trim/job/uar_inspector` 的 `New()` 在运行期把纳米传讯顾问（NTC）trim 的**源字段**
（`minimal_access` / `extra_access` / 两个 `*_wildcard_access` / `template_access`）抄过来，
再调 `refresh_trim_access()` 让基类重算 —— 而不是写死一张清单，上游改 NTC 权限时这里自动跟随。

⚠️ **别只抄组合后的 `access`**：最终 access = `minimal_access`（`jobs_have_minimal_access` 为真时）
或 `minimal | extra_access`（为假时），**再叠加 `template_access` 的模板展开**（`SSid_access`，`id_access.dm:201-205`）。
NTC 的 `template_access = list(ACCESS_CAPTAIN, ACCESS_CHANGE_IDS)` —— **舰桥/指挥区的门就在这段模板里**，
早先只抄 `access` 时权限看着是"39 条"却打不开舰桥，就是漏了它。
启动日志会打印 `行政ID 已套用 NTC 权限（access N 条 / wildcard N 条 / 模板 N 项）` 便于核对。
找不到 NTC 就在启动日志里**响亮**报错（`UAR_OFFICER: ⚠ ...`），不会静默给一张空卡。
`world/New()` 里另有一条自检，把职业套装的六个槽位实际类型打进 `data/logs/**/runtime.log`。

## 五、旗帜与货舱

- `/obj/structure/sign/flag/uar` + `/obj/item/sign/flag/uar`（折叠态，插墙展开），WSR 同构；
- 审查官**开局只携带 UAR 国旗**（`backpack_contents` 里只有它；用户 09-30 明确规格）；
  WSR 国旗不进开局携带，只能走货舱订购；
- 货舱订购：`/datum/supply_pack/companies/general/uar_flag` 与 `.../wsr_flag`（与上游 `hc_flag` **同组**、同价 `CARGO_CRATE_VALUE * 0.2`）。

## 六、测试方式

1. 编译：`dm.exe` 编 `tgstation.dme`（私服在跑时 `tgstation.rsc` 被占，用副本 dme 编译）；
   ⚠️ **`.rsc` 必须与 `.dmb` 同一次成功编译产出**：编译失败的那次会留下 rsc、下次成功的编译只重写 dmb，
   结果是「服务端一切正常、玩家屏幕上新贴图全空」——客户端拿到的资源缓存和二进制对不上。
   症状与"客户端缓存过期"完全一样。修法：删掉 `.rsc`+`.dmb` 重新完整编译（rsc 会重建，耗时较长），
   或让玩家清 `%APPDATA%\BYOND\cache` 后重连。
2. 进服 → 开局加入菜单 / 角色设置→职业偏好页 → 选「团结联盟审查官」；
3. 该看的：身上那套是否穿对、ID卡卡面与徽记、secHUD 图标、指挥售货机（CentDrobe）里有没有那四件、
   货舱订购里有没有两面旗、护甲读数（帽/手套/靴 = 激光·实弹·爆炸三级）、制服防火防酸；
4. spawn 后 `runtime.log` 里会有一行 `UAR_OFFICER: spawn 实装 → …`（`post_equip` 打的），
   逐槽位印出**实际**穿的是哪个类型 —— 判断"没穿/穿错"时先看这行，别只看套装类型体。

## 七、无线电频道（UAR / `:ua`）

新频道**必须逐处登记**，缺任何一处都表现为「发出去谁也没收到」或「频道名退化成 `[136.1]`」：

| # | 位置 | 登记内容 |
|---|---|---|
| 1 | `code/__DEFINES/radio.dm` | `RADIO_CHANNEL_UAR` / `RADIO_KEY_UAR` / `RADIO_TOKEN_UAR` / `FREQ_UAR 1361` |
| 2 | `code/game/communications.dm` | `default_radio_channels`（频道 → 频率） |
| 3 | 同上 | `reserved_radio_frequencies`（频率 → 名字；漏了显示 `[136.1]`） |
| 4 | 同上 | `reserved_radio_colors`（名字 → 颜色；与 ③ 联动，名字缺了颜色也拿不到） |
| 5 | `code/modules/mob/living/living_say.dm` | `department_radio_keys`（`:ua` → 频道） |
| 6 | `code/game/objects/items/devices/radio/headset.dm` | `channel_tokens` |
| 7 | **电信接收机** `telecomms/machines/receiver.dm` | `freq_listening` —— **第一道闸门**，不在清单里信号根本进不了电信网 |
| 8 | **电信总线** `telecomms/machines/bus.dm` | `freq_listening`（UAR 与安保/指挥同挂 `preset_three`） |
| 9 | 通信服务器 `telecomms/machines/server.dm` | `freq_listening`（存档/日志） |
| 10 | `code/game/say.dm` | `freqtospan`（频率 → CSS 类，决定聊天栏与说窗配色） |

前端（`tgui/`）另有两处配套：`tgui-say/constants.ts` 的 `RADIO_PREFIXES`（`:ua ` → 左侧短标签）、
`tgui-say/styles/colors.scss` 的 `$channel-map`（短名 → 颜色，生成 `.window-<短名>` / `.button-<短名>` 等类）。

**两处「只认单字符前缀」的地雷**（前后端各一颗，两字符前缀会被吞掉或直接不识别）：
- 后端 `code/modules/mob/mob_say.dm` 的 `get_message_mods()`；
- 前端 `tgui/packages/tgui-say/helpers.ts` 的 `getPrefix()`（`CHANNEL_REGEX` + `slice(0, 3)`）。

两处都已改为**先试两字符、命中优先**；单字符频道（`:u` 补给、`:s` 安保、`:c` 指挥）不受影响。

**加密钥匙**：每把钥匙要**显式写全自己拥有的频道** —— 子类的 `channels` 会整体覆盖父类的表，
父类 `Initialize` 的兜底对子类无效（漏写就会出现「耳机有频道、钥匙没挂上」）。

**构建坑**：改了前端后须在 `tgui/` 跑 `bun run tgui:build`，**并删掉 `.rsc` 再编译 DM** ——
DM 编译器只按文件清单判断资源是否变化，bundle 内容变了它**不会**重写 `.rsc`，客户端会继续用旧前端。

## 八、待办（尚未落地）

- **团结联盟SOP手册**：计划加进现成的 `sop_book` 模块（`/obj/item/book/manual/wiki/sop/uar`，
  `direct_wiki_url` 指向团结联盟标准操作程序 wiki 页，图标加进该模块的 `sop_books.dmi`）。
- **辛迪莉亚玩偶**：`/obj/item/toy/plush` 子类，音效套默认玩偶那套，desc「一个猩红玩偶，有一种阴谋与邪恶」，
  并加进赞助者（`sponsor_loadout_items`）开局可携带。
