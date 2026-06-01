/obj/item/scissors
	name = "barber's scissors"
	desc = "Some say a barbers best tool is his electric razor, that is not the case. These are used to cut hair in a professional way!"
	icon = 'modular_nova/modules/salon/icons/items.dmi'
	icon_state = "scissors"
	w_class = WEIGHT_CLASS_TINY
	sharpness = SHARP_EDGED
	// How long does it take to change someone's hairstyle?
	var/haircut_duration = 1 MINUTES
	// How long does it take to change someone's facial hair style?
	var/facial_haircut_duration = 20 SECONDS
	// Same as above, but for those with the hair expert trait
	var/haircut_duration_expert = 45 SECONDS
	var/facial_haircut_duration_expert = 15 SECONDS

/obj/item/scissors/attack(mob/living/attacked_mob, mob/living/user, params)
	if(!ishuman(attacked_mob))
		return

	var/mob/living/carbon/human/target_human = attacked_mob

	var/location = user.zone_selected
	if(!(location in list(BODY_ZONE_PRECISE_MOUTH, BODY_ZONE_HEAD)) && !user.combat_mode)
		to_chat(user, span_warning(LANG("obj.d6bb1707", null)))
		return

	if(target_human.hairstyle == "Bald" && target_human.facial_hairstyle == "Shaved")
		balloon_alert(user, LANG("obj.6754061c", null))
		return

	if(user.zone_selected != BODY_ZONE_HEAD)
		return ..()

	var/selected_part = tgui_alert(user, LANG("obj.0b4ef4b8", list(target_human)), LANG("obj.e455fc28", null), list("Hair", "Facial Hair", "Cancel"))

	if(!selected_part || selected_part == "Cancel")
		return

	if(selected_part == "Hair")
		if(!target_human.hairstyle == "Bald" && target_human.head)
			balloon_alert(user, LANG("obj.5df36852", null))
			return

		var/hair_id = tgui_input_list(user, LANG("obj.b89bab7d", null), LANG("obj.f7de00bf", null), SSaccessories.hairstyles_list)
		if(!hair_id)
			return

		if(hair_id == "Bald")
			to_chat(target_human, span_danger(LANG("obj.f8bef301", list(user))))

		to_chat(user, span_notice(LANG("obj.85380f50", list(target_human))))

		playsound(target_human, 'modular_nova/modules/salon/sound/haircut.ogg', 100)

		if(HAS_TRAIT(user, TRAIT_HAIR_EXPERT))
			if(do_after(user, haircut_duration_expert, target_human))
				target_human.set_hairstyle(hair_id, update = TRUE)
				user.visible_message(span_notice("[user] expertly cuts [target_human]'s hair!"), span_notice("You expertly cut [target_human]'s hair!"))
		else
			if(do_after(user, haircut_duration, target_human))
				target_human.set_hairstyle(hair_id, update = TRUE)
				user.visible_message(span_notice("[user] successfully cuts [target_human]'s hair!"), span_notice("You successfully cut [target_human]'s hair!"))
				new /obj/effect/decal/cleanable/hair(get_turf(src))
	else
		if(!target_human.facial_hairstyle == "Shaved" && target_human.wear_mask)
			balloon_alert(user, LANG("obj.5df36852", null))
			return

		var/facial_hair_id = tgui_input_list(user, LANG("obj.c5cd9bad", null), LANG("obj.f7de00bf", null), SSaccessories.facial_hairstyles_list)
		if(!facial_hair_id)
			return

		if(facial_hair_id == "Shaved")
			to_chat(target_human, span_danger(LANG("obj.77ac974b", list(user))))

		to_chat(user, LANG("obj.3c55989d", list(target_human)))

		playsound(target_human, 'modular_nova/modules/salon/sound/haircut.ogg', 100)

		if(HAS_TRAIT(user, TRAIT_HAIR_EXPERT))
			if(do_after(user, facial_haircut_duration_expert, target_human))
				target_human.set_facial_hairstyle(facial_hair_id, update = TRUE)
				user.visible_message(span_notice("[user] expertly cuts [target_human]'s facial hair!"), span_notice("You expertly cut [target_human]'s facial hair!"))
		else
			if(do_after(user, facial_haircut_duration, target_human))
				target_human.set_facial_hairstyle(facial_hair_id, update = TRUE)
				user.visible_message(span_notice("[user] successfully cuts [target_human]'s facial hair!"), span_notice("You successfully cut [target_human]'s facial hair!"))
				new /obj/effect/decal/cleanable/hair(get_turf(src))
