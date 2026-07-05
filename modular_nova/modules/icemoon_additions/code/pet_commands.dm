/datum/component/obeys_commands/RegisterWithParent()
	. = ..()
	RegisterSignal(parent, COMSIG_ATOM_EXAMINE_MORE, PROC_REF(on_examine_more))

/datum/component/obeys_commands/UnregisterFromParent()
	. = ..()
	UnregisterSignal(parent, COMSIG_ATOM_EXAMINE_MORE)

/datum/component/obeys_commands/on_examine(mob/living/source, mob/user, list/examine_list)
	. = ..()
	examine_list += span_italics(LANG("datum.32b38af5", list(source.p_them())))
	examine_list += span_italics(LANG("datum.cd3277e6", list(source.p_them(), source.p_their())))

/datum/component/obeys_commands/proc/on_examine_more(mob/living/source, mob/user, list/examine_list)
	SIGNAL_HANDLER

	if (IS_DEAD_OR_INCAP(source))
		return
	if (!(user in source.ai_controller?.blackboard[BB_FRIENDS_LIST]))
		return

	if (source.health < source.maxHealth*0.2)
		examine_list += span_bolddanger(LANG("datum.505c9252", list(source.p_They(), source.p_s())))
	else if (source.health < source.maxHealth*0.5)
		examine_list += span_danger(LANG("datum.3c0c0ffc", list(source.p_They(), source.p_s())))
	else if (source.health < source.maxHealth*0.8)
		examine_list += span_warning(LANG("datum.3a2cddb9", list(source.p_They(), source.p_s())))
	else
		examine_list += span_notice(LANG("datum.f1bd5dc8", list(source.p_They(), source.p_s())))
