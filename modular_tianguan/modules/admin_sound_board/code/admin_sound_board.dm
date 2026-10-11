// THIS IS A TIANGUAN MODULE FILE
// 模块：admin_sound_board —— 管理员「全局音效面板」
//
// 解决什么问题
// ------------
// 原版「播放全局音效」（code/modules/admin/verbs/playsound.dm）是在**播放那一刻**给每个在线玩家
// 各发一份音频文件：几十人同时来拉同一个文件 ⇒ 瞬时占满带宽 ⇒ 卡顿；而且：
//   * 没有上传进度可言，管理员点完就得**赌**客户端拉得动；
//   * 一局之内想再放一次，还得从头再发一遍；
//   * 中途新加入的玩家只能等下一次播放时跟着一起拉。
//
// 本模块的做法
// ------------
// 把「上传」与「播放」拆开成两个阶段，中间用一个**预传输**阶段衔接：
//   ① 上传：按钮走现有的「点唱机上传音乐」（fcopy 落到 config/jukebox_music/sounds/）；
//   ② 预传输：把该音频**逐份**（一份 = 一个在线玩家的一份）错开推进客户端缓存
//      （走 asset 通道 ⇒ 本质 browse_rsc），并在面板上实时显示就绪人数；
//   ③ 播放：**只有全部在线玩家都就绪后播放按钮才亮**；
//      音频在本局内一直保留 ⇒ 之后可以**反复播放**；新加入的玩家由每秒 tick 自动补传。
//
// 曲目来源与 admin_countdown 同源（都读点唱机上传目录），但**不跨模块调用它的 proc**：
// 模块边界自持一份精简的目录读取，避免以后单独删改任一个模块时互相牵连。
//
// 播放部分照抄「能响的那条路」（点唱机本体 / 点唱机浏览 Play 都实测有声）：
//   sound(路径) 直接构造 + channel = CHANNEL_JUKEBOX，并按**每个玩家自己的**音量偏好折算音量。
//   ⚠️ 不要用「新建 sound + .file = file(路径) + CHANNEL_ADMIN + status = SOUND_STREAM」那套：
//   实测该形状在客户端**完全无声**，而服务端日志一切正常（文件存在、音量算出、SEND_SOUND 送达）。

/// 每份之间的默认间隔（秒）。管理员可在面板上改。
/// 一份 = 一个在线玩家的一份音频 ⇒ 人数多人少时都按这个节奏错峰推，不制造瞬时峰值。
#define TIANGUAN_SOUND_BOARD_DEFAULT_INTERVAL 1

/datum/tianguan_sound_board
	/// 在线玩家的传输状态：ckey → list(name, pushed, ready, left)
	var/list/status = list()
	/// 待推的份：每一项是 list(ckey, 文件名)
	var/list/queue = list()
	/// 已推总份数（诊断/显示用）
	var/pushed_total = 0
	/// 每份之间的间隔（秒）
	var/interval = TIANGUAN_SOUND_BOARD_DEFAULT_INTERVAL
	/// 播放音量（1~100）
	var/volume = 60
	/// 推份定时器（一次一份）
	var/push_timer
	/// 每秒 tick：纳入新玩家 + 刷新打开着的界面
	var/tick_timer
	/// 当前在播放的文件名（用于停止按钮显示）
	var/playing_file
	/// 已知的目录清单：变了才把新文件纳入传输（上传后自动生效，无需回调）
	var/list/known_files = list()
	/// **已激活**的音频：只有这些才会被预传输。
	/// 打开面板**不**激活任何音频（否则一开面板就把整个曲库推给所有人）；
	/// 上传的新文件自动激活；已有的音频由面板上每行的「传输」按钮手动激活。
	/// 新玩家加入时只补传这里面的。
	var/list/enabled_files = list()
	/// 是否已把"打开面板时的现有曲库"记为已知（只需一次）
	var/seeded = FALSE

/datum/tianguan_sound_board/Destroy()
	stop_ticking()
	if(push_timer)
		deltimer(push_timer)
		push_timer = null
	return ..()

/// 控制器单例
/proc/tianguan_sound_board_controller()
	// proc 内静态 + 显式类型（`GLOBAL_VAR_INIT(x, null)` 里 null 推不出类型，会编译报错）
	var/static/datum/tianguan_sound_board/board
	if(!board)
		board = new
	return board

// ───────────────────────── 目录（读点唱机上传目录） ─────────────────────────

/// 返回 assoc：文件名 → list(name = 显示名, path = 完整路径)
/// 解析规则与点唱机（code/datums/components/jukebox.dm）和 admin_countdown 保持一致：
/// 文件名用 `+` 分隔，第一段是显示名。
/proc/tianguan_sound_board_files()
	var/list/out = list()
	for(var/track_file in flist(CONFIG_JUKEBOX_SOUNDS))
		var/path = "[CONFIG_JUKEBOX_SOUNDS][track_file]"
		if(!IS_SOUND_FILE_SAFE(path))
			continue
		var/list/track_data = splittext(track_file, "+")
		if(!length(track_data))
			continue
		var/track_name = strip_filepath_extension(track_data[JUKEBOX_NAME], SSsounds.safe_formats)
		if(!length(track_name))
			continue
		out[track_file] = list("name" = track_name, "path" = path)
	return out

/// 文件名 → asset 键名。上传的文件不是编译期常量，故在**运行时**注册进 asset 缓存；
/// 键名用原文件名，客户端收到的名字与游戏内 sound() 引用的文件名一致。
/// ⚠️ 客户端缓存按**文件内容**（md5asfile）寻址，与资源名叫什么无关 ⇒ 与游戏内 sound()
///    天然共享同一份缓存。因此**不要**改成"保留原文件名"（keep_local_name）：那样传输存的键名
///    与播放时按内容算出的键名不一致，反而会导致重新下载。
/proc/tianguan_sound_board_asset_key(track_file)
	var/list/track = tianguan_sound_board_files()[track_file]
	if(!track)
		return null
	var/datum/asset_transport/transport = SSassets.transport
	if(!transport)
		return null
	var/asset_key = track_file
	if(!SSassets.cache[asset_key])
		transport.register_asset(asset_key, file(track["path"]))
	return asset_key

// ───────────────────────── 传输调度 ─────────────────────────

/// 把当前在线、但还没登记过的玩家纳入队列（新加入的玩家也靠它补传）
/datum/tianguan_sound_board/proc/register_clients()
	var/list/files = tianguan_sound_board_files()
	// 首次调用：把**当前已有**的音频记为"已知但未激活" ⇒ 只有之后**新出现**的（= 本次上传的）
	// 才自动开始传输。否则一打开面板就把整个曲库排队传一遍（实测被指出语义不对）。
	if(!seeded)
		seeded = TRUE
		known_files = files.Copy()
	for(var/client/player as anything in GLOB.clients)
		if(QDELETED(player))
			continue
		var/key = player.ckey
		if(status[key])
			continue
		status[key] = list("name" = player.key, "pushed" = 0, "ready" = FALSE, "left" = FALSE)
		// 新玩家：只补**已激活**的音频
		for(var/track_file in enabled_files)
			queue += list(list(key, track_file))
	// 新出现的音频（管理员刚上传）⇒ 自动激活 + 给所有已知玩家各补一份
	for(var/track_file in files)
		if(!known_files[track_file])
			enabled_files[track_file] = TRUE
			for(var/other_key in status)
				queue += list(list(other_key, track_file))
	known_files = files.Copy()
	if(length(queue) && !push_timer)
		push_now()

/// 立刻推一份（避免第一份要等一个间隔才动）；其余按间隔排下去
/datum/tianguan_sound_board/proc/push_now()
	push_one()
	if(length(queue))
		push_timer = addtimer(CALLBACK(src, PROC_REF(push_now)), max(round(interval * 10), 5), TIMER_STOPPABLE)

/// 推一份（= 一个玩家的一份音频）
/datum/tianguan_sound_board/proc/push_one()
	if(!length(queue))
		if(push_timer)
			deltimer(push_timer)
			push_timer = null
		return
	var/list/pair = queue[1]
	queue.Cut(1, 2)
	var/key = pair[1]
	var/track_file = pair[2]
	var/list/entry = status[key]
	var/client/player = GLOB.directory[key]
	if(!entry)
		return
	if(QDELETED(player))
		entry["left"] = TRUE
		return
	var/asset_key = tianguan_sound_board_asset_key(track_file)
	if(asset_key)
		// 关键一步：走 asset 通道把这一份推给这个玩家的客户端
		var/datum/asset_transport/transport = SSassets.transport
		if(transport)
			transport.send_assets(player, asset_key)
			player.browse_queue_flush()
			entry["pushed"]++
			pushed_total++
			// ⚠️ 必须**逐文件**记账：推送是全局轮流（一次一份），玩家的份数对应不到具体哪一首，
			//    只数份数会让"就绪"提前成立 ⇒ 播放按钮在还没传到那首时就亮（实测逻辑会错）。
			if(!entry["files"])
				entry["files"] = list()
			entry["files"][track_file] = TRUE
			// 分母是**已激活**的音频数，不是整个曲库（曲库里没点"传输"的不参与）
			if(length(entry["files"]) >= length(enabled_files))
				entry["ready"] = TRUE

/// 某首音频是否**所有在线玩家**都已就绪（= 「上传全部结束」）
/datum/tianguan_sound_board/proc/ready_count(track_file)
	var/ready = 0
	var/total = 0
	for(var/key in status)
		var/client/player = GLOB.directory[key]
		if(!player || QDELETED(player))
			continue
		total++
		var/list/entry = status[key]
		if(entry && entry["files"] && entry["files"][track_file])
			ready++
	return list("ready" = ready, "total" = total)

/// 该音频是否已全部就绪（面板据此决定播放按钮亮不亮；服务端在播放时再核一次）
/datum/tianguan_sound_board/proc/is_fully_ready(track_file)
	var/list/r = ready_count(track_file)
	return r["total"] <= 0 ? FALSE : (r["ready"] >= r["total"])

/// 传输状态表（给 TGUI 用）
/datum/tianguan_sound_board/proc/status_table()
	var/total_files = length(enabled_files)
	var/ready = 0
	var/list/rows = list()
	for(var/key in status)
		var/list/entry = status[key]
		var/client/player = GLOB.directory[key]
		if(entry["ready"])
			ready++
		rows += list(list(
			"ckey" = key,
			"name" = entry["name"],
			"pushed" = entry["pushed"],
			"total" = total_files,
			"ready" = entry["ready"] ? TRUE : FALSE,
			"online" = (!isnull(player) && !QDELETED(player)),
			"left" = entry["left"] ? TRUE : FALSE,
		))
	return list(
		"players" = rows,
		"ready_count" = ready,
		"online_count" = length(GLOB.clients),
		"total" = total_files,
		"queue_left" = length(queue),
	)

// ───────────────────────── 播放 ─────────────────────────

/// 播放一首（可反复调用；音频在客户端已缓存 ⇒ 不产生下载）
/datum/tianguan_sound_board/proc/play(track_file, mob/user)
	var/list/track = tianguan_sound_board_files()[track_file]
	if(!track)
		return FALSE
	var/base_volume = clamp(volume, 1, 100)
	// ⚠️ 构造方式必须与「能响的那两条路」一致（点唱机本体 / 点唱机浏览 Play）：
	//    sound(路径) 直接构造 + CHANNEL_JUKEBOX，且**不要**设 SOUND_STREAM。
	var/sound/playing = sound(track["path"])
	playing.channel = CHANNEL_JUKEBOX
	playing.volume = base_volume
	var/heard = 0
	var/skipped = 0
	for(var/mob/player_mob as anything in GLOB.player_list)
		var/client/player = player_mob.client
		if(!player)
			continue
		var/volume_modifier = player.prefs?.read_preference(/datum/preference/numeric/volume/sound_midi)
		if(volume_modifier > 0)
			playing.volume = base_volume * (volume_modifier / 100)
			SEND_SOUND(player_mob, playing)
			heard++
			playing.volume = base_volume // 复位，下一个玩家重新折算
		else
			skipped++
	playing_file = track_file
	log_admin("[key_name(user)] 播放了全局音效面板里的 [track["name"]]（送达 [heard] 人 / 因音量偏好为 0 跳过 [skipped] 人）。")
	log_world("TIANGUAN_SOUND_BOARD: 播放 [track["name"]] 送达=[heard] 跳过=[skipped]")
	start_ticking()
	return TRUE

/// 停止播放
/datum/tianguan_sound_board/proc/stop(mob/user)
	for(var/mob/player_mob as anything in GLOB.player_list)
		SEND_SOUND(player_mob, sound(null, channel = CHANNEL_JUKEBOX))
	playing_file = null
	if(user)
		log_admin("[key_name(user)] 停止了全局音效面板的播放。")

// ───────────────────────── 每秒 tick ─────────────────────────

/// 有界面在看着时把 tick 带起来（纳入新玩家 + 刷新界面）
/datum/tianguan_sound_board/proc/start_ticking()
	if(tick_timer)
		return
	tick_timer = addtimer(CALLBACK(src, PROC_REF(tick)), 1 SECONDS, TIMER_LOOP | TIMER_STOPPABLE)

/datum/tianguan_sound_board/proc/stop_ticking()
	if(tick_timer)
		deltimer(tick_timer)
		tick_timer = null

/datum/tianguan_sound_board/proc/tick()
	// 中途新加入的玩家 ⇒ 自动补传（这就是"检测有没有新玩家需要补充上传"）
	register_clients()
	// 没有界面在看、也没有待推的份 ⇒ 循环自己收掉
	if(!length(GLOB.tianguan_sound_board_uis) && !length(GLOB.tianguan_sound_board_transfer_uis) && !length(queue))
		stop_ticking()
		return
	for(var/datum/tianguan_sound_board_ui/ui_datum as anything in GLOB.tianguan_sound_board_uis)
		SStgui.update_uis(ui_datum)
	for(var/datum/tianguan_sound_board_transfer_ui/ui_datum as anything in GLOB.tianguan_sound_board_transfer_uis)
		SStgui.update_uis(ui_datum)

// ───────────────────────── 主面板 ─────────────────────────

GLOBAL_LIST_EMPTY(tianguan_sound_board_uis)

/client/var/datum/tianguan_sound_board_ui/tianguan_sound_board_ui

/// 打开面板（核心 verb 从这里进来）
/// ⚠️ 入口参数是 **/client**（ADMIN_VERB 宏把 `user` 定为 client 类型）：
///    `/client` 自己**没有** `.client` 成员 ⇒ 写 `user.client` 会运行时报
///    "undefined variable /client/var/client" 并静默打不开面板（实测踩到过）。
///    所以缓存读 `user.tianguan_sound_board_ui`（那是 /client 上的变量），
///    而 ui_interact() 必须收到 **mob** ⇒ 传 `user.mob`（与 admin_countdown 面板同一写法）。
/proc/tianguan_sound_board_open(client/user)
	if(!user)
		log_world("TIANGUAN_SOUND_BOARD: 打开面板失败 —— 没有 client")
		return
	// 诊断：整条链上最容易出错的两点在这里一次说清（user 是不是 client、有没有 mob）
	log_world("TIANGUAN_SOUND_BOARD: 打开面板 ckey=[user.ckey] 有mob=[user.mob ? 1 : 0]")
	if(!user.mob)
		to_chat(user, span_warning("面板打不开：这个客户端还没有 mob。"))
		return
	var/datum/tianguan_sound_board_ui/ui_datum = user.tianguan_sound_board_ui
	if(!ui_datum)
		ui_datum = new /datum/tianguan_sound_board_ui(user)
	ui_datum.ui_interact(user.mob)

/datum/tianguan_sound_board_ui
	var/client/holder

/datum/tianguan_sound_board_ui/New(user)
	if(istype(user, /client))
		holder = user
	else
		var/mob/user_mob = user
		holder = user_mob?.client
	if(holder)
		holder.tianguan_sound_board_ui = src

/datum/tianguan_sound_board_ui/Destroy()
	GLOB.tianguan_sound_board_uis -= src
	if(holder && holder.tianguan_sound_board_ui == src)
		holder.tianguan_sound_board_ui = null
	holder = null
	return ..()

/datum/tianguan_sound_board_ui/ui_state(mob/user)
	return ADMIN_STATE(R_ADMIN)

/datum/tianguan_sound_board_ui/ui_interact(mob/user, datum/tgui/ui)
	GLOB.tianguan_sound_board_uis |= src
	tianguan_sound_board_controller().register_clients()
	tianguan_sound_board_controller().start_ticking()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TianGuanSoundBoard")
		ui.open()

/datum/tianguan_sound_board_ui/ui_close(mob/user)
	GLOB.tianguan_sound_board_uis -= src

/// 确认后删除某个上传音频（路径取自曲库 ⇒ 不接受任意字符串）
/datum/tianguan_sound_board_ui/proc/confirm_remove(client/warner, track_file, track_name)
	var/answer = tgui_alert(warner, "要从服务器上删掉「[track_name]」吗？\n它会同时从点唱机曲库里消失，且不可恢复。", "移除音频", list("删除", "取消"))
	if(answer != "删除")
		return
	var/path = "[CONFIG_JUKEBOX_SOUNDS][track_file]"
	if(!fexists(path))
		to_chat(warner, span_warning("文件已经不在了。"))
		return
	fdel(path)
	var/datum/tianguan_sound_board/board = tianguan_sound_board_controller()
	board.enabled_files -= track_file
	board.known_files -= track_file
	for(var/key in board.status)
		var/list/entry = board.status[key]
		if(entry && entry["files"])
			entry["files"] -= track_file
	log_admin("[key_name(warner)] 从全局音效面板移除并删除了上传音频 [track_file]。")
	to_chat(warner, span_notice("已删除「[track_name]」。（点唱机曲库同步生效）"))
	board.start_ticking()

/datum/tianguan_sound_board_ui/ui_data(mob/user)
	var/datum/tianguan_sound_board/board = tianguan_sound_board_controller()
	var/list/data = list()
	data["volume"] = board.volume
	data["interval"] = board.interval
	data["playing_file"] = board.playing_file
	var/list/rows = list()
	// ⚠️ 目录只扫一次：面板每秒刷新，若每首都重扫（flist × 每首）在曲目多时会拖慢开面板。
	var/list/files = tianguan_sound_board_files()
	for(var/track_file in files)
		var/list/track = files[track_file]
		var/list/ready = board.ready_count(track_file)
		rows += list(list(
			"key" = track_file,
			"name" = track["name"],
			"ready" = ready["ready"],
			"total" = ready["total"],
			"can_play" = board.is_fully_ready(track_file) ? TRUE : FALSE,
			"enabled" = board.enabled_files[track_file] ? TRUE : FALSE,
		))
	data["tracks"] = rows
	data["summary"] = board.status_table()
	return data

/datum/tianguan_sound_board_ui/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!holder || !check_rights_for(holder, R_SOUND))
		return TRUE
	var/datum/tianguan_sound_board/board = tianguan_sound_board_controller()
	switch(action)
		if("upload")
			// 复用现成的「点唱机上传音乐」verb（走 SSadmin_verbs 的正规入口，
			// 不直调 __avd_* —— 那会被 CanProcCall 拦下并通报管理员）。
			// 它的文件对话框是阻塞式的 ⇒ 必须 INVOKE_ASYNC 调起。
			// 上传成功后目录里会出现新文件，由每秒 tick 的 register_clients() 自动纳入传输。
			INVOKE_ASYNC(SSadmin_verbs, TYPE_PROC_REF(/datum/controller/subsystem/admin_verbs, dynamic_invoke_verb), holder, /datum/admin_verb/upload_jukebox_music)
			return TRUE
		if("play")
			var/track_file = params["key"]
			// 服务端再核一次"全部就绪"：按钮置灰只是提示，真正的门槛在这里
			if(!board.is_fully_ready(track_file))
				to_chat(holder, span_warning("这首还没给所有在线玩家传输完，稍等一会儿再点。"))
				return TRUE
			board.play(track_file, holder)
			return TRUE
		if("stop")
			board.stop(holder)
			return TRUE
		if("remove")
			// 移除 = 从服务器上删掉这个音频（属于 config/ 的上传目录，不进仓库）。
			// 删文件不可恢复 ⇒ 先弹确认（阻塞式对话框 ⇒ 必须 INVOKE_ASYNC）。
			var/remove_file = params["key"]
			var/list/remove_track = tianguan_sound_board_files()[remove_file]
			if(!remove_track)
				return TRUE
			INVOKE_ASYNC(src, PROC_REF(confirm_remove), holder, remove_file, remove_track["name"])
			return TRUE
		if("transfer")
			// 手动激活某一首（曲库里已有的音频不会自动传，必须管理员点名才传）
			var/track_file = params["key"]
			if(board.enabled_files[track_file])
				to_chat(holder, span_notice("这首已经在传输队列里了。"))
				return TRUE
			if(!tianguan_sound_board_files()[track_file])
				return TRUE
			board.enabled_files[track_file] = TRUE
			for(var/other_key in board.status)
				board.queue += list(list(other_key, track_file))
			board.start_ticking()
			log_admin("[key_name(holder)] 让 [track_file] 开始给在线玩家传输。")
			return TRUE
		if("set_volume")
			board.volume = clamp(text2num(params["volume"]) || 60, 1, 100)
			return TRUE
		if("set_interval")
			board.interval = clamp(text2num(params["interval"]) || TIANGUAN_SOUND_BOARD_DEFAULT_INTERVAL, 0.5, 60)
			return TRUE
		if("refresh")
			board.register_clients()
			return TRUE
		if("open_transfer")
			var/datum/tianguan_sound_board_transfer_ui/ui_datum = holder?.tianguan_sound_board_transfer_ui
			if(!ui_datum)
				ui_datum = new /datum/tianguan_sound_board_transfer_ui(holder)
			ui_datum.ui_interact(holder.mob)
			board.start_ticking()
			return TRUE

// ───────────────────────── 传输详情窗口（只读） ─────────────────────────
// 单独一个 TGUI：玩家数一多（几十人），主面板里那条窄列表根本铺不开。
// 这里用可换行的网格铺开，每个玩家名字下面一条小进度条。

GLOBAL_LIST_EMPTY(tianguan_sound_board_transfer_uis)

/client/var/datum/tianguan_sound_board_transfer_ui/tianguan_sound_board_transfer_ui

/datum/tianguan_sound_board_transfer_ui
	var/client/holder

/datum/tianguan_sound_board_transfer_ui/New(user)
	if(istype(user, /client))
		holder = user
	else
		var/mob/user_mob = user
		holder = user_mob?.client
	if(holder)
		holder.tianguan_sound_board_transfer_ui = src

/datum/tianguan_sound_board_transfer_ui/Destroy()
	GLOB.tianguan_sound_board_transfer_uis -= src
	if(holder && holder.tianguan_sound_board_transfer_ui == src)
		holder.tianguan_sound_board_transfer_ui = null
	holder = null
	return ..()

/datum/tianguan_sound_board_transfer_ui/ui_state(mob/user)
	return ADMIN_STATE(R_ADMIN)

/datum/tianguan_sound_board_transfer_ui/ui_interact(mob/user, datum/tgui/ui)
	GLOB.tianguan_sound_board_transfer_uis |= src
	tianguan_sound_board_controller().register_clients()
	tianguan_sound_board_controller().start_ticking()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TianGuanSoundBoardTransfer")
		ui.open()

/datum/tianguan_sound_board_transfer_ui/ui_close(mob/user)
	GLOB.tianguan_sound_board_transfer_uis -= src

/datum/tianguan_sound_board_transfer_ui/ui_data(mob/user)
	var/datum/tianguan_sound_board/board = tianguan_sound_board_controller()
	var/list/data = list()
	data["interval"] = board.interval
	data["status"] = board.status_table()
	return data
