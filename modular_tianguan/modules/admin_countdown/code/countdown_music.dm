// THIS IS A TIANGUAN MODULE FILE
// 模块：admin_countdown（音乐预传输部分）
//
// 解决什么问题
// ------------
// 原版「播放全局音效」（code/modules/admin/verbs/playsound.dm）是**在播放那一刻**给每个玩家
// 各发一份音频文件：几十人同时来拉同一个文件 ⇒ 瞬时占满带宽 ⇒ 卡顿。
//
// 本文件的做法
// ------------
// 在**倒计时期间**把选中的曲目按玩家、按曲目**错开**推送（走 asset 缓存通道 ⇒ 本质是 browse_rsc），
// 峰值被摊平到整个倒计时里；到点播放时客户端已持有本地副本，不再产生下载。
//
// 曲目来源
// --------
// **点唱机曲库**：`config/jukebox_music/sounds/`（`CONFIG_JUKEBOX_SOUNDS`）。
// 管理员用「点唱机上传音乐」上传的 .ogg 全部在这里，解析规则与点唱机一致
// （文件名用 `+` 分隔：`标题+节拍+…`，见 code/datums/components/jukebox.dm）。
// 本模块**不内置任何曲目**，只读这个目录 —— 与管理员的上传习惯保持同一份数据。
//
// 播放部分**照抄「能响的那条路」**（点唱机本体 / 点唱机浏览 Play 都实测有声）：
//   sound(路径) 直接构造 + channel = CHANNEL_JUKEBOX，并按**每个玩家自己的**音量偏好折算音量。
//   ⚠️ 不要用「新建 sound + .file = file(路径) + CHANNEL_ADMIN + status = SOUND_STREAM」那套：
//   实测该形状在客户端**完全无声**，而服务端日志一切正常（文件存在、音量算出、SEND_SOUND 送达）。
//
// 归属说明：本文件属于 admin_countdown 模块（倒计时提供时间窗，音乐挂在它上面），
// 不新建模块 ID；接入点见 admin_countdown.dm 里标注 music_ 的几处。

/// 预传输只占用倒计时剩余时间的这个比例，剩下的留作余量（客户端慢/迟到/大文件都赶得上）。
/// ⚠️ 取 1.0 是不可行的：那样「1 个人 1 份」时该份会卡在倒计时归零那一刻才推，
///    而此时 state 已非 RUNNING，推送被守卫拦掉 ⇒ 进度条永远停在 0/N。
#define TIANGUAN_CD_TRANSFER_WINDOW 0.75

// ───────────────────────── 曲库（读点唱机上传目录） ─────────────────────────
// 返回 assoc：文件名 → list(name = 显示名, path = 完整路径, length = 时长(分秒))
// 解析规则与 /datum/jukebox/load_songs_from_config() 保持一致。

/proc/tianguan_countdown_music_catalog()
	var/static/list/catalog
	// 目录清单是曲库的唯一真相：只有清单变了才重建（管理员上传/删除后自动生效）。
	// flist 很便宜，可以每次调用都做；而取每首时长（会读文件）只在重建时做一次。
	var/list/tracks = flist(CONFIG_JUKEBOX_SOUNDS)
	var/static/list/cached_listing
	if(!isnull(catalog) && length(tracks ^ cached_listing) == 0)
		return catalog
	catalog = list()
	cached_listing = tracks.Copy()
	for(var/track_file in tracks)
		var/path = "[CONFIG_JUKEBOX_SOUNDS][track_file]"
		// 只收真正的音频（与点唱机同一道过滤）
		if(!IS_SOUND_FILE_SAFE(path))
			continue
		var/list/track_data = splittext(track_file, "+")
		if(!length(track_data))
			continue
		var/track_name = strip_filepath_extension(track_data[JUKEBOX_NAME], SSsounds.safe_formats)
		if(!length(track_name))
			continue
		catalog[track_file] = list(
			"name" = track_name,
			"path" = path,
			"length" = null, // 按需再算：见 music_track_length()（开面板时逐个读文件会卡顿）
		)
	return catalog

/// 曲目时长（分秒）。只有「到点连播」需要它 ⇒ 按需计算并缓存进曲库条目，
/// 不在面板数据里读取 —— 否则每开一次面板/重建一次曲库都要把每个音频读一遍，会卡。
/datum/tianguan_countdown/proc/music_track_length(track_file)
	var/list/track = tianguan_countdown_music_catalog()[track_file]
	if(!track)
		return 0
	if(isnull(track["length"]))
		track["length"] = SSsounds.get_sound_length(track["path"])
	return track["length"]

/// 面板只需要「文件名 → 显示名」这一层（文件路径与时长不下发到前端）
/proc/tianguan_countdown_music_options()
	var/list/options = list()
	for(var/track_file in tianguan_countdown_music_catalog())
		var/list/track = tianguan_countdown_music_catalog()[track_file]
		options += list(list("key" = track_file, "name" = track["name"]))
	return options

/// 文件名 → asset 键名。上传的文件不是编译期常量，故在**运行时**注册进 asset 缓存；
/// 键名用**原文件名**，客户端收到的名字与游戏内 sound() 引用的文件名一致 ⇒ 命中同一份缓存。
/proc/tianguan_countdown_music_asset_key(track_file)
	var/list/track = tianguan_countdown_music_catalog()[track_file]
	if(!track)
		return null
	var/datum/asset_transport/transport = SSassets.transport
	if(!transport)
		return null
	var/asset_key = track_file
	// 客户端缓存按**文件内容**（md5asfile）寻址，与资源名叫什么无关 ⇒ 与游戏内 sound()
	// 天然共享同一份缓存（实测：已缓存曲目重播时客户端零新增下载）。
	// ⚠️ 因此**不要**改成"保留原文件名"（keep_local_name）：那样传输存的键名与播放时按内容
	//    算出的键名不一致，反而会导致重新下载。
	if(!SSassets.cache[asset_key])
		transport.register_asset(asset_key, file(track["path"]))
	return asset_key

// ───────────────────────── 内部倒计时（放歌准备窗）的启停 ─────────────────────────
// 与明面倒计时**各自独立计时**：各自设时长、可单独启动、也可以同时跑。
// 归零时播放（放在 tick() 里驱动，见 admin_countdown.dm）。

/// 启动内部倒计时。三种典型用法：
///   ① 两个都启动且时长相同 ⇒ 明面走完的同一刻播放；
///   ② 只启动这一个 ⇒ 玩家屏幕上什么都不显示（原「纯准备模式」的效果）；
///   ③ 明面填得比它长 ⇒ 明面先走一段，内部到点就播（明面继续走）。
/datum/tianguan_countdown/proc/begin_music(seconds)
	music_duration = max(round(seconds), 1)
	music_remaining = music_duration * 10
	music_deadline = world.time + music_remaining
	music_state = TIANGUAN_CD_RUNNING
	music_begin_transfer() // 立刻开始预传输（第一份立即推，进度条马上有动静）
	start_ticking() // 明面没在跑时，也得把 1 秒循环带起来
	refresh_all()

/// 停止内部倒计时：清掉传输与正在放的歌；**不影响**明面倒计时。
/datum/tianguan_countdown/proc/stop_music()
	music_state = TIANGUAN_CD_IDLE
	music_remaining = 0
	music_deadline = 0
	music_cleanup_transfer()
	music_cleanup_playback()

// ───────────────────────── 传输调度 ─────────────────────────
// 每个在线玩家一条独立的「逐首推送」链；玩家之间用初始延迟错开，
// 避免所有人在同一瞬间拉同一首。

/// 每首之间的间隔（秒）：默认按「剩余倒计时 ÷ 剩余曲目」动态算；管理员可手动指定。
/datum/tianguan_countdown/proc/music_interval_seconds()
	if(music_rate_manual > 0)
		return music_rate_manual
	// 自动 = 把「剩余待推送的份数」平摊进剩余倒计时。
	// 一份 = 一个玩家的一首歌 ⇒ 只有一首歌时就是「秒/人」（本功能最常见的场景）。
	// 下限 1 秒：再短就等于同一瞬间把所有人都推完，失去错峰的意义。
	var/seconds_left = max(round((running_deadline - world.time) / 10), 1)
	// ⚠️ 只占用剩余时间的 TIANGUAN_CD_TRANSFER_WINDOW（75%），留出余量：
	//    否则「1 个人 1 份」时间隔会等于整个倒计时，那一份会卡在归零那一刻才推 ——
	//    而那时 state 已不是 RUNNING，推送被守卫拦掉 ⇒ 进度条永远停在 0/N（实测踩到过）。
	return max((seconds_left * TIANGUAN_CD_TRANSFER_WINDOW) / max(length(music_transfer_queue), 1), 1)

/// 开始给所有在线玩家做预传输（倒计时开始时调用）
/datum/tianguan_countdown/proc/music_begin_transfer()
	music_cleanup_transfer()
	music_cleanup_playback() // 重开倒计时时，把上一轮可能还在连播的音乐停掉
	music_pushed_total = 0
	music_status = list()
	music_transfer_queue = list()
	if(!length(music_selection))
		return
	music_register_online_players()
	music_push_tick() // 第一份立刻推，进度条马上有动静（否则要等一个间隔才动）

/// 把当前在线的玩家纳入队列（倒计时途中新加入的玩家也靠它补发）
/datum/tianguan_countdown/proc/music_register_online_players()
	var/track_count = length(music_selection)
	for(var/client/player as anything in GLOB.clients)
		if(QDELETED(player))
			continue
		var/key = player.ckey
		if(music_status[key])
			continue
		music_status[key] = list("name" = player.key, "pushed" = 0, "ready" = FALSE, "left" = FALSE)
		for(var/song_index in 1 to track_count)
			music_transfer_queue += list(list(key, song_index))

/// 推一份（= 一个玩家的一首歌）；推完排下一份
/datum/tianguan_countdown/proc/music_push_tick()
	if(state != TIANGUAN_CD_RUNNING)
		return
	if(!length(music_transfer_queue))
		return
	var/list/pair = music_transfer_queue[1]
	music_transfer_queue.Cut(1, 2)
	var/key = pair[1]
	var/list/status = music_status[key]
	var/client/player = GLOB.directory[key]
	if(status && !QDELETED(player))
		var/asset_key = tianguan_countdown_music_asset_key(music_selection[pair[2]])
		if(asset_key)
			// 关键一步：走 asset 通道把这一首推给这个玩家的客户端
			var/datum/asset_transport/transport = SSassets.transport
			if(transport)
				transport.send_assets(player, asset_key)
				player.browse_queue_flush()
			status["pushed"]++
			music_pushed_total++
			if(status["pushed"] >= length(music_selection))
				status["ready"] = TRUE
	else if(status)
		status["left"] = TRUE
	music_push_next_schedule()

/// 排下一份（全局单条队列 ⇒ 只有一个定时器，份与份之间天然错峰）
/datum/tianguan_countdown/proc/music_push_next_schedule()
	if(state != TIANGUAN_CD_RUNNING)
		return
	var/interval = music_interval_seconds()
	music_transfer_timer = addtimer(CALLBACK(src, PROC_REF(music_push_tick)), max(round(interval * 10), 10), TIMER_STOPPABLE)

/// 取消所有未完成的推送
/datum/tianguan_countdown/proc/music_cleanup_transfer()
	if(music_transfer_timer)
		deltimer(music_transfer_timer)
		music_transfer_timer = null
	music_transfer_queue = list()

// ───────────────────────── 播放（复用 play_sound 的模型） ─────────────────────────
// 与 code/modules/admin/verbs/playsound.dm 的「播放全局音效」一致：同一个 /sound 对象逐个
// 玩家发送，并按每个玩家自己的音量偏好折算音量。差别：曲目已在倒计时里预传输 ⇒ 不产生额外下载。
// 选中的多首按顺序连播（用曲目自身时长推进）。

/datum/tianguan_countdown/proc/music_play()
	music_cleanup_playback()
	music_play_index = 0
	music_play_next()

/datum/tianguan_countdown/proc/music_play_next()
	music_play_index++
	if(music_play_index > length(music_selection))
		return
	var/track_file = music_selection[music_play_index]
	var/list/track = tianguan_countdown_music_catalog()[track_file]
	if(!track)
		return
	var/base_volume = clamp(music_volume, 1, 100)
	// ⚠️ 构造方式必须与「能响的那两条路」一致（点唱机本体 / 点唱机浏览 Play）：
	//    sound(路径) 直接构造 + CHANNEL_JUKEBOX，且**不要**设 SOUND_STREAM。
	//    实测：新建 sound + .file=file(路径) + CHANNEL_ADMIN + SOUND_STREAM ⇒ 客户端无声。
	var/sound/playing = sound(track["path"])
	// 诊断：文件是否真在服务端、以及每个玩家最终算出来的音量（排查"没声音"用）
	var/file_ok = fexists(track["path"])
	var/heard = 0
	var/skipped = 0
	var/lowest_volume = 999
	log_world("TIANGUAN_COUNTDOWN_MUSIC: 播放 [track["name"]] file=[track["path"]] 存在=[file_ok ? 1 : 0] 基准音量=[base_volume]")
	playing.channel = CHANNEL_JUKEBOX
	playing.volume = base_volume
	for(var/mob/player_mob as anything in GLOB.player_list)
		var/client/player = player_mob.client
		if(!player)
			continue
		var/volume_modifier = player.prefs?.read_preference(/datum/preference/numeric/volume/sound_midi)
		if(volume_modifier > 0)
			playing.volume = base_volume * (volume_modifier / 100)
			SEND_SOUND(player_mob, playing)
			heard++
			lowest_volume = min(lowest_volume, playing.volume)
			playing.volume = base_volume // 复位，下一个玩家重新折算
		else
			skipped++
	log_world("TIANGUAN_COUNTDOWN_MUSIC: 送达 [heard] 人 / 因音量偏好为 0 跳过 [skipped] 人 / 最小实际音量=[lowest_volume >= 999 ? "n/a" : lowest_volume]（若为 0 ⇒ 该玩家的「管理员音乐」音量是 0，去 Esc 菜单调）")
	log_admin("天关倒计时：播放预传输曲目 [track["name"]]（第 [music_play_index] 首）。")

	// 连播下一首：按本首时长推进（时长缺失时留 30 秒兜底）
	if(music_play_index < length(music_selection))
		var/length_ds = max(round(music_track_length(track_file) || 0), 0)
		if(!length_ds)
			length_ds = 30 SECONDS
		music_play_timer = addtimer(CALLBACK(src, PROC_REF(music_play_next)), length_ds, TIMER_STOPPABLE)
		// ⚠️ 连播定时器**不放进 music_timers**：倒计时收尾时的 music_cleanup_transfer()
		//    会清空那个表，若放进去会把刚开始的连播一起掐掉。

/// 停止连播（重开倒计时时用）
/datum/tianguan_countdown/proc/music_cleanup_playback()
	if(music_play_timer)
		deltimer(music_play_timer)
		music_play_timer = null
	for(var/mob/player_mob as anything in GLOB.player_list)
		var/client/player = player_mob.client
		if(player)
			SEND_SOUND(player_mob, sound(null, channel = CHANNEL_JUKEBOX))

/// 给 TGUI 的传输状态表（在线玩家逐个一行）
/datum/tianguan_countdown/proc/music_status_table()
	var/total = length(music_selection)
	var/ready = 0
	var/list/rows = list()
	for(var/key in music_status)
		var/list/entry = music_status[key]
		var/client/player = GLOB.directory[key]
		if(entry["ready"])
			ready++
		rows += list(list(
			"ckey" = key,
			"name" = entry["name"],
			"pushed" = entry["pushed"],
			"total" = total,
			"ready" = entry["ready"] ? TRUE : FALSE,
			"online" = !isnull(player),
		))
	return list(
		"players" = rows,
		"ready_count" = ready,
		"online_count" = length(GLOB.clients),
		"total" = total,
	)

// ───────────────────────── 传输详情窗口（只读） ─────────────────────────
// 单独一个 TGUI：玩家数一多（几十人），主面板里那条窄列表根本铺不开。
// 这里用可换行的网格铺开，每个玩家名字下面一条小进度条。

/// 打开着的传输详情窗口（运行中每秒刷新用）
GLOBAL_LIST_EMPTY(tianguan_countdown_transfer_uis)

/client/var/datum/tianguan_countdown_transfer_ui/tianguan_countdown_transfer_ui

/datum/tianguan_countdown_transfer_ui
	var/client/holder

/datum/tianguan_countdown_transfer_ui/New(user)
	if(istype(user, /client))
		holder = user
	else
		var/mob/user_mob = user
		holder = user_mob?.client

/datum/tianguan_countdown_transfer_ui/Destroy()
	GLOB.tianguan_countdown_transfer_uis -= src
	holder = null
	return ..()

/datum/tianguan_countdown_transfer_ui/ui_state(mob/user)
	return ADMIN_STATE(R_ADMIN)

/datum/tianguan_countdown_transfer_ui/ui_interact(mob/user, datum/tgui/ui)
	GLOB.tianguan_countdown_transfer_uis |= src
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TianGuanCountdownTransfer")
		ui.open()

/datum/tianguan_countdown_transfer_ui/ui_data(mob/user)
	var/datum/tianguan_countdown/countdown = tianguan_countdown_controller()
	var/list/data = list()
	data["state"] = countdown.state
	data["remaining"] = countdown.remaining / 10
	data["silent"] = countdown.silent
	data["music_interval"] = countdown.music_interval_seconds()
	data["rate_manual"] = countdown.music_rate_manual
	data["selection_count"] = length(countdown.music_selection)
	data["queue_left"] = length(countdown.music_transfer_queue)
	data["status"] = countdown.music_status_table()
	return data
