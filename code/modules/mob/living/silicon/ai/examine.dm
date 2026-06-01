// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
/mob/living/silicon/ai/examine(mob/user)
	. = list()
	if(stat == DEAD)
		. += span_warning("[p_They()] appear[p_s()] to be non functional.")
	. += span_notice("[p_Their()] floor <b>bolts</b> are [is_anchored ? "tightened" : "loose"].")
	if(is_anchored)
		if(!opened)
			if(!emagged)
				. += span_notice("[p_Their()] access panel is [stat == DEAD ? "damaged" : "closed and locked"], but could be <b>pried</b> open.")
			else
				. += span_warning("[p_Their()] access panel lock is sparking, the cover can be <b>pried</b> open.")
		else
			. += span_notice("[p_Their()] neural network connection could be <b>cut</b>, the access panel cover can be <b>pried</b> back into place.")
	if(stat != DEAD)
		if (get_brute_loss())
			if (get_brute_loss() < 30)
				. += span_warning("[p_They()] look[p_s()] slightly dented.")
			else
				. += span_warning("<B>[p_They()] look[p_s()] severely dented!</B>")
		if (get_fire_loss())
			if (get_fire_loss() < 30)
				. += span_warning("[p_They()] look[p_s()] slightly charred.")
			else
				. += span_warning("<B>[p_Their()] casing is melted and heat-warped!</B>")
		if(deployed_shell)
			. += LANG("mob.c0556282", null)
		else if (!shunted && !client)
			. += LANG("mob.dbbd0a60", list(src))
	//NOVA EDIT ADDITION BEGIN - CUSTOMIZATION
	. += get_silicon_flavortext(user)
	//NOVA EDIT ADDITION END

	. += ..()
