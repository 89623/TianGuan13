// THIS IS A TIANGUAN MODULE FILE
// 模块：admin_countdown —— 管理员「全局倒计时」面板
//
// 用途：管理员在「秘密」面板里打开本模块界面后，可向**所有玩家**屏幕推送一个倒计时提示：
//   标题（可选） + 倒计时 + 结束后出现的文本（可选） + 结束文本持续时长（可选）。
//   纯演出，不产生任何玩法效果（不判胜负、不触发事件、不改状态机）。
//
// 显示层复用与回合结束倒计时（`/atom/movable/screen/reboot_timer`，见 code/__HELPERS/roundend.dm）
// 完全相同的做法：一个 maptext 屏幕元素 + MAPTEXT_PIXELLARI 描边字体，位置/尺寸同款。
// 差异：那个元素由 ticker 每 tick 刷新、且只在回合结束后挂载；本模块自带状态机与 1 秒循环，
//   自己负责挂载/摘除，因此**不需要动任何核心文件**（连登录挂载钩子都不用 —— 循环里顺带补挂到新客户端）。
//
// 状态机：IDLE（未设置，屏幕上什么都没有）→ RUNNING（倒计时中）⇄ PAUSED（暂停，时间冻结）
//         → ENDTEXT（显示结束文本，倒计时结束）→ 到期后自动回到 IDLE。

GLOBAL_DATUM(tianguan_countdown, /datum/tianguan_countdown)

#define TIANGUAN_CD_IDLE 0
#define TIANGUAN_CD_RUNNING 1
#define TIANGUAN_CD_PAUSED 2
#define TIANGUAN_CD_ENDTEXT 3

/// 屏幕元素：与回合结束的 reboot_timer 同款（同位置、同尺寸、同字体描边）
/atom/movable/screen/tianguan_countdown
	screen_loc = "CENTER:-140,TOP:-42"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	maptext_width = 340
	maptext_height = 64
	maptext = ""
	layer = SCREENTIP_LAYER //This is basically an extra screentip

/// 取（懒创建）全局控制器
/proc/tianguan_countdown_controller()
	if(!GLOB.tianguan_countdown)
		GLOB.tianguan_countdown = new /datum/tianguan_countdown()
	return GLOB.tianguan_countdown

/// 秘密面板入口：只处理「打开倒计时面板」这一个动作，其余动作交回面板原逻辑。
/// 返回 TRUE 表示本模块已处理（核心那份 ui_act 会直接 return）。
/proc/tianguan_countdown_ui_act(action, list/params, client/holder)
	if(action != "tianguan_countdown_open" || !holder)
		return FALSE
	var/datum/tianguan_countdown_ui/ui = holder.tianguan_countdown_ui
	if(!ui)
		ui = new /datum/tianguan_countdown_ui(holder)
		holder.tianguan_countdown_ui = ui
	ui.ui_interact(holder.mob)
	return TRUE

/datum/tianguan_countdown
	/// IDLE / RUNNING / PAUSED / ENDTEXT
	var/state = TIANGUAN_CD_IDLE
	/// 倒计时上方那行标题（管理员自填，可为空）
	var/title = ""
	/// 倒计时结束后显示的文本（可为空；为空则结束后直接收工）
	var/end_text = ""
	/// 剩余倒计时（分秒）
	var/remaining = 0
	/// 结束文本剩余显示时长（分秒）
	var/end_remaining = 0
	/// 倒计时截止时刻（world.time；运行中以它为准反推剩余）
	var/running_deadline = 0
	/// 结束文本截止时刻（world.time）
	var/end_deadline = 0
	/// 结束文本总时长（秒，界面回显用）
	var/end_seconds = 0
	/// 标题颜色（#RRGGBB / #RGB / 常用色名；非法值回退白色）
	var/title_color = "#FFFFFF"
	/// 倒计时颜色（同上）
	var/countdown_color = "#FFFFFF"
	/// 结束文本颜色（同上）
	var/end_color = "#FFFFFF"
	var/atom/movable/screen/tianguan_countdown/hud
	var/timer_id

/datum/tianguan_countdown/New()
	. = ..()
	hud = new()

/datum/tianguan_countdown/Destroy()
	if(timer_id)
		deltimer(timer_id)
		timer_id = null
	for(var/client/player as anything in GLOB.clients)
		player?.screen -= hud
	QDEL_NULL(hud)
	return ..()

/// 开始（或按新参数重开）倒计时
/datum/tianguan_countdown/proc/begin(new_title, seconds, new_end_text, new_end_seconds)
	if(timer_id)
		deltimer(timer_id)
		timer_id = null // 必须清空：start_ticking() 以它作守卫，残留会导致新循环起不来
	state = TIANGUAN_CD_RUNNING
	title = new_title || ""
	remaining = max(round(seconds), 1) * 10
	end_text = new_end_text || ""
	end_seconds = max(round(new_end_seconds), 0)
	end_remaining = end_seconds * 10
	running_deadline = world.time + remaining
	end_deadline = 0
	start_ticking()
	refresh_all()

/// 暂停 ⇄ 继续（只在倒计时阶段有意义）
/datum/tianguan_countdown/proc/toggle_pause()
	if(state == TIANGUAN_CD_RUNNING)
		remaining = max(running_deadline - world.time, 0) // 冻结在当前值
		running_deadline = 0
		state = TIANGUAN_CD_PAUSED
	else if(state == TIANGUAN_CD_PAUSED)
		running_deadline = world.time + remaining // 从冻结值继续
		state = TIANGUAN_CD_RUNNING
	else
		return
	refresh_all()

/// 结束：文本与计时全部消失，回到「未进行任何设置」
/datum/tianguan_countdown/proc/stop()
	if(timer_id)
		deltimer(timer_id)
		timer_id = null
	state = TIANGUAN_CD_IDLE
	title = ""
	end_text = ""
	remaining = 0
	end_remaining = 0
	end_seconds = 0
	running_deadline = 0
	end_deadline = 0
	if(hud)
		hud.maptext = ""
	for(var/client/player as anything in GLOB.clients)
		player?.screen -= hud

/// 颜色校验：只接受 #RGB/#RGBA/#RRGGBB/#RRGGBBAA 或少量常用色名；
/// 非法值一律回退白色 —— 颜色会被拼进 maptext 的内联 CSS，不校验等于把任意字符串塞进 HTML。
/proc/tianguan_countdown_sanitize_color(color)
	if(!istext(color))
		return "#FFFFFF"
	color = lowertext(trim(color))
	if(!length(color))
		return "#FFFFFF"
	if(copytext(color, 1, 2) == "#")
		var/body = copytext(color, 2)
		if(!(length(body) in list(3, 4, 6, 8)))
			return "#FFFFFF"
		for(var/index in 1 to length(body))
			if(!findtext("0123456789abcdef", copytext(body, index, index + 1)))
				return "#FFFFFF"
		return color
	if(color in list("white", "black", "red", "green", "blue", "yellow", "orange", "purple", "pink", "cyan", "gray", "grey", "gold", "silver", "maroon", "navy", "teal", "olive", "lime", "aqua", "fuchsia"))
		return color
	return "#FFFFFF"

/datum/tianguan_countdown/proc/set_title_color(new_color)
	title_color = tianguan_countdown_sanitize_color(new_color)
	refresh_all()

/datum/tianguan_countdown/proc/set_countdown_color(new_color)
	countdown_color = tianguan_countdown_sanitize_color(new_color)
	refresh_all()

/datum/tianguan_countdown/proc/set_end_color(new_color)
	end_color = tianguan_countdown_sanitize_color(new_color)
	refresh_all()

/// 按类别读取颜色（"title" / "countdown" / "end"）
/datum/tianguan_countdown/proc/get_color(color_kind)
	switch(color_kind)
		if("title")
			return title_color
		if("countdown")
			return countdown_color
		if("end")
			return end_color
	return "#FFFFFF"

/datum/tianguan_countdown/proc/set_title(new_title)
	title = new_title || ""
	refresh_all()

/datum/tianguan_countdown/proc/set_end_text(new_text)
	end_text = new_text || ""
	refresh_all()

/// 1 秒一跳的循环：推进状态、补挂新客户端、刷新 maptext
/datum/tianguan_countdown/proc/start_ticking()
	if(timer_id)
		return
	timer_id = addtimer(CALLBACK(src, PROC_REF(tick)), 1 SECONDS, TIMER_LOOP | TIMER_STOPPABLE)

/datum/tianguan_countdown/proc/tick()
	if(state == TIANGUAN_CD_IDLE)
		if(timer_id)
			deltimer(timer_id)
			timer_id = null
		return
	// ★ 剩余一律由"截止时刻 − 当前世界时间"反推，而不是"每跳减 10"：
	//   tg 的计时器在服务器卡顿/补跳时可能短时间内连触发数次（玩家实测"偶发快一倍多"），
	//   逐跳累减会把这类抖动累积成误差；以截止时刻为准 ⇒ 与真实时间始终一致，且卡顿后自动追上。
	if(state == TIANGUAN_CD_RUNNING)
		remaining = max(running_deadline - world.time, 0)
		if(remaining <= 0)
			if(end_text && end_seconds > 0)
				state = TIANGUAN_CD_ENDTEXT
				end_remaining = end_seconds * 10
				end_deadline = world.time + end_remaining
			else
				stop()
				return
	else if(state == TIANGUAN_CD_ENDTEXT)
		end_remaining = max(end_deadline - world.time, 0)
		if(end_remaining <= 0)
			stop()
			return
	refresh_all()

/// 挂到所有客户端（顺带收编新登录的玩家 —— 故无需核心登录钩子）+ 刷新文本
/datum/tianguan_countdown/proc/refresh_all()
	for(var/client/player as anything in GLOB.clients)
		if(QDELETED(player))
			continue
		if(!(hud in player.screen))
			player.screen += hud
	if(hud)
		hud.maptext = build_maptext()

/datum/tianguan_countdown/proc/build_maptext()
	if(state == TIANGUAN_CD_IDLE)
		return ""
	if(state == TIANGUAN_CD_ENDTEXT)
		return MAPTEXT_PIXELLARI("<center><span style='color: [end_color]'>[end_text]</span></center>")
	var/list/lines = list()
	if(title)
		lines += "<span style='color: [title_color]'>[title]</span>"
	if(state == TIANGUAN_CD_PAUSED)
		lines += "<span style='color: [countdown_color]'>已暂停 [DisplayTimeText(remaining, 1)]</span>"
	else
		lines += "<span style='color: [countdown_color]'>[DisplayTimeText(remaining, 1)]</span>"
	return MAPTEXT_PIXELLARI("<center>[lines.Join("\n")]</center>")

// ───────────────────────── 管理员界面（TGUI：TianGuanCountdown） ─────────────────────────

/client/var/datum/tianguan_countdown_ui/tianguan_countdown_ui

/datum/tianguan_countdown_ui
	var/client/holder

/datum/tianguan_countdown_ui/New(user)
	if(istype(user, /client))
		holder = user
	else
		var/mob/user_mob = user
		holder = user_mob?.client

/datum/tianguan_countdown_ui/Destroy()
	holder = null
	return ..()

/datum/tianguan_countdown_ui/ui_state(mob/user)
	return ADMIN_STATE(R_ADMIN)

/datum/tianguan_countdown_ui/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TianGuanCountdown")
		ui.open()

/// 弹出取色窗（`tgui_color_picker` 是本仓现成的取色器：客户端开了 tgui_input 时走
/// TGUI 的 `ColorPickerModal`，否则回退拜恩原生取色环；两者都**阻塞等待**结果）。
/// ⚠️ 必须由 ui_act 用 INVOKE_ASYNC 调起 —— 直接调会把面板的回调卡住直到玩家取完色。
/datum/tianguan_countdown_ui/proc/pick_color(client/picker, color_kind)
	var/static/list/color_labels = list("title" = "标题", "countdown" = "倒计时", "end" = "结束文本")
	if(!(color_kind in color_labels))
		return
	var/datum/tianguan_countdown/countdown = tianguan_countdown_controller()
	var/picked = tgui_color_picker(picker, "选择[color_labels[color_kind]]颜色", "全局倒计时 · 取色", countdown.get_color(color_kind))
	if(!picked)
		return // 取消
	switch(color_kind)
		if("title")
			countdown.set_title_color(picked)
		if("countdown")
			countdown.set_countdown_color(picked)
		if("end")
			countdown.set_end_color(picked)
	log_admin("[key_name(picker)] 用取色器改了全局倒计时的[color_labels[color_kind]]颜色（[countdown.get_color(color_kind)]）。")
	SStgui.update_uis(src) // 让面板上的色块/输入框立刻回显新颜色

/datum/tianguan_countdown_ui/ui_data(mob/user)
	var/datum/tianguan_countdown/countdown = tianguan_countdown_controller()
	var/list/data = list()
	data["state"] = countdown.state
	data["title"] = countdown.title
	data["end_text"] = countdown.end_text
	data["remaining"] = countdown.remaining
	data["end_seconds"] = countdown.end_seconds
	data["title_color"] = countdown.title_color
	data["countdown_color"] = countdown.countdown_color
	data["end_color"] = countdown.end_color
	return data

/datum/tianguan_countdown_ui/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!check_rights(R_ADMIN))
		return
	var/datum/tianguan_countdown/countdown = tianguan_countdown_controller()
	switch(action)
		if("start")
			var/seconds = text2num(params["seconds"])
			var/end_seconds = text2num(params["end_seconds"])
			if(isnull(seconds))
				seconds = 60
			if(isnull(end_seconds))
				end_seconds = 0
			countdown.begin(params["title"], clamp(seconds, 1, 24 HOURS / 10), params["end_text"], clamp(end_seconds, 0, 1 HOURS / 10))
			log_admin("[key_name(holder)] 启动了全局倒计时（[clamp(seconds, 1, 24 HOURS / 10)] 秒）。")
		if("pause")
			countdown.toggle_pause()
			log_admin("[key_name(holder)] [countdown.state == TIANGUAN_CD_PAUSED ? "暂停" : "继续"]了全局倒计时。")
		if("stop")
			countdown.stop()
			log_admin("[key_name(holder)] 结束了全局倒计时。")
		if("set_title")
			countdown.set_title(params["title"])
			log_admin("[key_name(holder)] 更改了全局倒计时的标题。")
		if("set_end_text")
			countdown.set_end_text(params["end_text"])
			log_admin("[key_name(holder)] 更改了全局倒计时的结束文本。")
		if("set_title_color")
			countdown.set_title_color(params["title_color"])
			log_admin("[key_name(holder)] 更改了全局倒计时的标题颜色（[countdown.title_color]）。")
		if("set_countdown_color")
			countdown.set_countdown_color(params["countdown_color"])
			log_admin("[key_name(holder)] 更改了全局倒计时的倒计时颜色（[countdown.countdown_color]）。")
		if("set_end_color")
			countdown.set_end_color(params["end_color"])
			log_admin("[key_name(holder)] 更改了全局倒计时的结束文本颜色（[countdown.end_color]）。")
		if("pick_title_color")
			INVOKE_ASYNC(src, PROC_REF(pick_color), holder, "title")
		if("pick_countdown_color")
			INVOKE_ASYNC(src, PROC_REF(pick_color), holder, "countdown")
		if("pick_end_color")
			INVOKE_ASYNC(src, PROC_REF(pick_color), holder, "end")
	return TRUE
