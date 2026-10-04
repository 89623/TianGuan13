// THIS IS A TIANGUAN MODULE FILE
// 模块：liquid_siphon —— 轻量化液体虹吸器
//
// 定位：一台**用零件造出来**的便携吸液机 —— 吸取周围地面上的液体并**直接消除**（不存储、不转移）。
//       与仓库里那台「靠魔法工作」的便携液体泵互补：那台是结构、无电源、只能在自身一格上百分比吸吐；
//       本机是正规机器：有电池、有零件等级、可框范围、有 TGUI 面板。
//
// 等级（由装进去的零件决定，面板里可**向下**选择以省电）：
//   扫描模块 → 范围：1 级=仅本格 / 2 级=3×3 / 3 级=5×5 / 4 级=7×7
//   物质仓   → 速率：1 级=10 / 2 级=25 / 3 级=50 / 4 级=100（单位/秒，每格）
//   电池     → 运行时每 3 秒消耗 1 kJ（= 每秒 1000/3 焦耳；满电续航见下方宏注释）
//
// 零件等级取法：同类 3 个零件取**平均等级**后向下取整、钳到 1~4（装整套同级零件时即该等级）。
//
// 建造：电路板只需 3 扫描模块 + 3 物质仓；电池**不是**建造零件，造好后手持电池左键装入。
//
// 贴图：本模块暂无专属贴图，按需求沿用气体虹吸器（/obj/machinery/portable_atmospherics/pump）那套 ——
//       同为 icons/obj/pipes_n_cables/atmos.dmi 的 siphon_0（关）/ siphon_1（开，4 帧动画）。
//
// ⚠️ 规格未写明、由实现自行取定的一点（如需改动很便宜）：
//   1 级范围的「设备下一格」按【机器自己所在的那一格】实现（不额外向下取格）。

/// 范围等级 → 边长（格）
#define SIPHON_RANGE_SIDES list(1, 3, 5, 7)
/// 速率等级 → 单位/秒（每格）
#define SIPHON_RATES list(10, 25, 50, 100)
/// 耗电：每 3 秒 1 kJ —— 本仓 1 充能单位 = 1 焦耳（见 code/__DEFINES/power.dm：
/// STANDARD_CELL_CHARGE = (10 KILO) JOULES ⇒ 标准电池 10 kJ），故每秒消耗 1000/3 焦耳。
/// ⚠️ 由此的续航（按电池容量，实时值见面板原始电量）：
///   标准 10 kJ ⇒ 约 30 秒 ／ 升级 25 kJ ⇒ 约 75 秒 ／ 高容 50 kJ ⇒ 约 150 秒 ／ 超级 400 kJ ⇒ 约 20 分钟。
#define SIPHON_JOULES_PER_SECOND (1000 / 3.0)
/// 等级上限（= 四级零件）
#define SIPHON_MAX_TIER 4

/obj/machinery/light_liquid_siphon
	name = "轻量化液体虹吸器"
	desc = "星狐工业发明，与纳米传讯合作进行便携化改造的设备。其前身是用于海洋世界行星改造工程的特种设备。开启后可快速吸取并消除泄露的液体"
	icon = 'icons/obj/pipes_n_cables/atmos.dmi'
	icon_state = "siphon"
	density = TRUE
	anchored = FALSE
	layer = ABOVE_OBJ_LAYER
	use_power = NO_POWER_USE
	max_integrity = 250
	circuit = /obj/item/circuitboard/machine/light_liquid_siphon
	interaction_flags_click = NEED_DEXTERITY
	/// 是否运行中
	var/on = FALSE
	/// 电池（手持电池左键机器装进去；面板里可弹出）
	var/obj/item/stock_parts/power_store/cell/cell
	/// 面板里选择的范围等级（1 .. max_range_tier）
	var/range_tier = 1
	/// 面板里选择的速率等级（1 .. max_rate_tier）
	var/rate_tier = 1
	/// 零件决定的最高范围等级
	var/max_range_tier = 1
	/// 零件决定的最高速率等级
	var/max_rate_tier = 1

/obj/machinery/light_liquid_siphon/RefreshParts()
	. = ..()
	var/range_total = 0
	var/range_count = 0
	var/bin_total = 0
	var/bin_count = 0
	for(var/datum/stock_part/scanning_module/scanner in component_parts)
		range_total += scanner.tier
		range_count++
	for(var/datum/stock_part/matter_bin/bin in component_parts)
		bin_total += bin.tier
		bin_count++
	max_range_tier = clamp(range_count ? FLOOR(range_total / range_count, 1) : 1, 1, SIPHON_MAX_TIER)
	max_rate_tier = clamp(bin_count ? FLOOR(bin_total / bin_count, 1) : 1, 1, SIPHON_MAX_TIER)
	range_tier = clamp(range_tier, 1, max_range_tier) // 换零件后把选择钳回合法范围
	rate_tier = clamp(rate_tier, 1, max_rate_tier)

/obj/machinery/light_liquid_siphon/update_icon_state()
	icon_state = "[initial(icon_state)]_[on]"
	return ..()

/obj/machinery/light_liquid_siphon/examine(mob/user)
	. = ..()
	. += span_notice("当前状态：[on ? "运行中" : "已停止"]。")
	. += span_notice("电量：[cell ? "[round(cell.percent())]%" : "无电池"]。")
	. += span_notice("当前范围 [SIPHON_RANGE_SIDES[range_tier] == 1 ? "仅本格" : "[SIPHON_RANGE_SIDES[range_tier]]×[SIPHON_RANGE_SIDES[range_tier]]"]、速率 [SIPHON_RATES[rate_tier]] 单位/秒。")

/obj/machinery/light_liquid_siphon/process(seconds_per_tick)
	if(!on)
		return
	if(!is_operational)
		turn_off()
		return
	if(!cell || !cell.use(seconds_per_tick * SIPHON_JOULES_PER_SECOND))
		visible_message(span_warning("[src] 的电池耗尽了。"))
		turn_off()
		return
	var/turf/center = get_turf(src)
	if(!center)
		return
	var/side = SIPHON_RANGE_SIDES[range_tier]
	var/radius = max((side - 1) / 2, 0)
	var/per_tile = SIPHON_RATES[rate_tier] * seconds_per_tick
	for(var/turf/target as anything in RANGE_TURFS(radius, center))
		siphon_turf(target, per_tile)

/// 从一格地面吸取至多 amount 单位并**直接消除**；返回实际消除量
/obj/machinery/light_liquid_siphon/proc/siphon_turf(turf/target, amount)
	if(!target?.liquids || !target.liquids.total_reagents)
		return 0
	var/taken = min(amount, target.liquids.total_reagents)
	if(taken <= 0)
		return 0
	var/datum/reagents/pulled = target.liquids.take_reagents_flat(taken)
	if(!pulled)
		return 0
	. = pulled.total_volume
	qdel(pulled)

/obj/machinery/light_liquid_siphon/proc/turn_on()
	if(on)
		return
	on = TRUE
	START_PROCESSING(SSmachines, src)
	update_appearance()

/obj/machinery/light_liquid_siphon/proc/turn_off()
	if(!on)
		return
	on = FALSE
	STOP_PROCESSING(SSmachines, src)
	update_appearance()

/obj/machinery/light_liquid_siphon/proc/toggle()
	if(on)
		turn_off()
	else
		turn_on()

/// 弹出电池（面板按钮）：优先塞进使用者手里，塞不下就掉在地上
/obj/machinery/light_liquid_siphon/proc/eject_cell(mob/user)
	if(!cell)
		return FALSE
	var/obj/item/stock_parts/power_store/cell/ejected = cell
	cell = null
	ejected.add_fingerprint(user)
	if(!user || !user.put_in_hands(ejected))
		ejected.forceMove(drop_location())
	update_appearance()
	return TRUE

/obj/machinery/light_liquid_siphon/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(.)
		return
	ui_interact(user)

/obj/machinery/light_liquid_siphon/wrench_act(mob/living/user, obj/item/tool)
	default_unfasten_wrench(user, tool)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/light_liquid_siphon/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stock_parts/power_store/cell))
		return ..()
	if(cell)
		balloon_alert(user, "已有电池！")
		return ITEM_INTERACT_BLOCKING
	if(!user.transferItemToLoc(tool, src))
		return ITEM_INTERACT_BLOCKING
	cell = tool
	cell.add_fingerprint(user)
	balloon_alert(user, "已装入电池")
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/machinery/light_liquid_siphon/Destroy()
	turn_off()
	if(cell)
		QDEL_NULL(cell)
	return ..()

/obj/machinery/light_liquid_siphon/on_deconstruction(disassembled)
	if(cell)
		cell.forceMove(drop_location())
		cell = null
	return ..()

// ───────────────────────── TGUI ─────────────────────────

/obj/machinery/light_liquid_siphon/ui_state(mob/user)
	return GLOB.physical_state

/obj/machinery/light_liquid_siphon/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TianGuanLiquidSiphon")
		ui.open()

/obj/machinery/light_liquid_siphon/ui_data(mob/user)
	var/list/data = list()
	data["on"] = on
	data["has_cell"] = !!cell
	data["cell_name"] = cell ? cell.name : null
	data["cell_charge"] = cell ? round(cell.percent()) : 0
	// 原始电量一并给前端：1 kJ/3s 对一块标准电池而言百分比几乎不动，
	// 只显示百分比会让人以为没在耗电，故把原始数值也显示出来（每 3 秒能看见 -1）
	data["cell_raw"] = cell ? round(cell.charge) : 0
	data["cell_max"] = cell ? cell.maxcharge : 0
	data["range_tier"] = range_tier
	data["rate_tier"] = rate_tier
	data["max_range_tier"] = max_range_tier
	data["max_rate_tier"] = max_rate_tier
	data["range_sides"] = SIPHON_RANGE_SIDES
	data["rates"] = SIPHON_RATES
	return data

/obj/machinery/light_liquid_siphon/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	switch(action)
		if("toggle")
			if(on)
				turn_off()
			else if(!cell)
				balloon_alert(usr, "没有电池！")
			else if(!is_operational)
				balloon_alert(usr, "机器无法运行！")
			else
				turn_on()
		if("set_range")
			range_tier = clamp(text2num(params["tier"]) || 1, 1, max_range_tier)
		if("set_rate")
			rate_tier = clamp(text2num(params["tier"]) || 1, 1, max_rate_tier)
		if("eject_cell")
			if(!eject_cell(usr))
				balloon_alert(usr, "没有电池！")
	return TRUE

// ───────────────────────── 电路板 / 制造 ─────────────────────────

/obj/item/circuitboard/machine/light_liquid_siphon
	name = "轻量化液体虹吸器电路板"
	greyscale_colors = CIRCUIT_COLOR_ENGINEERING
	build_path = /obj/machinery/light_liquid_siphon
	needs_anchored = FALSE
	req_components = list(
		/datum/stock_part/scanning_module = 3,
		/datum/stock_part/matter_bin = 3,
	)

/datum/design/board/light_liquid_siphon
	name = "轻量化液体虹吸器电路板"
	desc = "用于组装一台轻量化液体虹吸器。"
	build_path = /obj/item/circuitboard/machine/light_liquid_siphon
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ATMOS
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_ENGINEERING
