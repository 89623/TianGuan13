// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
/mob/living/silicon/ai/examine(mob/user)
	. = list()
	if(stat == DEAD)
		. += span_warning(LANG("mob.8ca0f7fc", list(p_They(), p_s())))
	. += span_notice(LANG("mob.2e9e1c08", list(p_Their(), is_anchored ? "tightened" : "loose")))
	if(is_anchored)
		if(!opened)
			if(!emagged)
				. += span_notice(LANG("mob.2299454b", list(p_Their(), stat == DEAD ? "damaged" : "closed and locked")))
			else
				. += span_warning(LANG("mob.2a26588f", list(p_Their())))
		else
			. += span_notice(LANG("mob.b0adf1fe", list(p_Their())))
	if(stat != DEAD)
		if (get_brute_loss())
			if (get_brute_loss() < 30)
				. += span_warning(LANG("mob.c487477b", list(p_They(), p_s())))
			else
				. += span_warning(LANG("mob.5f081d0a", list(p_They(), p_s())))
		if (get_fire_loss())
			if (get_fire_loss() < 30)
				. += span_warning(LANG("mob.822ee814", list(p_They(), p_s())))
			else
				. += span_warning(LANG("mob.40f30327", list(p_Their())))
		if(deployed_shell)
			. += LANG("mob.c0556282", null)
		else if (!shunted && !client)
			. += LANG("mob.dbbd0a60", list(src))
	//NOVA EDIT ADDITION BEGIN - CUSTOMIZATION
	. += get_silicon_flavortext(user)
	//NOVA EDIT ADDITION END

	. += ..()
