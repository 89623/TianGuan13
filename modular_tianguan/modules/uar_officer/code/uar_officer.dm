/**
 * 团结联盟审查官服饰与装备（UAR_OFFICER）
 *
 * 内容：制服 / 公务员帽 / 礼仪手套 / 祖国靴 / 两个战术耳机（普通 + 防闪 bowman）/
 *       行政ID 卡 + 审查官卡面徽记 + secHUD 图标 / 两面旗帜（墙上态 + 折叠态 + 货舱订购）。
 *
 * 三种「零核心改动」的挂法（依据 modular_tianguan/readme.md）：
 *   ① 新类型：衣物 / 耳机 / ID卡 / trim / 旗帜 / 补给包 —— 全是新子类型，定义即生效；
 *   ② 重声明既有类型上的**变量**：`/datum/outfit/job/uar_inspector` 与
 *      `/obj/machinery/wardrobe/cent_wardrobe` 的 products —— DM 里同类型同 var 的跨文件重复赋值合法、
 *      后 include 者生效（脚本在 tgstation.dme 里排在 modular_nova / modular_tianguan 各模块之后）。
 *   ③ 本模块不碰 code/ 与 modular_nova/ 下任何文件。
 *
 * 贴图落点/朝向的每一次修正（含两处素材改绘）都记在 readme.md，改回去前先读那一节。
 */

// ———————————————————————————————— 贴图资源
// ⚠️ 每个 dmi 必须写**完整字面量**：DM 里 `'dir/' + "file.dmi"` 不是常量表达式（编译期报 invalid expression）。
#define UAR_OBJ_ICON     'modular_tianguan/modules/uar_officer/icons/uar_clothing_obj.dmi'
#define UAR_WORN_ICON    'modular_tianguan/modules/uar_officer/icons/uar_worn.dmi'
#define UAR_CARD_ICON    'modular_tianguan/modules/uar_officer/icons/uar_card.dmi'
#define UAR_HUD_ICON     'modular_tianguan/modules/uar_officer/icons/uar_hud.dmi'
#define UAR_FLAG_ICON    'modular_tianguan/modules/uar_officer/icons/uar_flags.dmi'

// ———————————————————————————————— 护甲档位
// 「激光 / 实弹 / 爆炸 = 三级防护」：护甲读数里的等级 = 数值/10 的罗马数字
// （code/datums/armor/_armor.dm: armor_to_protection_class()），所以三级 = 30。
#define UAR_TIER3_ARMOR /datum/armor/uar_tier3
/datum/armor/uar_tier3
	bullet = 30
	laser = 30
	bomb = 30

// ———————————————————————————————— 制服（防火防酸）
/obj/item/clothing/under/uar_uniform
	name = "团结联盟行政装"
	desc = "标准太空公务员装扮，只为人类设计的款式。"
	icon = UAR_OBJ_ICON
	icon_state = "uar_uniform"
	worn_icon = UAR_WORN_ICON
	// ⚠️ 不要写 worn_icon_state：本 fork 的 update_worn_undersuit() 用
	//   `target_overlay = uniform.icon_state` 顶掉状态名（human_update_icons.dm:84,144），
	//   穿戴 dmi 里的状态必须与 icon_state **同名**。上游所有服装都是这个约定。
	// 女性形变：基类 /obj/item/clothing/under 默认 FEMALE_UNIFORM_FULL（上下半身都按女性形变），
	//   我们的裤子会被引擎改形，导致女性小人胯/臀处多露出几个像素。上游连体服（under/color.dm:23）
	//   用的是 FEMALE_UNIFORM_TOP_ONLY —— 只做上半身，下半身原样保留，照它对齐。
	female_sprite_flags = FEMALE_UNIFORM_TOP_ONLY
	resistance_flags = FIRE_PROOF | ACID_PROOF

// ———————————————————————————————— 公务员帽
/obj/item/clothing/head/uar_cap
	name = "团结联盟公务员帽"
	desc = "是你曾在军中服役的最好证明，国家允许你保留的军帽。下士的军徽在岁月的侵蚀下略有掉色。"
	icon = UAR_OBJ_ICON
	icon_state = "uar_hat"
	worn_icon = UAR_WORN_ICON
	armor_type = UAR_TIER3_ARMOR

// ———————————————————————————————— 礼仪手套
/obj/item/clothing/gloves/uar_gloves
	name = "行政手套"
	desc = "国家配发的礼仪手套，在工作中表现的更绅士。"
	icon = UAR_OBJ_ICON
	icon_state = "uar_gloves"
	worn_icon = UAR_WORN_ICON
	armor_type = UAR_TIER3_ARMOR
	cold_protection = HANDS
	min_cold_protection_temperature = GLOVES_MIN_TEMP_PROTECT
	heat_protection = HANDS
	max_heat_protection_temperature = GLOVES_MAX_TEMP_PROTECT

// ———————————————————————————————— 祖国靴
/obj/item/clothing/shoes/uar_boots
	name = "祖国靴"
	desc = "国家配发的制式军靴，鞋跟敲在地板上像在阅兵。"
	icon = UAR_OBJ_ICON
	icon_state = "uar_boots"
	worn_icon = UAR_WORN_ICON
	armor_type = UAR_TIER3_ARMOR
	fastening_type = SHOES_SLIPON
	body_parts_covered = FEET | LEGS

// ———————————————————————————————— 耳机 ×2（代码结构照抄纳米传讯顾问那两只）
/obj/item/radio/headset/heads/uar_inspector
	name = "团结联盟战术耳机"
	desc = "团结联盟配发的战术通讯耳机，频道与纳米传讯顾问同级。"
	icon = UAR_OBJ_ICON
	icon_state = "uar_headset"
	worn_icon = UAR_WORN_ICON
	// ⚠️ 耳机**必须**显式写 worn_icon_state：基类 /obj/item/radio/headset 自带
	//   `worn_icon_state = "headset"`（code/game/objects/items/devices/radio/headset.dm:33），
	//   不写就会继承它、去穿戴 dmi 里找 "headset"（不存在）⇒ 小人身上一片空白。
	//   上游自定义耳机（cent_headset_alt）同样是 icon_state 与 worn_icon_state 同名双写。
	worn_icon_state = "uar_headset"
	keyslot = new /obj/item/encryptionkey/headset_com
	keyslot2 = new /obj/item/encryptionkey/headset_cent/ccrep

/obj/item/radio/headset/heads/uar_inspector/alt
	name = "团结联盟战术耳机（防闪）"
	desc = "团结联盟配发的战术通讯耳机，耳罩能挡住闪光弹。"
	icon_state = "uar_headset"

/obj/item/radio/headset/heads/uar_inspector/alt/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/wearertargeting/earprotection, list(ITEM_SLOT_EARS))

// ———————————————————————————————— 行政PDA（深红涂装）
// 与纳米传讯顾问的 PDA 同一套做法：**不画专属贴图**，走本 fork 的灰度着色系统
// （/obj/item/modular_computer/pda 自带 `greyscale_config = /datum/greyscale_config/tablet`；
//   各职业 PDA 只改 `greyscale_colors`。基类默认 "#999875#a92323" = 米灰机身 + 红按键）。
/obj/item/modular_computer/pda/uar_inspector
	name = "团结联盟审查官PDA"
	desc = "团结联盟配发的行政助理机，深红色涂装，背面压着联盟的星徽。"
	greyscale_config = /datum/greyscale_config/tablet
	greyscale_colors = "#8b0000#3a0a0a"
	inserted_disk = /obj/item/disk/computer/command/captain
	inserted_item = /obj/item/pen/red

// ———————————————————————————————— ID 卡 + 卡面徽记 + secHUD
/obj/item/card/id/advanced/uar_admin
	name = "行政ID"
	desc = "UAR政府配备的标准行政ID卡。"
	icon = UAR_CARD_ICON
	icon_state = "card_uar_admin"
	assigned_icon_state = "assigned_uar_admin"
	trim = /datum/id_trim/job/uar_inspector

/datum/id_trim/job/uar_inspector
	assignment = JOB_UAR_INSPECTOR
	trim_icon = UAR_CARD_ICON
	trim_state = "trim_uar_inspector"
	department_color = UAR_DEPARTMENT_COLOR
	subdepartment_color = "#1f3a8a"
	sechud_icon = UAR_HUD_ICON
	sechud_icon_state = "huduar_inspector"
	job = /datum/job/uar_inspector

/// 权限对齐纳米传讯顾问（NTC）：不写死清单，运行期把 NTC trim 的 access 整份抄过来。
/// 找不到就**响亮**地在启动日志里报出来（而不是静默给一张空卡）。
/datum/id_trim/job/uar_inspector/New()
	. = ..()
	var/datum/job/ntc = SSjob.get_job_type(/datum/job/nanotrasen_consultant)
	if(!ntc)
		log_world("UAR_OFFICER: ⚠ 找不到 /datum/job/nanotrasen_consultant，行政ID 未套用 NTC 权限")
		return
	for(var/trim_path in SSid_access.trim_singletons_by_path)
		var/datum/id_trim/any_trim = SSid_access.trim_singletons_by_path[trim_path]
		if(!istype(any_trim, /datum/id_trim/job))   // job 这个 var 只在 /datum/id_trim/job 上有，先判类型
			continue
		var/datum/id_trim/job/trims = any_trim
		if(trims.job == ntc)
			access = trims.access.Copy()
			wildcard_access = trims.wildcard_access.Copy()
			log_world("UAR_OFFICER: 行政ID 已套用 NTC 权限（[length(access)] 条 access / [length(wildcard_access)] 条 wildcard）")
			return
	log_world("UAR_OFFICER: ⚠ 没找到 NTC 的 id_trim 单例，行政ID 未套用 NTC 权限")

// ———————————————————————————————— 两面旗帜（结构态 + 可携带折叠态）
/obj/structure/sign/flag/uar
	name = "团结联盟共和国国旗"
	desc = "团结联盟共和国的国旗。深红底、金黄镶边，中央是联盟的蓝星徽记。"
	icon = UAR_FLAG_ICON
	icon_state = "flag_uar"
	item_flag = /obj/item/sign/flag/uar

/obj/item/sign/flag/uar
	name = "折叠的团结联盟共和国国旗"
	desc = "叠好的团结联盟共和国国旗，插到墙上就会展开。"
	icon = UAR_FLAG_ICON
	icon_state = "folded_uar"
	sign_path = /obj/structure/sign/flag/uar

/obj/structure/sign/flag/wsr
	name = "世界社会主义共和国国旗"
	desc = "世界社会主义共和国的国旗。"
	icon = UAR_FLAG_ICON
	icon_state = "flag_wsr"
	item_flag = /obj/item/sign/flag/wsr

/obj/item/sign/flag/wsr
	name = "折叠的世界社会主义共和国国旗"
	desc = "叠好的世界社会主义共和国国旗，插到墙上就会展开。"
	icon = UAR_FLAG_ICON
	icon_state = "folded_wsr"
	sign_path = /obj/structure/sign/flag/wsr

// ———————————————————————————————— 货舱订购（与现有旗帜同组：companies/general）
/datum/supply_pack/companies/general/uar_flag
	name = "团结联盟共和国国旗"
	contains = list(/obj/item/sign/flag/uar)
	cost = CARGO_CRATE_VALUE * 0.2

/datum/supply_pack/companies/general/wsr_flag
	name = "世界社会主义共和国国旗"
	contains = list(/obj/item/sign/flag/wsr)
	cost = CARGO_CRATE_VALUE * 0.2

// ———————————————————————————————— 职业套装（重声明变量：后 include 者生效）
/// 上一批 uar_department 里已经建过 /datum/outfit/job/uar_inspector（那一版是临时的黑西装），
/// 这里同类型重声明变量 → 本模块生效（模块 include 排在 uar_department 之后）。
/datum/outfit/job/uar_inspector
	name = JOB_UAR_INSPECTOR
	jobtype = /datum/job/uar_inspector

	id = /obj/item/card/id/advanced/uar_admin
	id_trim = /datum/id_trim/job/uar_inspector
	uniform = /obj/item/clothing/under/uar_uniform
	head = /obj/item/clothing/head/uar_cap
	gloves = /obj/item/clothing/gloves/uar_gloves
	shoes = /obj/item/clothing/shoes/uar_boots
	ears = /obj/item/radio/headset/heads/uar_inspector
	belt = /obj/item/modular_computer/pda/uar_inspector
	// 开局只带 **UAR 国旗**（用户 09-30 明确规格：审查官只携带 uar 国旗）；
	// WSR 国旗不进开局携带，只能走货舱订购。
	backpack_contents = list(
		/obj/item/sign/flag/uar = 1,
		/obj/item/choice_beacon/uar = 1,
	)

/// 诊断：每次有人以这个职业 spawn，都把**实际**穿/带的东西打进 runtime.log。
/// visualsOnly（大厅/偏好页的角色预览）不打日志：那种调用本来就不放背包内容，打出来只是噪声。
/datum/outfit/job/uar_inspector/post_equip(mob/living/carbon/human/H, visualsOnly)
	. = ..()
	if(visualsOnly)
		return
	var/list/slots = list(
		"制服" = H.w_uniform, "帽" = H.head, "手套" = H.gloves, "靴" = H.shoes,
		"耳机" = H.ears, "背包" = H.back,
	)
	var/list/desc = list()
	for(var/k in slots)
		var/obj/item/I = slots[k]
		desc += "[k]=[isnull(I) ? "NULL" : "[I.type]"]"
	log_world("UAR_OFFICER: spawn 实装 → [desc.Join(" | ")]")
	if(!isnull(H.back))
		var/list/inbag = list()
		for(var/obj/item/I in H.back.contents)
			inbag += "[I.type]"
		log_world("UAR_OFFICER: 背包实装 [length(inbag)] 件 → [inbag.Join(" / ")]")

// ———————————————————————————————— 指挥售货机（重声明 products：整表覆盖，含上游原 16 条）
/obj/machinery/vending/wardrobe/cent_wardrobe
	products = list(
		/obj/item/clothing/glasses/sunglasses = 3,
		/obj/item/clothing/head/hats/centcom_cap = 3,
		/obj/item/clothing/head/hats/centhat = 3,
		/obj/item/clothing/head/hats/intern = 3,
		/obj/item/clothing/under/rank/centcom/commander = 3,
		/obj/item/clothing/under/rank/centcom/centcom_skirt = 3,
		/obj/item/clothing/under/rank/centcom/intern = 3,
		/obj/item/clothing/under/rank/centcom/official = 3,
		/obj/item/clothing/under/rank/centcom/officer = 3,
		/obj/item/clothing/under/rank/centcom/officer_skirt = 3,
		/obj/item/clothing/suit/armor/centcom_formal = 3,
		/obj/item/clothing/suit/space/officer = 3,
		/obj/item/clothing/suit/hooded/wintercoat/centcom = 3,
		/obj/item/clothing/shoes/laceup = 3,
		/obj/item/clothing/shoes/jackboots = 3,
		/obj/item/clothing/gloves/combat = 3,
		// TIANGUAN EDIT ADDITION - UAR_OFFICER：团结联盟那套（制服防火防酸）
		/obj/item/clothing/under/uar_uniform = 3,
		/obj/item/clothing/head/uar_cap = 3,
		/obj/item/clothing/gloves/uar_gloves = 3,
		/obj/item/clothing/shoes/uar_boots = 3,
	)

// ———————————————————————————————— 启动自检（把静默失败变成日志里的一行）
/world/New()
	. = ..()
	if(!isnull(SSjob.get_job_type(/datum/job/uar_inspector)))
		var/datum/outfit/job/uar_inspector/o = new
		log_world("UAR_OFFICER: 自检 制服=[o.uniform] 帽=[o.head] 手套=[o.gloves] 靴=[o.shoes] 耳机=[o.ears] 卡=[o.id]")
	else
		log_world("UAR_OFFICER: ⚠ 找不到 /datum/job/uar_inspector（uar_department 模块没加载？）")

// ———————————————————————————————— 武器召唤信标（照纳米传讯顾问的 choice_beacon 同款改名）
// 结构照抄 NTC：信标本体只管"改名 + 换图标 + 换公司文案"；选项表由 generate_display_names() 给出，
// 菜单与空投由基类 /obj/item/choice_beacon 负责（code/game/objects/items/choice_beacon.dm）。
// 选项内容物按**读源码得到的真实 typepath**装（上游 Skild/Takbok 枪组用的就是这几样，
// 见 modular_nova/modules/modular_weapons/code/company_and_or_faction_based/trappiste_fabriek/gunsets.dm）：
//   .585 手枪   = /obj/item/gun/ballistic/automatic/pistol/trappiste/no_mag（无弹夹出厂）
//   其弹夹      = /obj/item/ammo_box/magazine/c585trappiste_pistol
//   左轮        = /obj/item/gun/ballistic/revolver/takbok
//   快速换弹器  = /obj/item/ammo_box/speedloader/c585trappiste
//   散装备弹    = /obj/item/ammo_box/c585trappiste
// 箱子容量：/datum/storage/toolbox/guncase/nova = 14 格重 / 6 槽 ⇒ 5 件、4 件都装得下。

/obj/item/storage/toolbox/guncase/nova/pistol/trappiste_small_case/uar_double_pistol
	name = "团结联盟 585 手枪双持组"
	desc = "一只贴着团结联盟封条的小枪箱：两把 .585 Trappiste 手枪、两个备用弹夹与一盒散装弹药。"

/obj/item/storage/toolbox/guncase/nova/pistol/trappiste_small_case/uar_double_pistol/PopulateContents()
	..()
	for(var/i in 1 to 2)
		new /obj/item/gun/ballistic/automatic/pistol/trappiste/no_mag(src)
		new /obj/item/ammo_box/magazine/c585trappiste_pistol(src)
	new /obj/item/ammo_box/c585trappiste(src)

/obj/item/storage/toolbox/guncase/nova/pistol/trappiste_small_case/uar_revolver
	name = "团结联盟 左轮手枪组"
	desc = "一只贴着团结联盟封条的小枪箱：一把 Takbok 左轮、两个快速换弹器与一盒散装弹药。"

/obj/item/storage/toolbox/guncase/nova/pistol/trappiste_small_case/uar_revolver/PopulateContents()
	..()
	new /obj/item/gun/ballistic/revolver/takbok(src)
	for(var/i in 1 to 2)
		new /obj/item/ammo_box/speedloader/c585trappiste(src)
	new /obj/item/ammo_box/c585trappiste(src)

/obj/item/choice_beacon/uar
	name = "团结联盟武器信标"
	desc = "一次性信标，用来申请一套武器。请在办公室内使用。"
	icon = 'modular_nova/modules/modular_items/icons/remote.dmi'
	icon_state = "cc_beacon"
	inhand_icon_state = "cc_beacon"
	lefthand_file = 'modular_nova/modules/modular_items/icons/inhand/mobs/lefthand_remote.dmi'
	righthand_file = 'modular_nova/modules/modular_items/icons/inhand/mobs/righthand_remote.dmi'
	company_source = "团结联盟"
	company_message = span_bold("补给舱正在降落，请远离落点。")

/obj/item/choice_beacon/uar/generate_display_names()
	var/static/list/selectable_gun_types = list(
		"两把 585 手枪 + 两个弹夹 + 备弹" = /obj/item/storage/toolbox/guncase/nova/pistol/trappiste_small_case/uar_double_pistol,
		"一把左轮 + 两个快速换弹器 + 备弹" = /obj/item/storage/toolbox/guncase/nova/pistol/trappiste_small_case/uar_revolver,
	)
	return selectable_gun_types
