/datum/crafting_recipe/gun/energy/gear_disabler
	name = "gear disabler"
	result = /obj/item/gun/energy/gear_disabler
	reqs = list(
		/obj/item/gun/energy/disabler/smoothbore = 1,
		/obj/item/stack/cable_coil = 5,
		/obj/item/stack/sheet/bronze = 5,
		/obj/item/stock_parts/capacitor = 2,
		/obj/item/assembly/timer = 1,
	)
	tool_behaviors = list(TOOL_SCREWDRIVER, TOOL_WRENCH)
	time = 50
	category = CAT_WEAPON_RANGED