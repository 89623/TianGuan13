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

/// 打开着的倒计时面板（运行中每秒刷新「传输状态表」用）
GLOBAL_LIST_EMPTY(tianguan_countdown_uis)

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
	/// 全局倒计时总时长（秒，用于算「已过了多久」⇒ 阶段切换的依据）
	var/total_seconds = 0
	/// 标题阶段：list(list("at" = 从倒计时开始算的**秒数（绝对时刻）**, "text" = 该阶段起显示的标题,
	/// "color" = 该阶段的标题颜色，空则用全局 title_color))。
	/// 到点自动切换；为空则一直用静态 title。维护时按 at 升序排好。
	var/list/title_stages = list()
	/// 内部倒计时是否跟随全局倒计时自动启动（同长 ⇒ 同时结束并播放）。
	/// 勾上后点「开始倒计时」一步到位，不必再单独开内部倒计时。
	var/music_follow_screen = TRUE
	/// 内部倒计时的「时长」按哪种口径解释：
	///   TRUE（默认）= 按「距全局倒计时结束」：音乐填 1 分钟 ⇒ **全局倒计时还剩 1 分钟时播放**
	///                 （例：全局倒计时 3:00 + 音乐 1:00 ⇒ 在总倒计时剩 1:00 时播）
	///   FALSE        = 从全局倒计时开始算：音乐填 1 分钟 ⇒ 开始后 1 分钟播放
	var/music_from_end = TRUE
	/// 标题颜色（#RRGGBB / #RGB / 常用色名；非法值回退白色）
	var/title_color = "#FFFFFF"
	/// 倒计时颜色（同上）
	var/countdown_color = "#FFFFFF"
	/// 结束文本颜色（同上）
	var/end_color = "#FFFFFF"
	var/atom/movable/screen/tianguan_countdown/hud
	var/timer_id
	// ── 倒计时音乐（预传输 + 到点播放，实现见同目录 countdown_music.dm）──
	/// 纯准备模式：不给玩家显示任何屏幕元素（倒计时只在管理员面板里走，专用来当放歌准备窗）
	var/silent = FALSE
	/// 选中的曲目（显示名，取自 tianguan_countdown_music_catalog()）
	var/list/music_selection = list()
	/// 传输节奏：0 = 自动（剩余时间 ÷ 剩余份数），>0 = 管理员指定的每份间隔秒数
	/// 一份 = 一个玩家的一首歌 ⇒ 只有一首歌时就是「秒/人」
	var/music_rate_manual = 0
	/// 播放音量 1~100（仍会按每个玩家自己的音量偏好逐个折算）
	var/music_volume = 60
	/// 每个玩家的传输状态：ckey → list(name, pushed, ready, left)
	var/list/music_status = list()
	/// 待推送队列：list(list(ckey, 曲目序号)) —— 全局单条，份与份之间天然错峰
	var/list/music_transfer_queue = list()
	/// 推送队列的推进定时器（全局只有一个）
	var/music_transfer_timer
	/// 已推送总次数（面板汇总用）
	var/music_pushed_total = 0
	/// 连播进度（到点后按顺序播第几首）
	var/music_play_index = 0
	/// 连播推进定时器（与传输定时器分开：收尾清理不会掐掉刚开始的播放）
	var/music_play_timer
	// ── 内部倒计时（放歌准备窗）：与全局倒计时**各自独立计时**，归零即播放 ──
	/// 内部倒计时状态（复用同一套状态常量）
	var/music_state = TIANGUAN_CD_IDLE
	/// 内部倒计时剩余（分秒）
	var/music_remaining = 0
	/// 内部倒计时截止时刻（world.time；运行中以它反推剩余）
	var/music_deadline = 0
	/// 内部倒计时设定时长（秒，面板回显用）
	var/music_duration = 0

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
	total_seconds = max(round(seconds), 1)
	end_deadline = 0
	start_ticking()
	refresh_all()
	// 内部倒计时：默认**跟随全局倒计时**一起启动（一步到位，不必再点下面那个按钮）。
	// 时长直接传 music_duration：**0 = 与全局倒计时同长**，由 begin_music() 按当前口径翻译成播放点
	// （默认口径下 = 全局倒计时结束时播；从开始算口径下 = 全局倒计时那么长之后播）。
	if(music_follow_screen && length(music_selection))
		begin_music(music_duration)
		log_admin("（自动）「跟随全局倒计时一起启动」带起了内部倒计时（音乐时长 [music_duration] 秒，口径：[music_from_end ? "距全局倒计时结束" : "从开始算"]）。")
	else if(music_follow_screen)
		// 勾了跟随但没选曲目 ⇒ 说清楚，别让它"静默不动"（这正是之前排查卡住的原因）
		log_admin("（自动）跟随已勾选，但没有选中任何曲目 ⇒ 未启动内部倒计时。")

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

/// 只收掉「全局倒计时」这一套（屏幕元素 + 全局倒计时计时），**不碰**内部倒计时与放歌状态。
/// 全局倒计时自动走完时用它 —— 两个计时器独立，全局倒计时先结束不该掐掉还在放的歌。
/datum/tianguan_countdown/proc/reset_screen()
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

/// 管理员点「结束」：全局倒计时 + 内部倒计时 + 传输全部收掉，回到「未进行任何设置」
/datum/tianguan_countdown/proc/stop()
	reset_screen()
	if(timer_id)
		deltimer(timer_id)
		timer_id = null
	// ⚠️ 刻意**不**清空 music_selection：结束倒计时不该让管理员重挑歌；
	//    而且「跟随全局倒计时一起启动」依赖它 —— 清掉会导致下次点「开始倒计时」时不带内部倒计时（实测踩到过）。
	music_status = list()
	music_pushed_total = 0
	music_state = TIANGUAN_CD_IDLE
	music_remaining = 0
	music_deadline = 0
	music_cleanup_transfer() // 清掉推送定时器与队列（幂等：上面已清过一次也无妨）

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
	// 两个计时器任一在跑，循环就得活着（只启动内部倒计时时全局倒计时是 IDLE）
	if(state == TIANGUAN_CD_IDLE && music_state == TIANGUAN_CD_IDLE)
		if(timer_id)
			deltimer(timer_id)
			timer_id = null
		return
	// ★ 剩余一律由"截止时刻 − 当前世界时间"反推，而不是"每跳减 10"：
	//   tg 的计时器在服务器卡顿/补跳时可能短时间内连触发数次（玩家实测"偶发快一倍多"），
	//   逐跳累减会把这类抖动累积成误差；以截止时刻为准 ⇒ 与真实时间始终一致，且卡顿后自动追上。
	if(state == TIANGUAN_CD_RUNNING)
		remaining = max(running_deadline - world.time, 0)
		// 倒计时途中新加入的玩家：每秒补登一次，把他们的份额追加进推送队列
		if(length(music_selection) && remaining > 0)
			music_register_online_players()
		if(remaining <= 0)
			if(end_text && end_seconds > 0)
				state = TIANGUAN_CD_ENDTEXT
				end_remaining = end_seconds * 10
				end_deadline = world.time + end_remaining
			else
				reset_screen() // 只收全局倒计时：内部倒计时（放歌准备窗）若还在跑，继续
				return
	else if(state == TIANGUAN_CD_ENDTEXT)
		end_remaining = max(end_deadline - world.time, 0)
		if(end_remaining <= 0)
			reset_screen() // 同上：全局倒计时结束文本到期只收全局倒计时
			return
	// ── 内部倒计时：与全局倒计时完全独立地推进；归零即播放 ──
	//    （全局倒计时先走一段、内部到点就播，就是"两个时长填不一样"自然得到的效果）
	if(music_state == TIANGUAN_CD_RUNNING)
		music_remaining = max(music_deadline - world.time, 0)
		if(length(music_selection) && music_remaining > 0)
			music_register_online_players()
		if(music_remaining <= 0)
			music_play() // 曲目已在内部倒计时里预传输 ⇒ 客户端命中本地缓存
			music_state = TIANGUAN_CD_IDLE
			music_remaining = 0
			music_deadline = 0
	refresh_all()
	// 让打开着的面板每秒回显一次「传输状态表」（面板刷新只能由服务端推）
	for(var/datum/tianguan_countdown_ui/panel as anything in GLOB.tianguan_countdown_uis)
		SStgui.update_uis(panel)
	for(var/datum/tianguan_countdown_transfer_ui/window as anything in GLOB.tianguan_countdown_transfer_uis)
		SStgui.update_uis(window)
	for(var/datum/tianguan_countdown_stage_ui/editor as anything in GLOB.tianguan_countdown_stage_uis)
		SStgui.update_uis(editor)

/// 挂到所有客户端（顺带收编新登录的玩家 —— 故无需核心登录钩子）+ 刷新文本
/datum/tianguan_countdown/proc/refresh_all()
	if(silent || state == TIANGUAN_CD_IDLE)
		// 纯准备模式 / 全局倒计时未启动：不给玩家挂任何屏幕元素
		// （「只启动内部倒计时」时玩家屏幕上就该什么都没有）
		for(var/client/player as anything in GLOB.clients)
			if(QDELETED(player))
				continue
			player.screen -= hud
		if(hud)
			hud.maptext = ""
		return
	for(var/client/player as anything in GLOB.clients)
		if(QDELETED(player))
			continue
		if(!(hud in player.screen))
			player.screen += hud
	if(hud)
		hud.maptext = build_maptext()

/datum/tianguan_countdown/proc/build_maptext()
	if(silent)
		return ""
	if(state == TIANGUAN_CD_IDLE)
		return ""
	if(state == TIANGUAN_CD_ENDTEXT)
		return MAPTEXT_PIXELLARI("<center><span style='color: [end_color]'>[end_text]</span></center>")
	var/list/lines = list()
	var/shown_title = current_title()
	if(shown_title)
		lines += "<span style='color: [current_title_color()]'>[shown_title]</span>"
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
	GLOB.tianguan_countdown_uis -= src
	holder = null
	return ..()

/datum/tianguan_countdown_ui/ui_state(mob/user)
	return ADMIN_STATE(R_ADMIN)

/datum/tianguan_countdown_ui/ui_interact(mob/user, datum/tgui/ui)
	GLOB.tianguan_countdown_uis |= src
	// 诊断：面板每次打开都记一行「曲库几首 / 当前已选几首」——
	// 这样"面板上有没有曲子可勾"与"后台认为选了几首"都能从日志看出来，不用猜。
	log_world("TIANGUAN_CD_UI: 面板打开 —— 曲库 [length(tianguan_countdown_music_options())] 首，已选 [length(tianguan_countdown_controller().music_selection)] 首")
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
	data["silent"] = countdown.silent
	// 曲库来自点唱机上传目录：只下发「文件名 + 显示名」，路径与时长留在服务端
	data["music_catalog"] = tianguan_countdown_music_options()
	data["music_selection"] = countdown.music_selection
	data["music_rate_manual"] = countdown.music_rate_manual
	data["music_volume"] = countdown.music_volume
	data["music_interval"] = countdown.music_interval_seconds()
	data["music_status"] = countdown.music_status_table()
	// 内部倒计时（放歌准备窗）：与全局倒计时各自独立计时
	data["music_state"] = countdown.music_state
	data["music_remaining"] = countdown.music_remaining / 10
	data["music_duration"] = countdown.music_duration
	// 内部倒计时与全局倒计时的"相对差"（秒）：>0 = 全局倒计时结束后过这么久播放；<0 = 全局倒计时结束前
	data["music_delta"] = (countdown.music_remaining - countdown.remaining) / 10
	data["music_follow_screen"] = countdown.music_follow_screen
	data["music_from_end"] = countdown.music_from_end
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
			// 防呆：勾了「跟随」却一首曲目都没选 ⇒ 弹框说清楚（否则只会静默不播放）
			if(countdown.music_follow_screen && !length(countdown.music_selection))
				INVOKE_ASYNC(src, PROC_REF(alert_no_songs), holder)
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
		if("set_silent")
			// 纯准备模式：倒计时不给玩家显示，只在面板里走（专用来当放歌准备窗）
			countdown.silent = !!params["silent"]
			countdown.refresh_all()
			log_admin("[key_name(holder)] 把全局倒计时设为[countdown.silent ? "纯准备（静默）" : "正常显示"]模式。")
		if("set_music")
			var/list/requested = params["selection"]
			if(!islist(requested))
				requested = list()
			// 只接受曲库内的显示名：不把任意字符串带进后续逻辑
			var/list/catalog = tianguan_countdown_music_catalog()
			var/list/accepted = list()
			for(var/song in requested)
				if(catalog[song])
					accepted += song
			countdown.music_selection = accepted
			// 诊断：分别记「收到几条」与「接受几条」—— 若收到>0 而接受=0 ⇒ 键名对不上（而不是没点）
			log_admin("[key_name(holder)] 选了 [length(accepted)] 首倒计时曲目（收到 [length(requested)] 条）。")
		if("set_music_rate")
			var/rate = text2num(params["rate"])
			countdown.music_rate_manual = clamp(isnull(rate) ? 0 : rate, 0, 600)
			log_admin("[key_name(holder)] 把倒计时传输节奏设为[countdown.music_rate_manual ? "[countdown.music_rate_manual] 秒/首" : "自动"]。")
		if("set_music_volume")
			var/vol = text2num(params["volume"])
			countdown.music_volume = clamp(isnull(vol) ? 60 : vol, 1, 100)
			log_admin("[key_name(holder)] 把倒计时音乐音量设为 [countdown.music_volume]。")
		if("set_music_duration")
			// 面板上「内部倒计时时长」的输入框改动即回写这里。
			// ⚠️ 必须回写：跟随启动时按 music_duration 取时长，不回写的话它会一直是 0
			//    ⇒ 明明填了 1 分钟却退化成"与全局倒计时同长"（实测踩到过）。
			var/duration = text2num(params["seconds"])
			countdown.music_duration = clamp(isnull(duration) ? 0 : round(duration), 0, 36000)
		if("start_music")
			// 启动内部倒计时（放歌准备窗）：与全局倒计时独立；归零即播放
			var/music_seconds = text2num(params["music_seconds"])
			// 防呆：没勾曲目就直接拦住并弹框（没有歌的内部倒计时没有意义）
			if(!length(countdown.music_selection))
				INVOKE_ASYNC(src, PROC_REF(alert_no_songs), holder)
				return TRUE
			countdown.begin_music(isnull(music_seconds) ? 60 : music_seconds)
			log_admin("[key_name(holder)] 启动了内部倒计时（放歌准备窗）：[countdown.music_duration] 秒。")
		if("stop_music")
			countdown.stop_music()
			log_admin("[key_name(holder)] 停止了内部倒计时。")
		if("set_follow")
			// 「跟随全局倒计时一起启动」：勾上后点「开始倒计时」就自动带内部倒计时同长启动
			countdown.music_follow_screen = !!params["follow"]
			log_admin("[key_name(holder)] 把「跟随全局倒计时一起启动」设为 [countdown.music_follow_screen ? "开" : "关"]。")
		if("set_from_end")
			// 时长口径：关 = 从全局倒计时开始算（旧逻辑）；开 = 按「距全局倒计时结束」算
			countdown.music_from_end = !!params["from_end"]
			log_admin("[key_name(holder)] 把音乐时长的口径设为[countdown.music_from_end ? "按「距全局倒计时结束」" : "按「从开始算」"]。")
		if("preview_music")
			// 试听：只放给按按钮的管理员自己，用来确认音量与曲目
			var/song = params["song"]
			var/list/track = tianguan_countdown_music_catalog()[song]
			if(track && holder?.mob)
				// 与点唱机一致的构造方式（sound(路径) + CHANNEL_JUKEBOX）——
				// 实测 CHANNEL_ADMIN 那条路在客户端无声，详见 countdown_music.dm 的注释
				var/sound/preview = sound(track["path"])
				log_world("TIANGUAN_COUNTDOWN_MUSIC: 试听 [track["name"]] file=[track["path"]] 存在=[fexists(track["path"]) ? 1 : 0] 音量=[countdown.music_volume] 目标=[holder.mob]")
				preview.channel = CHANNEL_JUKEBOX
				preview.volume = countdown.music_volume
				SEND_SOUND(holder.mob, preview)
		if("upload_music")
			// 直接复用现成的「点唱机上传音乐」verb（走 SSadmin_verbs 的正规入口，
			// 权限检查与参数收集都由它负责）⇒ 本模块不复制一份上传逻辑
			if(!check_rights(R_SERVER, FALSE))
				return
			INVOKE_ASYNC(SSadmin_verbs, TYPE_PROC_REF(/datum/controller/subsystem/admin_verbs, dynamic_invoke_verb), holder, /datum/admin_verb/upload_jukebox_music)
		if("refresh_music")
			// 上传走的是异步对话框，返回时面板已经刷过一次 ⇒ 给管理员一个手动刷新按钮：
			// 曲库按「目录清单是否变化」判断，这里只要触发一次 ui 刷新即可。
			. = TRUE
		if("open_transfer")
			// 打开独立的「传输详情」窗口（表格版，玩家多时才铺得开）
			var/datum/tianguan_countdown_transfer_ui/window = holder.tianguan_countdown_transfer_ui
			if(!window)
				window = new /datum/tianguan_countdown_transfer_ui(holder)
				holder.tianguan_countdown_transfer_ui = window
			window.ui_interact(holder.mob)
			. = TRUE
		if("open_stages")
			// 打开「标题阶段」编辑器（独立窗口，专门用来增删改阶段）
			var/datum/tianguan_countdown_stage_ui/editor = holder.tianguan_countdown_stage_ui
			if(!editor)
				editor = new /datum/tianguan_countdown_stage_ui(holder)
				holder.tianguan_countdown_stage_ui = editor
			editor.ui_interact(holder.mob)
			. = TRUE
	return TRUE

/// 把阶段按 at 升序排好（切换逻辑靠顺序逐个比较；阶段数量很小，手写插入排序即可）
/datum/tianguan_countdown/proc/sort_title_stages()
	var/list/sorted = title_stages.Copy()
	for(var/i in 2 to length(sorted))
		var/list/key = sorted[i]
		var/j = i - 1
		while(j >= 1 && sorted[j]["at"] > key["at"])
			sorted[j + 1] = sorted[j]
			j--
		sorted[j + 1] = key
	return sorted

// ───────────────────────── 标题阶段编辑器（TGUI：TianGuanCountdownStages） ─────────────────────────
// 单独一个窗口：阶段是「时间点 + 文本」的列表，在主面板里塞不下，也容易误触。

/// 打开着的阶段编辑器（编辑时实时刷新回显用）
GLOBAL_LIST_EMPTY(tianguan_countdown_stage_uis)

/client/var/datum/tianguan_countdown_stage_ui/tianguan_countdown_stage_ui

/datum/tianguan_countdown_stage_ui
	var/client/holder

/datum/tianguan_countdown_stage_ui/New(user)
	if(istype(user, /client))
		holder = user
	else
		var/mob/user_mob = user
		holder = user_mob?.client

/datum/tianguan_countdown_stage_ui/Destroy()
	GLOB.tianguan_countdown_stage_uis -= src
	holder = null
	return ..()

/datum/tianguan_countdown_stage_ui/ui_state(mob/user)
	return ADMIN_STATE(R_ADMIN)

/datum/tianguan_countdown_stage_ui/ui_interact(mob/user, datum/tgui/ui)
	GLOB.tianguan_countdown_stage_uis |= src
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TianGuanCountdownStages")
		ui.open()

/datum/tianguan_countdown_stage_ui/ui_data(mob/user)
	var/datum/tianguan_countdown/countdown = tianguan_countdown_controller()
	var/list/data = list()
	data["base_title"] = countdown.title
	data["total_seconds"] = countdown.total_seconds
	data["state"] = countdown.state
	data["elapsed"] = countdown.elapsed_seconds()
	data["current"] = countdown.current_title()
	data["stages"] = countdown.title_stages
	return data

/// 弹出取色窗给某条阶段选标题颜色（阻塞式 ⇒ 必须由 ui_act 用 INVOKE_ASYNC 调起）
/datum/tianguan_countdown_stage_ui/proc/pick_stage_color(client/picker, index)
	var/datum/tianguan_countdown/countdown = tianguan_countdown_controller()
	if(!index || index < 1 || index > length(countdown.title_stages))
		return
	var/list/stage = countdown.title_stages[index]
	var/picked = tgui_color_picker(picker, "选择该阶段标题颜色", "标题阶段 · 取色", stage["color"] || countdown.title_color)
	if(!picked)
		return
	stage["color"] = tianguan_countdown_sanitize_color(picked)
	SStgui.update_uis(src)

/datum/tianguan_countdown_stage_ui/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/datum/tianguan_countdown/countdown = tianguan_countdown_controller()
	switch(action)
		if("add_stage")
			// 默认接在上一条之后 1 分钟 ⇒ 连点就是 1 分 / 2 分 / 3 分…一次一变，不用手算
			var/next_at = 60
			if(length(countdown.title_stages))
				var/list/last_stage = countdown.title_stages[length(countdown.title_stages)]
				next_at = last_stage["at"] + 60
			countdown.title_stages += list(list("at" = next_at, "text" = "", "color" = null))
			countdown.title_stages = countdown.sort_title_stages()
			. = TRUE
		if("set_stage")
			var/index = text2num(params["index"])
			if(!index || index < 1 || index > length(countdown.title_stages))
				return
			var/list/stage = countdown.title_stages[index]
			if(!isnull(params["at"]))
				stage["at"] = max(round(text2num(params["at"])), 0)
			if(!isnull(params["text"]))
				stage["text"] = "[params["text"]]"
			if(!isnull(params["color"]))
				stage["color"] = tianguan_countdown_sanitize_color("[params["color"]]")
			countdown.title_stages = countdown.sort_title_stages()
			. = TRUE
		if("pick_stage_color")
			// 取色窗（本仓现成的 tgui_color_picker）：与全局三色同一套；必须 INVOKE_ASYNC 调起
			var/index = text2num(params["index"])
			if(index && index >= 1 && index <= length(countdown.title_stages))
				INVOKE_ASYNC(src, PROC_REF(pick_stage_color), holder, index)
			. = TRUE
		if("remove_stage")
			var/index = text2num(params["index"])
			if(index && index >= 1 && index <= length(countdown.title_stages))
				countdown.title_stages.Cut(index, index + 1)
			. = TRUE
		if("clear_stages")
			countdown.title_stages = list()
			. = TRUE
/// 当前生效的阶段（返回那条阶段 list；还没到第一条或没有阶段 ⇒ null）
/datum/tianguan_countdown/proc/current_stage()
	if(!length(title_stages))
		return null
	var/elapsed = elapsed_seconds()
	var/list/picked = null
	for(var/list/stage as anything in title_stages)
		if(stage["at"] > elapsed)
			break
		picked = stage
	return picked

/// 全局倒计时的「已过秒数」：总时长 − 剩余
/datum/tianguan_countdown/proc/elapsed_seconds()
	return max(total_seconds - round(remaining / 10), 0)

/// 当前应显示的标题文本：当前阶段有文本就用它，否则回退静态 title。
/datum/tianguan_countdown/proc/current_title()
	var/list/stage = current_stage()
	if(!stage || isnull(stage["text"]))
		return title
	return stage["text"]

/// 当前应显示的标题颜色：当前阶段有颜色就用它，否则用全局 title_color。
/datum/tianguan_countdown/proc/current_title_color()
	var/list/stage = current_stage()
	if(!stage || !stage["color"])
		return title_color
	return stage["color"]
/// 防呆提示：播放相关的设置开着却没勾曲目 ⇒ 弹框告知（阻塞式对话框 ⇒ 必须 INVOKE_ASYNC 调起）
/datum/tianguan_countdown_ui/proc/alert_no_songs(client/warner)
	tgui_alert(warner, "倒计时播放相关的设置已开启，但没有勾选任何曲目 ⇒ 到点不会播放。\n请到面板下方「曲目与传输」里勾选至少一首。", "倒计时音乐")
