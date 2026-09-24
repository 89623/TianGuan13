/// 天关赞助者配装（modular_tianguan/modules/sponsor_loadout_items）的解锁清单按 item_path 匹配上游条目。
/// 上游改名/删掉某条配装 datum 时编译照样通过（物品类型还在），解锁却会静默失效 ——
/// 这里逐条确认清单里的每个 item_path 都真的落到了一个已解锁的配装条目上。
/datum/unit_test/tianguan_sponsor_loadout

/datum/unit_test/tianguan_sponsor_loadout/Run()
	for(var/path in tianguan_sponsor_item_paths())
		var/datum/loadout_item/entry = GLOB.all_loadout_datums[path]
		if(isnull(entry))
			TEST_FAIL("赞助者解锁清单里的 [path] 没有对应的配装条目（上游改名或删除了？）")
			continue
		if(!entry.donator_only)
			TEST_FAIL("[entry.type]（[path]）应为 donator_only")
		if(LAZYLEN(entry.ckeywhitelist))
			TEST_FAIL("[entry.type]（[path]）的 ckeywhitelist 应已清空，实为 [jointext(entry.ckeywhitelist, ", ")]")

	// 本模块自建、不走清单的条目：donator_only 写在各自类型体里
	var/list/own_items = list(
		/obj/item/storage/box/balloons,
		/obj/item/skillchip/job/clown,
		/obj/item/holosign_creator/hardlight_wheelchair,
	)
	for(var/path in own_items)
		var/datum/loadout_item/entry = GLOB.all_loadout_datums[path]
		if(isnull(entry))
			TEST_FAIL("缺少天关自建赞助者配装条目：[path]")
			continue
		if(!entry.donator_only)
			TEST_FAIL("天关自建赞助者配装条目 [entry.type] 应为 donator_only")
