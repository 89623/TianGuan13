// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
/datum/ai_controller/basic_controller/bot/secbot/super_beepsky

	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity/pacifist,
		/datum/ai_planning_subtree/respond_to_summon,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
		/datum/ai_planning_subtree/find_patrol_beacon,
	)

/datum/ai_controller/basic_controller/bot/secbot/super_beepsky/on_target_set()
	. = ..()
	var/mob/living/basic/bot/secbot/grievous/super_beeps = pawn
	if(!super_beeps.sword_active)
		INVOKE_ASYNC(super_beeps.weapon, TYPE_PROC_REF(/obj/item, attack_self), super_beeps)
	super_beeps.visible_message(LANG("datum.bcd922f7", list(super_beeps, blackboard[BB_BASIC_MOB_CURRENT_TARGET])))
