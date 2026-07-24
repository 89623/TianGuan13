/obj/item/autosurgeon/bodypart
	name = "bodypart upgrade autosurgeon"
	desc = "A device that will expertly replace your bodypart."

	var/bodypart_type = /obj/item/bodypart

	var/starting_bodypart //The bodypart we come with

	var/obj/item/bodypart/storedbodypart

/obj/item/autosurgeon/bodypart/Initialize(mapload)
	. = ..()
	if(starting_bodypart)
		insert_bodypart(new starting_bodypart(src))

/obj/item/autosurgeon/bodypart/proc/insert_bodypart(obj/item/I)
	storedbodypart = I
	I.forceMove(src)
	name = "[lang_reverse_text(initial(name))] ([storedbodypart.name])"  // i18n: initial(name) 会覆盖掉已反查的中文名

/obj/item/autosurgeon/bodypart/attack_self(mob/user)//when the object it used...
	if(!uses)
		to_chat(user, span_alert(LANG("obj.8104ad50", list(src))))
		return
	if(!storedbodypart)
		to_chat(user, span_alert(LANG("obj.7c5b6298", list(src))))
		return
	if(!ishuman(user))
		return

	var/mob/living/carbon/human/H = user

	var/obj/item/bodypart/oldBP = H.get_bodypart(storedbodypart.body_zone)

	if(oldBP)
		to_chat(H, span_warning(LANG("obj.ac75381d", list(src, oldBP.name))))
		oldBP.dismember()

	user.visible_message(span_notice(LANG("obj.00b55570", list(H, src))), span_notice(LANG("obj.d2eeea84", list(src))))

	if(!storedbodypart.try_attach_limb(H))
		to_chat(H, span_warning(LANG("obj.42f1dc61", list(src, storedbodypart))))
		return

	playsound(get_turf(H), 'sound/items/weapons/circsawhit.ogg', 50, TRUE)
	storedbodypart = null
	name = initial(name)
	if(uses != INFINITY)
		uses--
	if(!uses)
		desc = LANG("obj.8c69c278", list(initial(desc)))

/obj/item/autosurgeon/bodypart/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, bodypart_type))
		if(storedbodypart)
			to_chat(user, span_alert("[src] already has an implant stored."))
			return ITEM_INTERACT_BLOCKING
		else if(!uses)
			to_chat(user, span_alert("[src] has already been used up."))
			return ITEM_INTERACT_BLOCKING
		if(!user.transferItemToLoc(tool, src))
			return ITEM_INTERACT_BLOCKING
		storedbodypart = tool
		to_chat(user, span_notice("You insert the [tool] into [src]."))
		return ITEM_INTERACT_SUCCESS
	else
		return ..()

/obj/item/autosurgeon/bodypart/screwdriver_act(mob/living/user, obj/item/I)
	if(..())
		return TRUE
	if(!storedbodypart)
		to_chat(user, span_warning(LANG("obj.215a92c5", list(src))))
	else
		var/atom/drop_loc = user.drop_location()
		for(var/J in src)
			var/atom/movable/AM = J
			AM.forceMove(drop_loc)

		to_chat(user, span_notice(LANG("obj.01339089", list(storedbodypart, src))))
		I.play_tool_sound(src)
		storedbodypart = null
		if(uses != INFINITY)
			uses--
		if(!uses)
			desc = LANG("obj.8c69c278", list(initial(desc)))
	return TRUE
