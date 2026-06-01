// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
/// Gives the target bad luck, optionally permanently
/datum/smite/bad_luck
	name = "Bad Luck"

	/// Should the target know they've received bad luck?
	var/silent

	/// Is this permanent?
	var/incidents

/datum/smite/bad_luck/configure(client/user)
	silent = tgui_alert(user, LANG("datum.c5311705", null), LANG("datum.d2553aea", null), list("Notify", "Silent")) == "Silent"
	incidents = tgui_input_number(user, LANG("datum.d285fd8d", null), LANG("datum.fe7116d6", null), default = 0, round_value = 1)
	if(incidents == 0)
		incidents = INFINITY

/datum/smite/bad_luck/effect(client/user, mob/living/target)
	. = ..()
	//if permanent, replace any existing omen
	if(incidents == INFINITY)
		var/existing_component = target.GetComponent(/datum/component/omen)
		qdel(existing_component)
	target.AddComponent(/datum/component/omen/smite, incidents_left = incidents)
	if(silent)
		return
	to_chat(target, span_warning(LANG("datum.b1f835cf", null)))
	if(incidents == INFINITY)
		to_chat(target, span_warning(LANG("datum.d475bfb9", null)))
