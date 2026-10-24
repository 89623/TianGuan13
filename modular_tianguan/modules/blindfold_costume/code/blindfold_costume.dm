/**
 * 非盲人专用眼罩（外观眼罩 / cosmetic blindfold）
 *
 * 需求：配装菜单里只有上游那条「眼罩 - 盲人专用」（/datum/loadout_item/glasses/blindfold/color →
 * /obj/item/clothing/glasses/blindfold/color），戴上必定失明。玩家想要一件**外观与它相同**、
 * 但不影响视野的同款眼罩；局内名字要与「盲人眼罩」区分，检视只留一句话。
 *
 * 做法：直接从 /obj/item/clothing/glasses/blindfold/color 派生，只改掉两处会改变玩法结果的字段：
 *   tint          —— 核心靠它致盲：/mob/living/carbon/proc/update_tint() 把所有穿戴件的 tint 相加，
 *                    达到 TINT_BLIND 就 become_blind(EYES_COVERED)。父类是 INFINITY（必瞎），这里给 0。
 *   flash_protect —— 父类顺带给了焊接/闪光防护（FLASH_PROTECTION_WELDER）；纯外观件不白送，置 NONE。
 * 其余全部原样继承：icon / icon_state / post_init_icon_state / greyscale_config(_worn) /
 * worn_icon / greyscale_colors / flags_1(IS_PLAYER_COLORABLE_1，玩家仍可自己染色) /
 * visual_equipped()（戴上时按瞳色染色）/ Initialize() 的钓鱼难度 element —— 即「只体现其精灵图效果」。
 *
 * 本文件不触碰任何核心文件，只需在 tgstation.dme 里 include 一行。
 */

/obj/item/clothing/glasses/blindfold/color/cosmetic
	name = "眼罩"
	desc = "和盲人眼罩同款，但戴上不影响视野。"
	tint = 0 // 父类是 INFINITY（必定致盲）；必须显式给 0，否则继承下来就瞎
	flash_protect = FLASH_PROTECTION_NONE // 父类是 FLASH_PROTECTION_WELDER；外观件不送防护

// ——— 配装（loadout）条目 ———
// 挂 /datum/loadout_item/glasses ⇒ 落在配装界面的 Glasses（眼镜）页签，紧挨着上游「眼罩 - 盲人专用」
// （该页签的 insert_path_into_outfit() 会把物品塞进眼睛槽 outfit.glasses）。
// 条目 item_path 是全新类型 ⇒ 不会撞 GLOB.all_loadout_datums 的键（那个键就是 item_path）。
// 无 donator_only / restricted_roles ⇒ 所有玩家都能领。
/datum/loadout_item/glasses/cosmetic_blindfold
	name = "眼罩 - 非盲人专用"
	item_path = /obj/item/clothing/glasses/blindfold/color/cosmetic
