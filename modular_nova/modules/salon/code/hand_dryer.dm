/obj/machinery/dryer
	name = "hand dryer"
	desc = "The Breath Of Lizards-3000, an experimental dryer."
	icon = 'modular_nova/modules/salon/icons/dryer.dmi'
	icon_state = "dryer"
	density = FALSE
	anchored = TRUE
	var/busy = FALSE

/obj/machinery/dryer/attack_hand(mob/user)
	if(iscyborg(user) || isAI(user))
		return

	if(!can_interact(user))
		return

	if(busy)
		to_chat(user, span_warning(LANG("obj.b5773197", null)))
		return

	to_chat(user, span_notice(LANG("obj.86c15bf3", null)))
	playsound(src, 'modular_nova/modules/salon/sound/drying.ogg', 50)
	add_fingerprint(user)
	busy = TRUE
	if(do_after(user, 4 SECONDS, src))
		busy = FALSE
		user.visible_message(LANG("obj.8459c139", list(user, src)))
	else
		busy = FALSE
