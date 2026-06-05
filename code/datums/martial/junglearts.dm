// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
/datum/martial_art/jungle_arts
	name = "Jungle Arts"
	id = MARTIALART_JUNGLEARTS
	pacifist_style = TRUE

/datum/martial_art/jungle_arts/disarm_act(mob/living/attacker, mob/living/defender)
	return jungle_attack(attacker, defender)

/datum/martial_art/jungle_arts/grab_act(mob/living/attacker, mob/living/defender)
	return jungle_attack(attacker, defender, TRUE)

/datum/martial_art/jungle_arts/harm_act(mob/living/attacker, mob/living/defender)
	return jungle_attack(attacker, defender)

/datum/martial_art/jungle_arts/proc/jungle_attack(mob/living/attacker, mob/living/defender, grab_attack)
	var/atk_verb
	switch(rand(1,6))
		if(1)
			atk_verb = "dragged"
			var/obj/item/organ/tail/tail = attacker.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
			if(isnull(tail) && defender.stat != CONSCIOUS || defender.IsParalyzed())
				return MARTIAL_ATTACK_INVALID

			attacker.do_attack_animation(defender, ATTACK_EFFECT_CLAW)
			attacker.emote("spin")
			defender.visible_message(
				span_danger(LANG("datum.fd5e1b20", list(attacker, atk_verb, defender))),
				span_userdanger(LANG("datum.c7a77b1a", list(atk_verb, attacker))),
				span_hear(LANG("datum.895314d0", null)),
				null,
				attacker,
			)
			to_chat(attacker, span_danger(LANG("datum.da48b359", list(defender, atk_verb))))
			defender.apply_damage(rand(5, 10), attacker.get_attack_type())
			playsound(attacker, 'sound/items/weapons/whip.ogg', 50, TRUE, -1)
			defender.Knockdown(2 SECONDS)
			if(HAS_TRAIT(attacker, TRAIT_PACIFISM))
				attacker.add_mood_event("bypassed_pacifism", /datum/mood_event/pacifism_bypassed)

		if(6)
			var/obj/item/organ/tail/tail = attacker.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
			if(isnull(tail))
				return MARTIAL_ATTACK_INVALID

			atk_verb = pick("whipped", "flogged", "lashed")
			attacker.do_attack_animation(defender, ATTACK_EFFECT_CLAW)
			defender.visible_message(
				span_danger(LANG("datum.e6c71944", list(attacker, atk_verb, defender))),
				span_userdanger(LANG("datum.4115ef68", list(atk_verb, attacker))),
				span_hear(LANG("datum.13c58946", null)),
				null,
				attacker,
			)
			to_chat(attacker, span_danger(LANG("datum.77f1c6e9", list(atk_verb, defender))))
			defender.apply_damage(rand(10, 15), attacker.get_attack_type())
			playsound(attacker, 'sound/items/weapons/whip.ogg', 50, TRUE, -1)
			defender.drop_all_held_items()
			if(HAS_TRAIT(attacker, TRAIT_PACIFISM))
				attacker.add_mood_event("bypassed_pacifism", /datum/mood_event/pacifism_bypassed)

		else
			atk_verb = pick("chomp", "gnaw", "chew")
			if(defender.check_block(attacker, 0, "[attacker]'s [atk_verb]", UNARMED_ATTACK))
				return MARTIAL_ATTACK_FAIL

			attacker.do_attack_animation(defender, ATTACK_EFFECT_BITE)
			defender.visible_message(
				span_danger(LANG("datum.b16baefa", list(attacker, atk_verb, defender))),
				span_userdanger(LANG("datum.762b8a3b", list(atk_verb, attacker))),
				span_hear(LANG("datum.41cd5294", null)),
				null,
				attacker,
			)
			to_chat(attacker, span_danger(LANG("datum.d75fd5cb", list(atk_verb, defender))))
			defender.apply_damage(rand(10, 20), damagetype = BRUTE, sharpness = SHARP_POINTY, wound_bonus = 50)
			playsound(attacker, 'sound/items/weapons/bite.ogg', 50, TRUE, -1)
			if(HAS_TRAIT(attacker, TRAIT_PACIFISM))
				attacker.add_mood_event("bypassed_pacifism", /datum/mood_event/pacifism_bypassed)

	if(atk_verb)
		log_combat(attacker, defender, "[atk_verb] (Jungle Arts)")
		return MARTIAL_ATTACK_SUCCESS

	return MARTIAL_ATTACK_FAIL
