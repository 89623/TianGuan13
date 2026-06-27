// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
/turf/closed/wall/r_wall
	name = "reinforced wall"
	desc = "A huge chunk of reinforced metal used to separate rooms."
	icon = 'icons/turf/walls/reinforced_wall.dmi' //NOVA EDIT - ICON OVERRIDDEN IN AESTHETICS MODULE
	icon_state = "reinforced_wall-0"
	base_icon_state = "reinforced_wall"
	opacity = TRUE
	density = TRUE
	turf_flags = IS_SOLID
	smoothing_flags = SMOOTH_BITMASK
	hardness = 10
	sheet_type = /obj/item/stack/sheet/plasteel
	sheet_amount = 1
	girder_type = /obj/structure/girder/reinforced
	girder_state = GIRDER_REINF
	make_delay = 5 SECONDS
	explosive_resistance = 2
	rad_insulation = RAD_HEAVY_INSULATION
	rust_resistance = RUST_RESISTANCE_REINFORCED
	heat_capacity = 312500 //a little over 5 cm thick , 312500 for 1 m by 2.5 m by 0.25 m plasteel wall. also indicates the temperature at wich the wall will melt (currently only able to melt with H/E pipes)
	///Dismantled state, related to deconstruction.
	var/d_state = INTACT
	///Base icon state to use for deconstruction
	var/base_decon_state = "r_wall"

/turf/closed/wall/r_wall/deconstruction_hints(mob/user)
	switch(d_state)
		if(INTACT)
			return span_notice("The outer <b>grille</b> is fully intact.")
		if(SUPPORT_LINES)
			return span_notice("The outer <i>grille</i> has been cut, and the support lines are <b>screwed</b> securely to the outer cover.")
		if(COVER)
			return span_notice("The support lines have been <i>unscrewed</i>, and the metal cover is <b>welded</b> firmly in place.")
		if(CUT_COVER)
			return span_notice("The metal cover has been <i>sliced through</i>, and is <b>connected loosely</b> to the girder.")
		if(ANCHOR_BOLTS)
			return span_notice("The outer cover has been <i>pried away</i>, and the bolts anchoring the support rods are <b>wrenched</b> in place.")
		if(SUPPORT_RODS)
			return span_notice("The bolts anchoring the support rods have been <i>loosened</i>, but are still <b>welded</b> firmly to the girder.")
		if(SHEATH)
			return span_notice("The support rods have been <i>sliced through</i>, and the outer sheath is <b>connected loosely</b> to the girder.")

/turf/closed/wall/r_wall/devastate_wall()
	new sheet_type(src, sheet_amount)
	new /obj/item/stack/sheet/iron(src, 2)

/turf/closed/wall/r_wall/hulk_recoil(obj/item/bodypart/arm, mob/living/carbon/human/hulkman, damage = 41)
	return ..()

/turf/closed/wall/r_wall/try_decon(obj/item/W, mob/user, turf/T)
	//DECONSTRUCTION
	switch(d_state)
		if(INTACT)
			if(W.tool_behaviour == TOOL_WIRECUTTER)
				W.play_tool_sound(src, 100)
				d_state = SUPPORT_LINES
				update_appearance()
				to_chat(user, span_notice(LANG("turf.2db4e4b4", null)))
				return TRUE

		if(SUPPORT_LINES)
			if(W.tool_behaviour == TOOL_SCREWDRIVER)
				to_chat(user, span_notice(LANG("turf.ced2cc5e", null)))
				if(W.use_tool(src, user, 40, volume=100))
					if(!istype(src, /turf/closed/wall/r_wall) || d_state != SUPPORT_LINES)
						return TRUE
					d_state = COVER
					update_appearance()
					to_chat(user, span_notice(LANG("turf.044271e7", null)))
				return TRUE

			else if(W.tool_behaviour == TOOL_WIRECUTTER)
				W.play_tool_sound(src, 100)
				d_state = INTACT
				update_appearance()
				to_chat(user, span_notice(LANG("turf.c2013483", null)))
				return TRUE

		if(COVER)
			if(W.tool_behaviour == TOOL_WELDER)
				if(!W.tool_start_check(user, amount=2, heat_required = HIGH_TEMPERATURE_REQUIRED))
					return
				to_chat(user, span_notice(LANG("turf.d609b468", null)))
				if(W.use_tool(src, user, 60, volume=100))
					if(!istype(src, /turf/closed/wall/r_wall) || d_state != COVER)
						return TRUE
					d_state = CUT_COVER
					update_appearance()
					to_chat(user, span_notice(LANG("turf.13a3384c", null)))
				return TRUE

			if(W.tool_behaviour == TOOL_SCREWDRIVER)
				to_chat(user, span_notice(LANG("turf.2c269478", null)))
				if(W.use_tool(src, user, 40, volume=100))
					if(!istype(src, /turf/closed/wall/r_wall) || d_state != COVER)
						return TRUE
					d_state = SUPPORT_LINES
					update_appearance()
					to_chat(user, span_notice(LANG("turf.344640c2", null)))
				return TRUE

		if(CUT_COVER)
			if(W.tool_behaviour == TOOL_CROWBAR)
				to_chat(user, span_notice(LANG("turf.07626d8f", null)))
				if(W.use_tool(src, user, 100, volume=100))
					if(!istype(src, /turf/closed/wall/r_wall) || d_state != CUT_COVER)
						return TRUE
					d_state = ANCHOR_BOLTS
					update_appearance()
					to_chat(user, span_notice(LANG("turf.3cb3a5f9", null)))
				return TRUE

			if(W.tool_behaviour == TOOL_WELDER)
				if(!W.tool_start_check(user, amount=2, heat_required = HIGH_TEMPERATURE_REQUIRED))
					return
				to_chat(user, span_notice(LANG("turf.cabf836e", null)))
				if(W.use_tool(src, user, 60, volume=100))
					if(!istype(src, /turf/closed/wall/r_wall) || d_state != CUT_COVER)
						return TRUE
					d_state = COVER
					update_appearance()
					to_chat(user, span_notice(LANG("turf.3a2b5796", null)))
				return TRUE

		if(ANCHOR_BOLTS)
			if(W.tool_behaviour == TOOL_WRENCH)
				to_chat(user, span_notice(LANG("turf.b3d323d1", null)))
				if(W.use_tool(src, user, 40, volume=100))
					if(!istype(src, /turf/closed/wall/r_wall) || d_state != ANCHOR_BOLTS)
						return TRUE
					d_state = SUPPORT_RODS
					update_appearance()
					to_chat(user, span_notice(LANG("turf.946d094a", null)))
				return TRUE

			if(W.tool_behaviour == TOOL_CROWBAR)
				to_chat(user, span_notice(LANG("turf.5f8f8cac", null)))
				if(W.use_tool(src, user, 20, volume=100))
					if(!istype(src, /turf/closed/wall/r_wall) || d_state != ANCHOR_BOLTS)
						return TRUE
					d_state = CUT_COVER
					update_appearance()
					to_chat(user, span_notice(LANG("turf.85bd236a", null)))
				return TRUE

		if(SUPPORT_RODS)
			if(W.tool_behaviour == TOOL_WELDER)
				if(!W.tool_start_check(user, amount=2, heat_required = HIGH_TEMPERATURE_REQUIRED))
					return
				to_chat(user, span_notice(LANG("turf.d5829270", null)))
				if(W.use_tool(src, user, 100, volume=100))
					if(!istype(src, /turf/closed/wall/r_wall) || d_state != SUPPORT_RODS)
						return TRUE
					d_state = SHEATH
					update_appearance()
					to_chat(user, span_notice(LANG("turf.43e315af", null)))
				return TRUE

			if(W.tool_behaviour == TOOL_WRENCH)
				to_chat(user, span_notice(LANG("turf.6dc263b6", null)))
				W.play_tool_sound(src, 100)
				if(W.use_tool(src, user, 40))
					if(!istype(src, /turf/closed/wall/r_wall) || d_state != SUPPORT_RODS)
						return TRUE
					d_state = ANCHOR_BOLTS
					update_appearance()
					to_chat(user, span_notice(LANG("turf.df3b1ea5", null)))
				return TRUE

		if(SHEATH)
			if(W.tool_behaviour == TOOL_CROWBAR)
				to_chat(user, span_notice(LANG("turf.79850687", null)))
				if(W.use_tool(src, user, 100, volume=100))
					if(!istype(src, /turf/closed/wall/r_wall) || d_state != SHEATH)
						return TRUE
					to_chat(user, span_notice(LANG("turf.1e18af62", null)))
					dismantle_wall()
				return TRUE

			if(W.tool_behaviour == TOOL_WELDER)
				if(!W.tool_start_check(user, amount=0, heat_required = HIGH_TEMPERATURE_REQUIRED))
					return
				to_chat(user, span_notice(LANG("turf.98374a92", null)))
				if(W.use_tool(src, user, 100, volume=100))
					if(!istype(src, /turf/closed/wall/r_wall) || d_state != SHEATH)
						return TRUE
					d_state = SUPPORT_RODS
					update_appearance()
					to_chat(user, span_notice(LANG("turf.a69d2767", null)))
				return TRUE
	return FALSE

/turf/closed/wall/r_wall/update_icon(updates=ALL)
	. = ..()
	if(d_state != INTACT)
		smoothing_flags = NONE
		return
	if (!(updates & UPDATE_SMOOTHING))
		return
	smoothing_flags = SMOOTH_BITMASK
	QUEUE_SMOOTH_NEIGHBORS(src)
	QUEUE_SMOOTH(src)

// We don't react to smoothing changing here because this else exists only to "revert" intact changes
/turf/closed/wall/r_wall/update_icon_state()
	if(d_state != INTACT)
		icon = 'modular_nova/modules/aesthetics/walls/icons/reinforced_wall.dmi' // NOVA EDIT CHANGE - AESTHETICS - ORIGINAL: icon = 'icons/turf/walls/reinforced_states.dmi'
		icon_state = "[base_decon_state]-[d_state]"
	else
		icon = initial(icon)
		icon_state = "[base_icon_state]-[smoothing_junction]"
	return ..()

/turf/closed/wall/r_wall/wall_singularity_pull(current_size)
	if(current_size >= STAGE_FIVE)
		if(prob(30))
			dismantle_wall()

/turf/closed/wall/r_wall/rcd_vals(mob/user, obj/item/construction/rcd/the_rcd)
	if (the_rcd.construction_mode == RCD_WALLFRAME)
		return ..()
	if(!the_rcd.canRturf)
		return
	. = ..()
	if (.)
		.["delay"] *= RCD_RWALL_DELAY_MULT

/turf/closed/wall/r_wall/rcd_act(mob/user, obj/item/construction/rcd/the_rcd, list/rcd_data)
	if(the_rcd.canRturf || rcd_data[RCD_DESIGN_MODE] == RCD_WALLFRAME)
		return ..()

/turf/closed/wall/r_wall/rust_turf(magic = FALSE)
	if(HAS_TRAIT(src, TRAIT_RUSTY))
		ChangeTurf(/turf/closed/wall/rust)
		return TRUE
	return ..()

/turf/closed/wall/r_wall/plastitanium
	name = /turf/closed/wall/mineral/plastitanium::name
	desc = "An extra durable wall made of an alloy of plasma and titanium, reinforced with plasteel rods."
	icon = 'icons/turf/walls/plastitanium_wall.dmi'
	icon_state = "plastitanium_wall-0"
	base_icon_state = "plastitanium_wall"
	sheet_type = /obj/item/stack/sheet/mineral/plastitanium
	hardness = 25 //plastitanium
	turf_flags = IS_SOLID
	smoothing_flags = SMOOTH_BITMASK | SMOOTH_DIAGONAL_CORNERS
	smoothing_groups = SMOOTH_GROUP_WALLS + SMOOTH_GROUP_CLOSED_TURFS + SMOOTH_GROUP_SYNDICATE_WALLS
	canSmoothWith = SMOOTH_GROUP_SHUTTLE_PARTS + SMOOTH_GROUP_AIRLOCK + SMOOTH_GROUP_PLASTITANIUM_WALLS + SMOOTH_GROUP_SYNDICATE_WALLS
	rust_resistance = RUST_RESISTANCE_TITANIUM

/turf/closed/wall/r_wall/plastitanium/nodiagonal
	icon = MAP_SWITCH('icons/turf/walls/plastitanium_wall.dmi', 'icons/turf/walls/misc_wall.dmi')
	icon_state = MAP_SWITCH("plastitanium_wall-0", "plastitanium_nd")
	smoothing_flags = SMOOTH_BITMASK

/turf/closed/wall/r_wall/plastitanium/overspace
	icon = MAP_SWITCH('icons/turf/walls/plastitanium_wall.dmi', 'icons/turf/walls/misc_wall.dmi')
	icon_state = MAP_SWITCH("plastitanium_wall-0", "plastitanium_overspace")
	fixed_underlay = list("space" = TRUE)

/turf/closed/wall/r_wall/plastitanium/syndicate
	name = "hull"
	desc = "The armored hull of an ominous looking ship."
	explosive_resistance = 20

/turf/closed/wall/r_wall/plastitanium/syndicate/rcd_vals(mob/user, obj/item/construction/rcd/the_rcd)
	return FALSE

/turf/closed/wall/r_wall/plastitanium/syndicate/nodiagonal
	icon = MAP_SWITCH('icons/turf/walls/plastitanium_wall.dmi', 'icons/turf/walls/misc_wall.dmi')
	icon_state = MAP_SWITCH("plastitanium_wall-0", "plastitanium_nd")
	smoothing_flags = SMOOTH_BITMASK

/turf/closed/wall/r_wall/plastitanium/syndicate/overspace
	icon = MAP_SWITCH('icons/turf/walls/plastitanium_wall.dmi', 'icons/turf/walls/misc_wall.dmi')
	icon_state = MAP_SWITCH("plastitanium_wall-0", "plastitanium_overspace")
	fixed_underlay = list("space" = TRUE)
