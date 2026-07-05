// 天关模块化改动：安全官生成后额外获得一把小型能量枪，避免直接改核心安全官 outfit 定义。
/datum/outfit/job/security/post_equip(mob/living/carbon/human/equipped, visuals_only = FALSE)
	. = ..()
	if(visuals_only)
		return

	equipped.equip_to_storage(new /obj/item/gun/energy/e_gun/mini(equipped), ITEM_SLOT_BACK, indirect_action = TRUE, del_on_fail = TRUE)
