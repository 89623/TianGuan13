GLOBAL_DATUM_INIT(temporary_flavor_text_vis, /obj/effect/overlay/indicator/temporary_flavor_text, new)

/obj/effect/overlay/indicator/temporary_flavor_text
	icon = 'modular_nova/modules/indicators/icons/temporary_flavor_text_indicator.dmi'
	icon_state = "flavor"

/mob/living/verb/set_temporary_flavor()
	set category = "IC"
	set name = "Set Temporary Flavor Text"
	set desc = "Allows you to set a temporary flavor text."

	if(stat != CONSCIOUS)
		to_chat(usr, span_warning(LANG("mob.a3ef0a20", null)))
		return

	var/msg = tgui_input_text(usr, LANG("mob.3b4f7fa2", null), LANG("mob.bfbb9785", null), temporary_flavor_text, max_length = MAX_FLAVOR_LEN, multiline = TRUE)
	if(msg == null)
		return

	// Turn empty input into no flavor text
	var/result = msg || null
	temporary_flavor_text = result
	if(temporary_flavor_text)
		vis_contents |= GLOB.temporary_flavor_text_vis
	else
		vis_contents -= GLOB.temporary_flavor_text_vis

