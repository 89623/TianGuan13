/obj/item/pneumatic_cannon/junkcannon
	name = "Junk Cannon"
	desc = "The invention of the Clown Planet relies on a bluespace polycrystal to connect with the garbage dimension, allowing for the unlimited emission of garbage, honk!!"
	icon = 'modular_z121/icons/obj/guns/junkcannon.dmi'
	icon_state = "junkcannon"
	automatic = TRUE
	selfcharge = TRUE
	//charge_type = /obj/item/trash/chips
	//charge_amount = 100
	maxWeightClass = 10
	force = 10
	gasPerThrow = 0
	range_multiplier = 1
	throw_amount = 1
	needs_air = FALSE
	clumsyCheck = FALSE
	var/static/list/junk_paths = list(
        /obj/item/trash/chips,
    	/obj/item/trash/candy,
		/obj/item/trash/raisins,
		/obj/item/trash/cheesie,
		/obj/item/trash/shrimp_chips,
		/obj/item/trash/boritos,
		/obj/item/trash/popcorn,
		/obj/item/trash/sosjerky,
		/obj/item/trash/syndi_cakes,
		/obj/item/trash/energybar,
		/obj/item/trash/fleet_ration,
		/obj/item/trash/pistachios,
		/obj/item/trash/semki,
		/obj/item/trash/tray,
		/obj/item/trash/candle,
		/obj/item/trash/flare,
		/obj/item/trash/can,
		/obj/item/trash/can/food,
		/obj/item/trash/can/food/peaches,
		/obj/item/trash/can/food/beans,
		/obj/item/trash/peanuts,
		/obj/item/trash/cnds,
		/obj/item/trash/can/food/envirochow,
		/obj/item/trash/can/food/tomatoes,
		/obj/item/trash/can/food/pine_nuts,
		/obj/item/trash/can/food/jellyfish,
		/obj/item/trash/can/food/desert_snails,
		/obj/item/trash/can/food/larvae,
		/obj/item/trash/spacers_sidekick,
		/obj/item/trash/ready_donk,
		/obj/item/trash/can/food/squid_ink,
		/obj/item/trash/can/food/chap,
		/obj/item/trash/hot_shots,
		/obj/item/trash/sticko,
		/obj/item/trash/sticko/matcha,
		/obj/item/trash/sticko/nutty,
		/obj/item/trash/sticko/pineapple,
		/obj/item/trash/sticko/yuyake,
		/obj/item/trash/shok_roks,
		/obj/item/trash/shok_roks/citrus,
		/obj/item/trash/shok_roks/berry,
		/obj/item/reagent_containers/cup/glass/drinkingglass,
		/obj/item/shard,
		/obj/item/assembly/mousetrap,
		/obj/item/broken_bottle,
		/obj/item/light/tube/broken,
		/obj/item/light/bulb/broken,
		/obj/item/food/breadslice/moldy/bacteria,
		/obj/item/food/deadmouse/moldy,
		/obj/item/crowbar,
		/obj/item/wrench,
		/obj/item/screwdriver,
		/obj/item/weldingtool,
		/obj/item/wirecutters,
		/obj/item/food/monkeycube,
		/obj/item/organ/tail/monkey,
		/obj/item/organ/tongue/monkey,
		/obj/item/stack/sheet/animalhide/carbon/monkey,
		/obj/item/organ/brain/primate,
		/obj/item/food/meat/slab/monkey,
		/obj/item/organ/appendix,
		/obj/item/organ/eyes,
		/obj/item/organ/ears,
		/obj/item/organ/stomach,
		/obj/item/organ/heart,
		/obj/item/organ/liver,
		/obj/item/grown/bananapeel
	)

/obj/item/pneumatic_cannon/junkcannon/process()
	charge_tick++
	if(charge_tick >= charge_ticks)
		charge_tick = 0
		var/chosen = pick(junk_paths)
		fill_with_type(chosen, charge_amount)
