// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
/datum/buildmode_mode/varedit
	key = "edit"
	// Varedit mode
	var/varholder = null
	var/valueholder = null

/datum/buildmode_mode/varedit/Destroy()
	varholder = null
	valueholder = null
	return ..()

/datum/buildmode_mode/varedit/show_help(client/builder)
	to_chat(builder, span_purple(boxed_message(
		LANG("datum.8d80cf05", list(span_bold("Select var(type) & value"), span_bold("Set var(type) & value"), span_bold("Reset var's value")))))
	)

/datum/buildmode_mode/varedit/Reset()
	. = ..()
	varholder = null
	valueholder = null

/datum/buildmode_mode/varedit/change_settings(client/c)
	varholder = input(c, "Enter variable name:" ,"Name", "name")

	if(!vv_varname_lockcheck(varholder))
		return

	var/temp_value = c.vv_get_value()
	if(isnull(temp_value["class"]))
		Reset()
		to_chat(c, span_notice(LANG("datum.c1c7b5ad", null)))
		return
	valueholder = temp_value["value"]

/datum/buildmode_mode/varedit/handle_click(client/c, params, obj/object)
	var/list/modifiers = params2list(params)

	if(isnull(varholder))
		to_chat(c, span_warning(LANG("datum.43435a0e", null)))
		return
	if(LAZYACCESS(modifiers, LEFT_CLICK))
		if(object.vars.Find(varholder))
			if(object.vv_edit_var(varholder, valueholder) == FALSE)
				to_chat(c, span_warning(LANG("datum.473659ab", null)))
				return
			log_admin("Build Mode: [key_name(c)] modified [object.name]'s [varholder] to [valueholder]")
		else
			to_chat(c, span_warning(LANG("datum.be75221e", list(initial(object.name), varholder))))
	if(LAZYACCESS(modifiers, RIGHT_CLICK))
		if(object.vars.Find(varholder))
			var/reset_value = initial(object.vars[varholder])
			if(object.vv_edit_var(varholder, reset_value) == FALSE)
				to_chat(c, span_warning(LANG("datum.473659ab", null)))
				return
			log_admin("Build Mode: [key_name(c)] modified [object.name]'s [varholder] to [reset_value]")
		else
			to_chat(c, span_warning(LANG("datum.be75221e", list(initial(object.name), varholder))))

