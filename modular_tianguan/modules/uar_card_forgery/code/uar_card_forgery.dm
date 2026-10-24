/**
 * 让特工卡（/obj/item/card/id/advanced/chameleon）能变造出「团结联盟审查官」的卡
 *
 * 特工卡有两把「变造」action，各自维护一份写死的可选项清单：
 *   /datum/action/item_action/chameleon/change/id        —— 外观（卡类型：卡面图集 + icon_state + trim）
 *   /datum/action/item_action/chameleon/change/id_trim   —— 印花（id_trim：徽记/部门色/secHUD）
 * 清单在各自的 initialize_disguises() 里写死；天关的卡是模块新增类型，一条都不在里面，
 * 所以游戏里无论怎么点都变不出审查官样式的卡。
 *
 * 本模块用「..() + 追加」的方式覆写这两个 proc，**不修改任何核心文件**（不需要 TIANGUAN EDIT），
 * 上游就算改了清单内容，我们的追加项也照样生效。
 */

/// 要放进特工卡「外观」菜单的卡：行政ID（= 审查官开局那张，卡面 dmi 在 uar_officer 模块里）
#define UAR_FORGEABLE_CARDS list(/obj/item/card/id/advanced/uar_admin)
/// 要放进特工卡「印花」菜单的 id_trim：审查官 trim
#define UAR_FORGEABLE_TRIMS list(/datum/id_trim/job/uar_inspector)

// ———————————————————————————————— 外观（整张卡）
/datum/action/item_action/chameleon/change/id/initialize_disguises()
	. = ..()
	add_chameleon_items(UAR_FORGEABLE_CARDS, only_root = TRUE)

/datum/action/item_action/chameleon/change/id/update_item(obj/item/picked_item)
	. = ..()
	var/obj/item/card/id/advanced/chameleon/agent_card = target
	var/obj/item/card/id/copied_card = picked_item
	// 上游只抄 icon_state，不抄 icon（卡面图集）。天关的卡用模块自带 dmi，
	// 不补这一下，卡面就会去默认图集里找 "card_uar_admin" 这个不存在的状态 ⇒ 空白卡。
	agent_card.icon = initial(copied_card.icon) || /obj/item/card/id/advanced/chameleon::icon
	agent_card.update_appearance(UPDATE_ICON)

// ———————————————————————————————— 印花（id_trim）
/// 上游那份清单是 initialize_disguises() 里的局部变量，追加不进去，所以这里照它的判定条件再走一遍。
/datum/action/item_action/chameleon/change/id_trim/initialize_disguises()
	. = ..()
	for(var/trim_path in typecacheof(UAR_FORGEABLE_TRIMS))
		if(is_type_in_typecache(trim_path, chameleon_blacklist))
			continue
		var/datum/id_trim/trim = SSid_access.trim_singletons_by_path[trim_path]
		if(trim?.trim_state && trim.assignment)
			chameleon_list[format_readable_name(trim)] = trim_path
			chameleon_typecache[trim_path] = TRUE

#undef UAR_FORGEABLE_CARDS
#undef UAR_FORGEABLE_TRIMS
