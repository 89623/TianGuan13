// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
///AI Upgrades
/obj/item/aiupgrade
	name = "ai upgrade disk"
	desc = "You really shouldn't be seeing this"
	icon = 'icons/obj/devices/floppy_disks.dmi'
	icon_state = "datadisk3"
	///The upgrade that will be applied to the AI when installed
	var/datum/ai_module/to_gift = /datum/ai_module

/obj/item/aiupgrade/pre_attack(atom/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!isAI(target))
		return ..()
	var/mob/living/silicon/ai/AI = target
	var/datum/action/innate/ai/action = locate(to_gift.power_type) in AI.actions
	var/datum/ai_module/gifted_ability = new to_gift
	if(!to_gift.upgrade)
		if(!action)
			var/ability = to_gift.power_type
			var/datum/action/gifted_action = new ability
			gifted_action.Grant(AI)
		else if(gifted_ability.one_purchase)
			to_chat(user, LANG("obj.b6b27d9f", list(AI, src)))
			return
		else
			action.uses += initial(action.uses)
			action.desc = "[initial(action.desc)] It has [action.uses] use\s remaining."
			action.build_all_button_icons()
	else
		if(!action)
			gifted_ability.upgrade(AI)
			if(gifted_ability.unlock_text)
				to_chat(AI, gifted_ability.unlock_text)
			if(gifted_ability.unlock_sound)
				AI.playsound_local(AI, gifted_ability.unlock_sound, 50, 0)
		update_static_data(AI)
	to_chat(user, span_notice(LANG("obj.6e7b7e33", list(src, AI))))
	to_chat(AI, span_userdanger(LANG("obj.4e408555", list(user, src))))
	user.log_message("has upgraded [key_name(AI)] with a [src].", LOG_GAME)
	qdel(src)
	return TRUE


//Malf Picker
/obj/item/malf_upgrade
	name = "combat software upgrade"
	desc = "A highly illegal, highly dangerous upgrade for artificial intelligence units, granting them a variety of powers as well as the ability to hack APCs.<br>This upgrade does not override any active laws, and must be applied directly to an active AI core."
	icon = 'icons/obj/devices/floppy_disks.dmi'
	icon_state = "datadisk3"

/obj/item/malf_upgrade/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_CONTRABAND, INNATE_TRAIT)

/obj/item/malf_upgrade/pre_attack(atom/A, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!isAI(A))
		return ..()
	var/mob/living/silicon/ai/AI = A
	if(AI.malf_picker)
		AI.malf_picker.processing_time += 50
		to_chat(AI, span_userdanger(LANG("obj.6bdff5a2", list(user))))
	else
		to_chat(AI, span_userdanger(LANG("obj.cee23e03", list(user))))
		to_chat(AI, span_userdanger(LANG("obj.b94f62ed", null))) //this unlocks malf powers, but does not give the license to plasma flood
		AI.add_malf_picker()
		AI.hack_software = TRUE
		log_silicon("[key_name(user)] has upgraded [key_name(AI)] with a [src].")
		message_admins("[ADMIN_LOOKUPFLW(user)] has upgraded [ADMIN_LOOKUPFLW(AI)] with a [src].")
	to_chat(user, span_notice(LANG("obj.6e7b7e33", list(src, AI))))
	qdel(src)
	return TRUE


//Lipreading
/obj/item/aiupgrade/surveillance_upgrade
	name = "surveillance software upgrade"
	desc = "An illegal software package that will allow an artificial intelligence to 'hear' from its cameras via lip reading and hidden microphones."
	to_gift = /datum/ai_module/malf/upgrade/eavesdrop
	custom_materials = list(/datum/material/diamond = SHEET_MATERIAL_AMOUNT * 10, /datum/material/gold = SHEET_MATERIAL_AMOUNT * 7.5, /datum/material/silver = SHEET_MATERIAL_AMOUNT * 7.5, /datum/material/plasma = SHEET_MATERIAL_AMOUNT * 5, /datum/material/iron = SHEET_MATERIAL_AMOUNT * 2.5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5)

/obj/item/aiupgrade/surveillance_upgrade/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_CONTRABAND, INNATE_TRAIT)


/obj/item/aiupgrade/power_transfer
	name = "power transfer upgrade"
	desc = "A legal upgrade that allows an artificial intelligence to directly provide power to APCs from a distance"
	to_gift = /datum/ai_module/power_apc
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2.5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5)
