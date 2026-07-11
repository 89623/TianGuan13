/datum/crafting_recipe/pneumatic_cannon/junkcannon
	name = "Junk Cannon"
	result = /obj/item/pneumatic_cannon/junkcannon
	reqs = list(
		/obj/item/stack/sheet/iron = 4,
		/obj/item/stack/package_wrap = 8,
		/obj/item/pipe = 2,
		/obj/item/stack/sheet/bluespace_crystal = 1,
		/obj/item/tank/internals/oxygen = 1,
		/obj/item/stock_parts/servo = 1,
		/obj/item/stack/cable_coil = 10
	)
	tool_behaviors = list(TOOL_WELDER, TOOL_WRENCH)
	time = 50
	category = CAT_WEAPON_RANGED