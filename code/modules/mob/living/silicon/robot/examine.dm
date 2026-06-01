// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
/mob/living/silicon/robot/examine(mob/user)
	. = list()
	if(desc)
		. += "[desc]"

	var/model_name = model ? "\improper [model.name]" : "\improper Default"
	. += LANG("mob.6d297d48", list(p_Theyre(), model_name))

	var/obj/act_module = get_active_held_item()
	if(act_module)
		. += LANG("mob.49de5798", list(p_Theyre(), icon2html(act_module, user), act_module))
	. += get_status_effect_examinations()
	if (get_brute_loss())
		if (get_brute_loss() < maxHealth*0.5)
			. += span_warning(LANG("mob.c487477b", list(p_They(), p_s())))
		else
			. += span_boldwarning(LANG("mob.a3853f19", list(p_They(), p_s())))
	if (get_fire_loss() || get_tox_loss())
		var/overall_fireloss = get_fire_loss() + get_tox_loss()
		if (overall_fireloss < maxHealth * 0.5)
			. += span_warning(LANG("mob.822ee814", list(p_They(), p_s())))
		else
			. += span_boldwarning(LANG("mob.189102d3", list(p_They(), p_s())))
	if (health < -maxHealth*0.5)
		. += span_warning(LANG("mob.a6985b41", list(p_They(), p_s())))
	if (fire_stacks < 0)
		. += span_warning(LANG("mob.6d7c684c", list(p_Theyre())))
	else if (fire_stacks > 0)
		. += span_warning(LANG("mob.6f469a95", list(p_Theyre())))

	if(opened)
		. += span_warning(LANG("mob.2d2c85ca", list(p_Their(), cell ? "installed" : "missing")))
	else
		. += LANG("mob.9883c04b", list(p_Their(), locked ? "" : ", and looks unlocked"))

	if(cell && cell.charge <= 0)
		. += span_warning(LANG("mob.1269489e", list(p_Their())))

	switch(stat)
		if(CONSCIOUS)
			if(shell)
				. += "[p_They()] appear[p_s()] to be an [deployed ? "active" : "empty"] AI shell."
			else if(!client)
				. += "[p_They()] appear[p_s()] to be in stand-by mode." //afk
		if(SOFT_CRIT, UNCONSCIOUS, HARD_CRIT)
			. += span_warning("[p_They()] do[p_es()]n't seem to be responding.")
		if(DEAD)
			. += span_deadsay("[p_They()] look[p_s()] like its system is corrupted and requires a reset.")
	//NOVA EDIT ADDITION BEGIN - CUSTOMIZATION
	. += get_silicon_flavortext(user)
	//NOVA EDIT ADDITION END
	. += ..()

/mob/living/silicon/robot/examine_descriptor(mob/user)
	return "cyborg"
