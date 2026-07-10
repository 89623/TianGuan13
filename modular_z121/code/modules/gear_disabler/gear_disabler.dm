/obj/item/gun/energy/gear_disabler
	name = "gear disabler"
	desc = "A cleverly designed stun gun that seamlessly links time and energy to automatically recharge itself."
	icon = 'modular_z121/icons/obj/guns/gear_disabler.dmi'
	icon_state = "gear_disabler"
	lefthand_file = 'icons/mob/inhands/weapons/guns_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/weapons/guns_righthand.dmi'
	inhand_icon_state = "smoothbore_prime0"
	ammo_type = list(/obj/item/ammo_casing/energy/disabler)
	selfcharge = TRUE
	charge_sections = 6
	shaded_charge = 1
	var/recharge_interval = 2 SECONDS
	var/last_recharge_time = 0

/obj/item/gun/energy/gear_disabler/Initialize(mapload)
	. = ..()
	var/obj/item/ammo_casing/energy/disabler/shot = ammo_type[1]
	var/cost = shot.e_cost
	if(cell)
		cell.maxcharge = cost * 6
		cell.charge = cell.maxcharge
	last_recharge_time = world.time
	update_appearance()

/obj/item/gun/energy/gear_disabler/process(seconds_per_tick)
	if(!cell || cell.percent() >= 100)
		return
	if(world.time >= last_recharge_time + recharge_interval)
		var/obj/item/ammo_casing/energy/disabler/shot = ammo_type[1]
		var/cost = shot.e_cost
		cell.give(cost)
		last_recharge_time = world.time
		update_appearance()