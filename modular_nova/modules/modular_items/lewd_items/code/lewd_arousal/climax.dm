#define CLIMAX_VAGINA "Vagina"
#define CLIMAX_PENIS "Penis"
#define CLIMAX_BOTH "Both"

#define CLIMAX_ON_FLOOR "On the floor"
#define CLIMAX_IN_OR_ON "Climax in or on someone"
#define CLIMAX_OPEN_CONTAINER "Fill reagent container"

/mob/living/carbon/human
	/// Used to prevent nightmare scenarios.
	var/refractory_period

/mob/living/carbon/human/proc/climax(manual = TRUE)
	if (CONFIG_GET(flag/disable_erp_preferences))
		return

	if(!client?.prefs?.read_preference(/datum/preference/toggle/erp/autocum) && !manual)
		return
	if(refractory_period > REALTIMEOFDAY)
		return
	refractory_period = REALTIMEOFDAY + 30 SECONDS
	if(has_status_effect(/datum/status_effect/climax_cooldown) || !client?.prefs?.read_preference(/datum/preference/toggle/erp))
		return

	if(HAS_TRAIT(src, TRAIT_NEVERBONER) || has_status_effect(/datum/status_effect/climax_cooldown) || (!has_vagina() && !has_penis()))
		visible_message(span_purple(LANG("mob.65eb8f7f", list(src))), \
			span_purple(LANG("mob.59077c06", null)), pref_to_check = /datum/preference/toggle/erp)
		return TRUE

	// Reduce pop-ups and make it slightly more frictionless (lewd).
	var/climax_choice = has_penis() ? CLIMAX_PENIS : CLIMAX_VAGINA

	if(manual)
		var/list/genitals = list()
		if(has_vagina())
			genitals.Add(CLIMAX_VAGINA)
			if(has_penis())
				genitals.Add(CLIMAX_PENIS)
				genitals.Add(CLIMAX_BOTH)
		else if(has_penis())
			genitals.Add(CLIMAX_PENIS)
		climax_choice = tgui_alert(src, "You are climaxing, choose which genitalia to climax with.", "Genitalia Preference!", genitals)

	switch(gender)
		if(MALE)
			playsound_if_pref(get_turf(src), pick('modular_nova/modules/modular_items/lewd_items/sounds/final_m1.ogg',
										'modular_nova/modules/modular_items/lewd_items/sounds/final_m2.ogg',
										'modular_nova/modules/modular_items/lewd_items/sounds/final_m3.ogg'), 50, TRUE, pref_to_check = /datum/preference/toggle/erp/sounds)
		if(FEMALE)
			playsound_if_pref(get_turf(src), pick('modular_nova/modules/modular_items/lewd_items/sounds/final_f1.ogg',
										'modular_nova/modules/modular_items/lewd_items/sounds/final_f2.ogg',
										'modular_nova/modules/modular_items/lewd_items/sounds/final_f3.ogg'), 50, TRUE, pref_to_check = /datum/preference/toggle/erp/sounds)

	var/self_orgasm = FALSE
	var/self_their = p_their()

	if(climax_choice == CLIMAX_PENIS || climax_choice == CLIMAX_BOTH)
		var/obj/item/organ/genital/penis/penis = get_organ_slot(ORGAN_SLOT_PENIS)
		if(!get_organ_slot(ORGAN_SLOT_TESTICLES)) //If we have no god damn balls, we can't cum anywhere... GET BALLS!
			visible_message(span_userlove(LANG("mob.6e0187ed", list(src, self_their))), \
				span_userlove(LANG("mob.f8c5d54c", null)), pref_to_check = /datum/preference/toggle/erp)

		else if(is_wearing_condom())
			var/obj/item/clothing/sextoy/condom/condom = src.penis
			condom.condom_use()
			visible_message(span_userlove(LANG("mob.a1e08d66", list(src, self_their, condom))), \
				span_userlove(LANG("mob.02a03105", list(condom))), pref_to_check = /datum/preference/toggle/erp)

		else if(!is_bottomless() && penis.visibility_preference != GENITAL_ALWAYS_SHOW)
			visible_message(span_userlove(LANG("mob.64e23146", list(src, self_their))), \
				span_userlove(LANG("mob.d44b5efa", null)), pref_to_check = /datum/preference/toggle/erp)
			self_orgasm = TRUE

		else
			var/list/interactable_inrange_humans = list()
			var/list/interactable_inrange_open_containers = list()

			// Unfortunately prefs can't be checked here, because byond/tgstation moment.
			for(var/mob/living/carbon/human/iterating_human in (view(1, src) - src))
				interactable_inrange_humans[iterating_human.name] = iterating_human

			// this should be making a list of cups(?)
			for(var/obj/item/reagent_containers/cup/iterating_open_container in (view(1, src)))
				if(!iterating_open_container.is_refillable() || !iterating_open_container.is_drainable())
					continue
				interactable_inrange_open_containers[iterating_open_container.name] = iterating_open_container

			var/list/buttons = list(CLIMAX_ON_FLOOR)
			if(interactable_inrange_humans.len)
				buttons += CLIMAX_IN_OR_ON

			if(interactable_inrange_open_containers.len)
				buttons += CLIMAX_OPEN_CONTAINER

			var/penis_climax_choice = tgui_alert(src, "Choose where to shoot your load.", "Load preference!", buttons)

			var/create_cum_decal = FALSE

			if(isnull(penis_climax_choice) || penis_climax_choice == CLIMAX_ON_FLOOR)
				create_cum_decal = TRUE
				visible_message(span_userlove(LANG("mob.47e60ad7", list(src, self_their))), \
					span_userlove(LANG("mob.28062261", null)), pref_to_check = /datum/preference/toggle/erp)

			else if(penis_climax_choice == CLIMAX_OPEN_CONTAINER)
				var/target_choice = tgui_input_list(src, "Choose a container to cum into.", "Choose target!", interactable_inrange_open_containers)
				if(isnull(target_choice))
					create_cum_decal = TRUE
					visible_message(span_userlove(LANG("mob.47e60ad7", list(src, self_their))), \
						span_userlove(LANG("mob.171aa063", null)), pref_to_check = /datum/preference/toggle/erp)
				else
					var/obj/item/reagent_containers/cup/target_open_container = interactable_inrange_open_containers[target_choice]
					if(target_open_container.is_refillable() && target_open_container.is_drainable())
						var/obj/item/organ/genital/testicles/src_testicles = src.get_organ_slot(ORGAN_SLOT_TESTICLES)
						var/load_volume = src_testicles.genital_size * 10
						playsound_if_pref(get_turf(src), SFX_DESECRATION, 50, TRUE, pref_to_check = /datum/preference/toggle/erp/sounds)
						if(target_open_container.reagents.holder_full())
							// reagent container is full
							add_cum_splatter_floor(get_turf(target_open_container))
							visible_message(span_userlove(LANG("mob.b19e3b70", list(src, target_open_container))), \
								span_userlove(LANG("mob.30345c74", list(target_open_container))), pref_to_check = /datum/preference/toggle/erp)
						else
							target_open_container.reagents.add_reagent(/datum/reagent/consumable/cum, load_volume)
							if((load_volume + target_open_container.reagents.total_volume) > target_open_container.volume)
								// the chalice overfloweth
								add_cum_splatter_floor(get_turf(target_open_container))
								visible_message(span_userlove(LANG("mob.596a5d85", list(src, self_their, target_open_container))), \
									span_userlove(LANG("mob.de263d6c", list(target_open_container))), pref_to_check = /datum/preference/toggle/erp)
							else
								visible_message(span_userlove(LANG("mob.a9928d9e", list(src, self_their, target_open_container))), \
									span_userlove(LANG("mob.00685b84", list(target_open_container))), pref_to_check = /datum/preference/toggle/erp)
					else
						// somehow the reagents changed while we were deciding where to go
						create_cum_decal = TRUE
						visible_message(span_userlove(LANG("mob.47e60ad7", list(src, self_their))), \
							span_userlove(LANG("mob.28062261", null)), pref_to_check = /datum/preference/toggle/erp)

			else
				var/target_choice = tgui_input_list(src, "Choose a person to cum in or on.", "Choose target!", interactable_inrange_humans)
				if(!target_choice)
					create_cum_decal = TRUE
					visible_message(span_userlove(LANG("mob.47e60ad7", list(src, self_their))), \
						span_userlove(LANG("mob.28062261", null)), pref_to_check = /datum/preference/toggle/erp)
				else
					var/mob/living/carbon/human/target_human = interactable_inrange_humans[target_choice]
					var/target_human_them = target_human.p_them()

					var/list/target_buttons = list()

					if(!target_human.wear_mask)
						target_buttons += "mouth"
					if(target_human.has_vagina(REQUIRE_GENITAL_EXPOSED))
						target_buttons += ORGAN_SLOT_VAGINA
					if(target_human.has_anus(REQUIRE_GENITAL_EXPOSED))
						target_buttons += "asshole"
					if(target_human.has_penis(REQUIRE_GENITAL_EXPOSED))
						var/obj/item/organ/genital/penis/other_penis = target_human.get_organ_slot(ORGAN_SLOT_PENIS)
						if(other_penis.sheath != SPRITE_ACCESSORY_NONE)
							target_buttons += "sheath"
					target_buttons += "On [target_human_them]"

					var/climax_into_choice = tgui_input_list(src, "Where on or in [target_human] do you wish to cum?", "Final frontier!", target_buttons)

					if(!climax_into_choice)
						create_cum_decal = TRUE
						visible_message(span_userlove(LANG("mob.c112e520", list(src))), \
							span_userlove(LANG("mob.28062261", null)), pref_to_check = /datum/preference/toggle/erp)
					else if(climax_into_choice == "On [target_human_them]")
						create_cum_decal = TRUE
						visible_message(span_userlove(LANG("mob.82a775d2", list(src, target_human))), \
							span_userlove(LANG("mob.967166ce", list(target_human))), pref_to_check = /datum/preference/toggle/erp)
					else
						visible_message(span_userlove(LANG("mob.98f8dc62", list(src, self_their, target_human, climax_into_choice, target_human_them))), \
							span_userlove(LANG("mob.8cccffb8", list(target_human, climax_into_choice, target_human_them))), pref_to_check = /datum/preference/toggle/erp)
						to_chat(target_human, span_userlove(LANG("mob.a85881eb", list(climax_into_choice, src, self_their))))

			var/obj/item/organ/genital/testicles/testicles = get_organ_slot(ORGAN_SLOT_TESTICLES)
			testicles.transfer_internal_fluid(null, testicles.internal_fluid_count * 0.6) // yep. we are sending semen to nullspace
			if(create_cum_decal)
				add_cum_splatter_floor(get_turf(src))

		try_lewd_autoemote("moan")
		if(climax_choice == CLIMAX_PENIS)
			apply_status_effect(/datum/status_effect/climax)
			apply_status_effect(/datum/status_effect/climax_cooldown)
			if(self_orgasm)
				add_mood_event("orgasm", /datum/mood_event/climaxself)
			return TRUE

	if(climax_choice == CLIMAX_VAGINA || climax_choice == CLIMAX_BOTH)
		var/obj/item/organ/genital/vagina/vagina = get_organ_slot(ORGAN_SLOT_VAGINA)
		if(is_bottomless() || vagina.visibility_preference == GENITAL_ALWAYS_SHOW)
			visible_message(span_userlove(LANG("mob.7afb4b07", list(src, p_they()))), span_userlove(LANG("mob.e21fd6a2", null)), pref_to_check = /datum/preference/toggle/erp)
			add_cum_splatter_floor(get_turf(src), female = TRUE)
		else
			visible_message(span_userlove(LANG("mob.945b0574", list(src, self_their, self_their))), \
						span_userlove(LANG("mob.e799c6ce", null)), pref_to_check = /datum/preference/toggle/erp)
			self_orgasm = TRUE

	apply_status_effect(/datum/status_effect/climax)
	apply_status_effect(/datum/status_effect/climax_cooldown)
	if(self_orgasm)
		add_mood_event("orgasm", /datum/mood_event/climaxself)
	return TRUE

#undef CLIMAX_VAGINA
#undef CLIMAX_PENIS
#undef CLIMAX_BOTH
#undef CLIMAX_ON_FLOOR
#undef CLIMAX_IN_OR_ON
#undef CLIMAX_OPEN_CONTAINER
