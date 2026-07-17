// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md


/obj/machinery/computer/upload
	var/mob/living/silicon/current = null //The target of future law uploads
	icon_state = MAP_SWITCH("computer", "/obj/machinery/computer/upload")
	icon_screen = "command"
	time_to_unscrew = 6 SECONDS
	var/locked = FALSE
	var/lock_timer

/obj/machinery/computer/upload/Initialize(mapload)
	. = ..()

	if(!mapload)
		log_silicon("\A [name] was created at [loc_name(src)].")
		message_admins("\A [name] was created at [ADMIN_VERBOSEJMP(src)].")

	if(isnull(circuit) || circuit.obj_flags & EMAGGED)
		return

	set_locked(TRUE)


/obj/machinery/computer/upload/emag_act(mob/user, obj/item/card/emag/emag_card)
	if(circuit.obj_flags & EMAGGED)
		return FALSE
	circuit.obj_flags |= EMAGGED
	set_locked(FALSE, user)
	circuit.req_access = null
	circuit.req_one_access = null

	if(user)
		balloon_alert(user, LANG("obj.4b26d84a", null))
	return TRUE

/obj/machinery/computer/upload/proc/should_have_lock()
	if(isnull(circuit))
		return FALSE
	return length(circuit.req_access) || length(circuit.req_one_access)

/obj/machinery/computer/upload/proc/set_locked(locked_state = TRUE, mob/user)
	if(locked == locked_state)
		return
	if(!should_have_lock())
		return
	locked  = !!locked_state
	icon_screen = locked ? "command_locked" : "command"
	update_appearance(UPDATE_OVERLAYS)
	if(user)
		balloon_alert(user, locked ? "console locked!" : "console unlocked!")

/obj/machinery/computer/upload/attackby(obj/item/O, mob/user, list/modifiers, list/attack_modifiers)
	if(istype(O, /obj/item/card/id) && should_have_lock())
		if(machine_stat & (NOPOWER|BROKEN|MAINT))
			return
		if(circuit.obj_flags & EMAGGED)
			balloon_alert(user, LANG("obj.0f1a88d0", null))
			return
		if(!circuit.check_access(O))
			balloon_alert(user, LANG("obj.1bd3ceeb", null))
			return

		set_locked(!locked, user)
		if(lock_timer)
			deltimer(lock_timer)
			lock_timer = null
		if(!locked)
			lock_timer = addtimer(CALLBACK(src, PROC_REF(set_locked), TRUE), 5 MINUTES, TIMER_UNIQUE | TIMER_STOPPABLE)

		update_appearance(UPDATE_OVERLAYS)
		return TRUE

	if(istype(O, /obj/item/ai_module))
		var/obj/item/ai_module/module = O
		if(machine_stat & (NOPOWER|BROKEN|MAINT))
			return
		if(locked && !module.bypass_access_check)
			to_chat(user, span_alert(LANG("obj.3af50529", null)))
			balloon_alert(user, LANG("obj.554f7402", null))
			return
		if(!current)
			to_chat(user, span_alert(LANG("obj.0c5e775e", null)))
			return
		if(!can_upload_to(current))
			to_chat(user, span_alert(LANG("obj.45caa6cb", list(current.name))))
			current = null
			return
		if(!is_valid_z_level(get_turf(current), get_turf(user)))
			to_chat(user, span_alert(LANG("obj.a2299260", list(current.name))))
			current = null
			return
		module.install(current.laws, user)
		imprint_gps("Weak Upload Signal")
	else
		return ..()

/obj/machinery/computer/upload/proc/can_upload_to(mob/living/silicon/S)
	if(S.stat == DEAD)
		return FALSE
	return TRUE

/obj/machinery/computer/upload/ai
	icon_state = MAP_SWITCH("computer", "/obj/machinery/computer/upload/ai") // i mean it starts locked by default
	name = "\improper AI upload console"
	desc = "Used to upload laws to the AI."
	circuit = /obj/item/circuitboard/computer/aiupload

/obj/machinery/computer/upload/ai/Initialize(mapload)
	. = ..()
	if(mapload && HAS_TRAIT(SSstation, STATION_TRAIT_HUMAN_AI))
		return INITIALIZE_HINT_QDEL

	return .

/obj/machinery/computer/upload/ai/interact(mob/user)
	current = select_active_ai(user, z, TRUE)

	if (!current)
		to_chat(user, span_alert(LANG("obj.c8b193f9", null)))
	else
		to_chat(user, span_notice(LANG("obj.1ba2e700", list(current.name))))

/obj/machinery/computer/upload/ai/can_upload_to(mob/living/silicon/ai/A)
	if(!A || !isAI(A))
		return FALSE
	if(A.control_disabled)
		return FALSE
	return ..()


/obj/machinery/computer/upload/borg
	name = "cyborg upload console"
	desc = "Used to upload laws to Cyborgs."
	circuit = /obj/item/circuitboard/computer/borgupload

/obj/machinery/computer/upload/borg/interact(mob/user)
	current = select_active_free_borg(user)

	if(!current)
		to_chat(user, span_alert(LANG("obj.9d4f84e5", null)))
	else
		to_chat(user, span_notice(LANG("obj.1ba2e700", list(current.name))))

/obj/machinery/computer/upload/borg/can_upload_to(mob/living/silicon/robot/B)
	if(!B || !iscyborg(B))
		return FALSE
	if(B.scrambledcodes || B.emagged)
		return FALSE
	return ..()


/obj/machinery/computer/upload/ai/no_lock
	circuit = /obj/item/circuitboard/computer/aiupload/no_lock

/obj/machinery/computer/upload/borg/no_lock
	circuit = /obj/item/circuitboard/computer/borgupload/no_lock
