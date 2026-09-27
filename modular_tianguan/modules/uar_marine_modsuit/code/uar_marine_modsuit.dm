// UAR_MARINE_MODSUIT - 天关模块：团结联盟海军陆战队第四代模块服 + 团结联盟武装部 ID 卡
//
// 本模块提供三件东西：
//   1) /datum/mod_theme/uar_marine —— 新的模块服主题（第四代全环境防护服）
//   2) /obj/item/mod/control/pre_equipped/uar_marine —— 可直接刷出来的整套（含电池，不含模块）
//   3) /obj/item/card/id/advanced/uar_marine + /datum/id_trim/uar_marine —— 武装部 ID 卡
//      （卡底 + 骷髅徽记 + secHUD 图标，见 icons/card.dmi 与 icons/hud.dmi）
//
// 模块化说明：
//   · 主题是 /datum/mod_theme 的子类型，由 setup_mod_themes() 用 valid_subtypesof() 自动实例化
//     ⇒ 只写子类型即可，无需改任何核心文件。
//   · 贴图靠 variants 里该 skin 的 MOD_ICON_OVERRIDE / MOD_WORN_ICON_OVERRIDE 指向本模块 icons/
//     （上游 marines 主题也是这么做的，见 modular_nova/master_files/.../mod_theme.dm）。
//   · 启动音效是本模块唯一的核心改动：code/modules/mod/mod_activation.dm 里那个
//     wearer.playsound_local(get_turf(src), 'sound/vehicles/mecha/nominal.ogg', 50) 改成优先读
//     activation_sound（本文件声明的 var）。上游没有可挂的信号/proc 落点，理由见模块 readme.md。

#define UAR_MARINE_MODSUIT_ICON 'modular_tianguan/modules/uar_marine_modsuit/icons/mod_clothing.dmi'
#define UAR_MARINE_MODSUIT_WORN_ICON 'modular_tianguan/modules/uar_marine_modsuit/icons/mod_clothing_worn.dmi'
#define UAR_MARINE_MODSUIT_CARD_ICON 'modular_tianguan/modules/uar_marine_modsuit/icons/card.dmi'
#define UAR_MARINE_MODSUIT_HUD_ICON 'modular_tianguan/modules/uar_marine_modsuit/icons/hud.dmi'
/// 启动音效（用户提供的 启动.ogg，入模块后改成 ASCII 文件名）
#define UAR_MARINE_MODSUIT_STARTUP_SOUND 'modular_tianguan/modules/uar_marine_modsuit/sound/uar_marine_start.ogg'
/// secHUD 图标状态：挂在 trim 的 sechud_icon_state 上
#define SECHUD_UAR "huduar"
/// 部门色块 = 卡面红；副部门条 = 团结联盟蓝星色（配色取自 tgui/styles/themes/uar.scss）
#define UAR_MARINE_COLOR_CARD_RED "#b00c28"
#define UAR_MARINE_COLOR_UNION_BLUE "#1f3a8a"

// ---------------------------------------------------------------- 主题
/datum/mod_theme/uar_marine
	name = "团结联盟海军陆战队"
	desc = "第四代团结联盟海军陆战队全环境防护服，应用了国家最先进的单兵护甲技术，适用于太空战斗。"
	extended_desc = "在列热叛乱以后团结联盟投入了更多的预算用于建设海军陆战队，第四代防护服成为团结联盟强大武力的重要象征。\
		有人称新的防护服外观令人恐惧，性能优越，团结联盟的敌人将感受精神和物理上的压力。"
	default_skin = "uar_marine"
	armor_type = /datum/armor/mod_theme_uar_marine
	atom_flags = PREVENT_CONTENTS_EXPLOSION_1
	resistance_flags = FIRE_PROOF|ACID_PROOF
	max_heat_protection_temperature = FIRE_IMMUNITY_MAX_TEMP_PROTECT
	siemens_coefficient = 0
	hearing_protection = EAR_PROTECTION_NORMAL
	/// 移速与死亡小队（秘典 apocryphal）一致：基础默认值 0.75，这里显式写出来，免得基类默认值哪天变了
	slowdown_deployed = 0.75
	/// 与死亡小队/陆战队同档（默认 15 + 10）
	complexity_max = DEFAULT_MAX_COMPLEXITY + 10
	allowed_suit_storage = list(
		/obj/item/flashlight,
		/obj/item/tank/internals,
		/obj/item/ammo_box,
		/obj/item/ammo_casing,
		/obj/item/restraints/handcuffs,
		/obj/item/assembly/flash,
		/obj/item/melee/baton,
		/obj/item/gun/ballistic,
	)
	variants = list(
		"uar_marine" = list(
			MOD_ICON_OVERRIDE = UAR_MARINE_MODSUIT_ICON,
			MOD_WORN_ICON_OVERRIDE = UAR_MARINE_MODSUIT_WORN_ICON,
			// 本主题没有单独画蜥蜴人/兽吻变体：把这两个覆盖指向同一份穿戴贴图，
			// 好过让非人类种族穿上后部件整片不可见（上游同类主题是另画一份 _mutant.dmi）。
			MOD_DIGITIGRADE_ICON_OVERRIDE = UAR_MARINE_MODSUIT_WORN_ICON,
			MOD_SNOUT_ICON_OVERRIDE = UAR_MARINE_MODSUIT_WORN_ICON,
			/obj/item/clothing/head/mod = list(
				UNSEALED_LAYER = NECK_LAYER,
				UNSEALED_CLOTHING = SNUG_FIT,
				SEALED_CLOTHING = THICKMATERIAL|STOPSPRESSUREDAMAGE|BLOCK_GAS_SMOKE_EFFECT|HEADINTERNALS,
				// 未密封态也要藏掉头发：本主题的未密封头盔素材本身也是全封闭头盔
				// （不像多数模块服未密封时是敞开露脸的），头发会画在封闭头盔外面/之上，很怪。
				// 上游同类「未密封也是封闭头盔」的主题同样这么写：
				//   /datum/mod_theme/mining 第 568 行、/datum/mod_theme/loader 第 675 行、
				//   死亡小队 apocryphal 都是 HIDEEARS|HIDEHAIR；civilian 把整个脸都藏了。
				// 摘掉头盔部件后自动恢复显示头发（这几个 flags 来自所穿部件，与主题无关）。
				// ⚠ 别把 HIDEHAIR 同时写进下面两张表：seal_part() 解封时是
				//   flags_inv &= ~visor_flags_inv   （mod_activation.dm:287）
				// 也就是"从 flags_inv 里减掉密封表"——凡是两张表都有的位，密封→未密封 之后会被清掉。
				// 早期版本就是这么写的（两表都有 HIDEHAIR），结果解封那一刻头发又冒出来。
				// 正解与上游 mining / loader 的封闭头盔范本一致：要"两态都藏"的位只放未密封表，
				// 密封表只放"密封时额外要藏的"。
				UNSEALED_INVISIBILITY = HIDEHAIR|HIDEFACIALHAIR,
				SEALED_INVISIBILITY = HIDEMASK|HIDEEARS|HIDEEYES|HIDEFACE|HIDESNOUT,
				SEALED_COVER = HEADCOVERSMOUTH|HEADCOVERSEYES|PEPPERPROOF,
				UNSEALED_MESSAGE = HELMET_UNSEAL_MESSAGE,
				SEALED_MESSAGE = HELMET_SEAL_MESSAGE,
			),
			/obj/item/clothing/suit/mod = list(
				UNSEALED_CLOTHING = THICKMATERIAL,
				SEALED_CLOTHING = STOPSPRESSUREDAMAGE,
				SEALED_INVISIBILITY = HIDEJUMPSUIT|HIDETAIL,
				UNSEALED_MESSAGE = CHESTPLATE_UNSEAL_MESSAGE,
				SEALED_MESSAGE = CHESTPLATE_SEAL_MESSAGE,
			),
			/obj/item/clothing/gloves/mod = list(
				UNSEALED_CLOTHING = THICKMATERIAL,
				SEALED_CLOTHING = STOPSPRESSUREDAMAGE,
				CAN_OVERSLOT = TRUE,
				UNSEALED_MESSAGE = GAUNTLET_UNSEAL_MESSAGE,
				SEALED_MESSAGE = GAUNTLET_SEAL_MESSAGE,
			),
			/obj/item/clothing/shoes/mod = list(
				UNSEALED_CLOTHING = THICKMATERIAL,
				SEALED_CLOTHING = STOPSPRESSUREDAMAGE,
				CAN_OVERSLOT = TRUE,
				UNSEALED_MESSAGE = BOOT_UNSEAL_MESSAGE,
				SEALED_MESSAGE = BOOT_SEAL_MESSAGE,
			),
		),
	)

/// 第四代全环境防护服：需求方指定"数值全 100"（近战/子弹/激光/能量/爆炸/生物/耐热/耐酸/创伤）
/datum/armor/mod_theme_uar_marine
	melee = 100
	bullet = 100
	laser = 100
	energy = 100
	bomb = 100
	bio = 100
	fire = 100
	acid = 100
	wound = 100

// ---------------------------------------------------------------- 整套（可刷）
/obj/item/mod/control/pre_equipped/uar_marine
	theme = /datum/mod_theme/uar_marine
	applied_cell = /obj/item/stock_parts/power_store/cell/bluespace
	// 内置模块：参照 modular_z121/code/modules/modsuit/contain_mod/contain_mod.dm 的做法（同一套 17 个）。
	// 合计 complexity = 22，本主题 complexity_max = DEFAULT_MAX_COMPLEXITY(15) + 10 = 25，装得下（不用像 contain 那样加到 +15）。
	applied_modules = list(
		/obj/item/mod/module/storage/bluespace,
		/obj/item/mod/module/headprotector,
		/obj/item/mod/module/emp_shield/advanced,
		/obj/item/mod/module/magnetic_harness,
		/obj/item/mod/module/jetpack/advanced/nored,
		/obj/item/mod/module/magboot/advanced,
		/obj/item/mod/module/dna_lock,
		/obj/item/mod/module/longfall,
		/obj/item/mod/module/flashlight,
		/obj/item/mod/module/status_readout,
		/obj/item/mod/module/anti_magic,
		/obj/item/mod/module/thermal_regulator,
		/obj/item/mod/module/holster,
		/obj/item/mod/module/shock_absorber,
		/obj/item/mod/module/shove_blocker/locked,
		/obj/item/mod/module/rad_protection,
		/obj/item/mod/module/visor/night,
	)
	// 喷气背包默认固定在快捷栏，和 contain 一致
	default_pins = list(
		/obj/item/mod/module/jetpack/advanced/nored,
	)
	activation_sound = UAR_MARINE_MODSUIT_STARTUP_SOUND

// ---------------------------------------------------------------- 启动音效钩子
/// MOD 控制单元的启动音效。默认 null ⇒ 用核心原本的 nominal.ogg；
/// 主题要自己的启动音就在 pre_equipped 子类型里赋一个 sound 路径。
/obj/item/mod/control
	var/activation_sound

// ---------------------------------------------------------------- 武装部 ID 卡
/obj/item/card/id/advanced/uar_marine
	name = "团结联盟武装部"
	desc = "这是团结联盟国家军职人员身份证，它之所以被你看到，是因为这里出现了国家的敌人！"
	icon = UAR_MARINE_MODSUIT_CARD_ICON
	icon_state = "card_uar"
	assigned_icon_state = "assigned_uar"
	trim = /datum/id_trim/uar_marine

/// 卡面徽记（骷髅）+ secHUD 图标（红底 UAR 徽）。department/subdepartment 三块通用色块
/// 必须和 trim_state 放在同一个文件里 —— 它们都从 trim_icon 那份 dmi 里取。
/datum/id_trim/uar_marine
	trim_icon = UAR_MARINE_MODSUIT_CARD_ICON
	assignment = "海军陆战队"
	trim_state = "trim_uar"
	department_color = UAR_MARINE_COLOR_CARD_RED
	subdepartment_color = UAR_MARINE_COLOR_UNION_BLUE
	sechud_icon = UAR_MARINE_MODSUIT_HUD_ICON
	sechud_icon_state = SECHUD_UAR

// 全权限：与 /datum/id_trim/admin（debug 卡，注释原文 "Has every single access in the game"）同一写法。
// REGION_ALL_GLOBAL = 站点全部 + 中央 + 辛迪加 + 远离站 + 邪教，即全游戏每一个区域门禁（实测 98 个 access）。
// 再补 4 个“任何区域都不含、连 debug 卡也没有”的真实门禁：遗迹餐厅 ROROCO（含保险库）、邪教据点、猎人据点。
// 不加的两个：ACCESS_INACCESSIBLE（map helper 用它把门标记成“谁都进不去”，语义上是拒绝而非门禁）、
// ACCESS_ALERT_ADMINS（它不是 access，是“刷这张卡要报警”的清单）。
// 以后要收权限就在这里减，例如：access -= list(ACCESS_CHANGE_IDS)
/datum/id_trim/uar_marine/New()
	. = ..()
	access = SSid_access.get_region_access_list(list(REGION_ALL_GLOBAL)) | list(ACCESS_ROROCO, ACCESS_ROROCO_SECURE, ACCESS_HERETIC, ACCESS_HUNTER)

#undef UAR_MARINE_MODSUIT_ICON
#undef UAR_MARINE_MODSUIT_WORN_ICON
#undef UAR_MARINE_MODSUIT_CARD_ICON
#undef UAR_MARINE_MODSUIT_HUD_ICON
#undef UAR_MARINE_MODSUIT_STARTUP_SOUND
#undef SECHUD_UAR
#undef UAR_MARINE_COLOR_CARD_RED
#undef UAR_MARINE_COLOR_UNION_BLUE
