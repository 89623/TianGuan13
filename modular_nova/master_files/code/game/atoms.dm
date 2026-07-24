// Stop All Animations nulls the mob's transform, so we have to call update_body_size to ensure that it gets scaled properly again
/atom/vv_do_topic(list/href_list)
	. = ..()
	if(href_list[VV_HK_STOP_ALL_ANIMATIONS] && check_rights(R_VAREDIT))
		var/mob/living/carbon/human/human_mob = src
		if(!istype(human_mob))
			return

		human_mob.dna.update_body_size(force_reapply = TRUE)

/// Called after a loadout item gets custom named
/atom/proc/on_loadout_custom_named()
	return

/// Called after a loadout item gets a custom description
/atom/proc/on_loadout_custom_described()
	return

// i18n: 在 Initialize 期把静态 name/desc 整串反查为全服 locale 的译文。
// 仅当全服 locale 非缺省（en）时生效；查不到的（玩家自定义名、运行时拼接名）原样保留。
// 这一层让「变量类」文本（物品名/描述）能显示中文——它们无法直接改写成 LANG()。
// 排除 /obj/effect/landmark：地标 name 是**匹配标识符**（SSjob 按 name == job.title 找职业
// 出生点 start landmark），翻译会让出生点匹配失败、职业出生错位；地标不可见，玩家永远看不到其名。
/atom/Initialize(mapload, ...)
	. = ..()
	// i18n_locale_resolved 门：少数 atom 在 GLOB 阶段就被建出来（管理员状态栏的 /obj/effect/statclick
	// 占位对象——opfor_list / ticket_list / sdql2_vv_all），SSatoms 会立刻 InitAtom 它们，此时 config
	// 还没读、locale 恒为 en，这里翻不动。无实际影响：那些名字（"Initializing..." 等）随后由状态栏
	// 逻辑动态覆盖。写成显式条件只为不让早调用告警把它们当新问题反复报出来。
	if(GLOB.i18n_locale_resolved && GLOB.i18n_server_locale != DEFAULT_UI_LOCALE && !istype(src, /obj/effect/landmark))
		if(name)
			name = lang_reverse_text(name)
		if(desc)
			desc = lang_reverse_text(desc)
