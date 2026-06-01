// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
/obj/machinery/computer/prisoner
	interaction_flags_machine = INTERACT_MACHINE_ALLOW_SILICON|INTERACT_MACHINE_REQUIRES_LITERACY
	/// ID card currently inserted into the computer.
	VAR_FINAL/obj/item/card/id/advanced/prisoner/contained_id
	interaction_flags_click = ALLOW_SILICON_REACH

/obj/machinery/computer/prisoner/on_deconstruction(disassembled)
	contained_id?.forceMove(drop_location())

/obj/machinery/computer/prisoner/Destroy()
	QDEL_NULL(contained_id)
	return ..()

/obj/machinery/computer/prisoner/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == contained_id)
		contained_id = null

/obj/machinery/computer/prisoner/examine(mob/user)
	. = ..()
	if(contained_id)
		. += span_notice(LANG("obj.91ac6969", null))

/obj/machinery/computer/prisoner/click_alt(mob/user)
	id_eject(user)
	return CLICK_ACTION_SUCCESS

/obj/machinery/computer/prisoner/proc/id_insert(mob/user, obj/item/card/id/advanced/prisoner/new_id)
	if(!istype(new_id))
		return
	if(!isnull(contained_id))
		balloon_alert(user, LANG("obj.012de839", null))
		return
	if(!user.transferItemToLoc(new_id, src))
		return
	contained_id = new_id
	balloon_alert_to_viewers("id inserted")
	playsound(src, 'sound/machines/terminal/terminal_insert_disc.ogg', 50, FALSE)

/obj/machinery/computer/prisoner/proc/id_eject(mob/user)
	if(isnull(contained_id))
		balloon_alert(user, LANG("obj.94788ab7", null))
		return

	if(!issilicon(user) && Adjacent(user))
		user.put_in_hands(contained_id)
	else
		contained_id.forceMove(drop_location())

	balloon_alert_to_viewers("id ejected")
	playsound(src, 'sound/machines/terminal/terminal_insert_disc.ogg', 50, FALSE)

/obj/machinery/computer/prisoner/attackby(obj/item/weapon, mob/user, list/modifiers, list/attack_modifiers)
	if(istype(weapon, /obj/item/card/id/advanced/prisoner))
		id_insert(user, weapon)
		return TRUE

	return ..()
