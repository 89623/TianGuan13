/obj/vehicle/sealed/car/sedan
	name = "轿车"
	desc = "四人座的轿车，不用考科目3就能上手"
	icon = 'modular_z121/icons/mob/rideables/vehicles48x.dmi'
	icon_state = "sedan"
	pixel_x = -8
	max_integrity = 150
	enter_delay = 1 SECONDS
	escape_time = 0 SECONDS
	max_occupants = 4
	movedelay = 0.6
	armor_type = /datum/armor/sedan
	key_type = /obj/item/key/car
	light_system = OVERLAY_LIGHT_DIRECTIONAL
	light_range = 6
	light_power = 2
	light_on = FALSE
	enter_sound = 'sound/vehicles/clown_car/door_close.ogg'
	exit_sound = 'sound/vehicles/clown_car/door_open.ogg'

/obj/vehicle/examine(mob/user)
	. = ..()
	var/examine_text = ""
	var/integrity = occupant_amount()
	if(!integrity)
		examine_text = "这辆车看上去里面没人"
	else
		examine_text = "这辆车看上去里面有<b>[integrity]<b>人"

	. += examine_text

/obj/vehicle/sealed/car/sedan/generate_actions()
	. = ..()
	initialize_controller_action_type(/datum/action/vehicle/sealed/headlights, VEHICLE_CONTROL_DRIVE)

/datum/armor/sedan
	melee = 50
	bullet = 30
	laser = 25
	bomb = 50
	fire = 80
	acid = 80

/obj/vehicle/sealed/car/sedan/Bump(atom/bumped_atom)
	. = ..()
	if(!isliving(bumped_atom))
		return
	var/mob/living/mob = bumped_atom
	mob.throw_at(get_edge_target_turf(mob, dir), 2, 3, bumped_atom, gentle = TRUE)	// 轻轻一撞，而不是往死里撞
	mob.visible_message(
		span_danger("[src]轻轻的撞飞了[mob]！"),
		span_danger("[src]轻轻的撞飞了你！"),
	)
	playsound(src, 'sound/items/weapons/genhit.ogg', 25, TRUE)

/obj/vehicle/sealed/car/sedan/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(!occupant_amount())
		to_chat(user, span_notice("你准备动手打开车门，却发现里面空无一人..."))
		return

	var/var/mob/living/target_pull = show_radial_menu(user, src, occupants, require_near = TRUE)

	if(!target_pull)
		return
	user.visible_message(
		span_danger("[user]正在尝试打开[src]的车门！"),
		span_danger("你开始打开[src]的车门！"),
	)
	to_chat(target_pull, span_userdanger("[user]正在打开那一侧的车门！"))

	if(!do_after(user, 30))
		return

	if(!(isliving(target_pull) && is_occupant(target_pull)))
		return

	mob_try_exit(target_pull)
	if(iscarbon(target_pull))
		var/mob/living/carbon/C = target_pull
		C.Paralyze(40)

	target_pull.visible_message(
		span_danger("[user]把[target_pull]从[src]里拽出来了！"),
		span_userdanger("你被[user]从[src]里拽出来了！"),
	)
