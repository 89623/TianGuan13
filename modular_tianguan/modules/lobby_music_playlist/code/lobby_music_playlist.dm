// THIS IS A TIANGUAN MODULE FILE
// 模块：lobby_music_playlist —— 首页（大厅）BGM 随机轮播
//
// 背景：原版大厅音乐只在客户端登录时播一首就结束（code/game/sound/sound.dm 的
//       /client/proc/playtitlemusic() 里那次 SEND_SOUND 用的是 repeat = 0）。
// 做法：核心那一处加最小钩子（TIANGUAN EDIT ADDITION）——若本模块的接管 proc 返回 TRUE 就 return，
//       否则原样执行下游逻辑（模块不在/被禁用时行为与改动前完全一致）。
// 轮播：先放 SSticker 已随机挑好的那首（保留其"排除上回合曲目"的行为），
//       之后每首取时长（tianguan_lobby_track_length()：先查时长兜底表，再问 SSsounds.get_sound_length()），
//       sleep 到时再取下一首。
//       选曲用「洗牌队列 + 记忆窗」：整池随机排队逐首消费（队列内不重复），
//       且刚从队里取出的曲子若落在"最近（池大小-1）首"内就与队内后面交换 ⇒ 任意连续 N 次播放
//       互不相同（N = 池大小），跨轮/含首曲也不会回跳（A→X→A）。
// 终止：客户端断开、进入游戏（不再是大厅）时停止；音量偏好为 0 或服务器禁用大厅音乐时不启动。
//
// ⚠️ 上线前提（**服务器侧，本模块不改仓库配置**）：服务器须自行把 config/game_options.txt 里那行
//    DISALLOW_TITLE_MUSIC 注释掉（上游默认打开 = 禁用大厅音乐；配置页按指南不在仓库里动）。
//    未注释时 playtitlemusic() 的整体判定会直接跳过本模块 —— 表现为"大厅自始至终没声音"，且不报任何错（实测）。
//
// 曲目来源与命名约定（与 code/controllers/subsystem/ticker.dm 的 Initialize() 保持一致）：
//   目录 [global.config.directory]/title_music/sounds/
//   - 名字里没有 "+" ⇒ 常规曲目（始终在轮播池里）
//   - "rare" ⇒ 稀有曲目（仅 1% 概率型的场合出现，本模块沿用：默认不进池）
//   - "<地图名>" ⇒ 该地图专属（默认不进池）
//   - "exclude" ⇒ 排除项
//   池为空时回退 strings/round_start_sounds.txt（与 ticker 相同）。

GLOBAL_VAR_INIT(tianguan_lobby_music_pool, null)

/// 轮播代际号：playtitlemusic() 可能被多次调用（登录 / 音量偏好变更 / 回合结束），
/// 每次启动都 +1，旧循环在下一轮检查时自行退出 —— 避免多路循环叠着放歌。
/client/var/tianguan_lobby_music_generation = 0
/// 洗牌队列（shuffle bag）：本轮已洗好待播的曲目；空即重洗。
/client/var/list/tianguan_lobby_music_queue = null
/// 最近已播曲目（记忆窗，容量 = 池大小-1）：刚从队里取出的曲子若落在窗内，就与队内后面交换
/// —— 杜绝 A→B→A 回跳，并使【任意连续（池大小）次播放互不相同】（即一轮内不重复）。
/client/var/list/tianguan_lobby_music_history = list()

/// 取下一首（洗牌队列 + 记忆窗，业内标准做法）：
/// ① 洗牌队列：整池随机排队逐首消费 ⇒ 队列本身一轮内不重复；
/// ② 记忆窗（容量 = 池大小-1）：即将播放的这首若落在窗内，就与"队内第一首不在窗内的"交换 ⇒
///    即便跨轮（或首曲）也不会回跳。纯洗牌队列只保证"队列内不重复"，跨轮边界会回跳到间隔 2（A→X→A）。
///    实测（30 种子 × 4 千次，池 2~30 首）：同曲最小间隔 = 池大小、任意连续 N 次播放互不相同、违规窗口 0。
/client/proc/tianguan_lobby_next_track(list/pool)
	if(length(pool) < 2)
		return pool[1]

	if(!length(tianguan_lobby_music_queue))
		tianguan_lobby_music_queue = shuffle(pool.Copy())

	var/next_track = tianguan_lobby_music_queue[1]
	// 队首若落在记忆窗内 ⇒ 与"队内第一首不在窗内"的交换（确定性查找；
	// 不能用随机交换：随机可能换来另一首同样在窗内的，反而制造相邻重复，模拟验证过）。
	if((next_track in tianguan_lobby_music_history) && length(tianguan_lobby_music_queue) > 1)
		for(var/i in 2 to length(tianguan_lobby_music_queue))
			if(!(tianguan_lobby_music_queue[i] in tianguan_lobby_music_history))
				tianguan_lobby_music_queue.Swap(1, i)
				next_track = tianguan_lobby_music_queue[1]
				break
	tianguan_lobby_music_queue.Cut(1, 2)

	tianguan_lobby_music_history.Insert(1, next_track)
	// 窗容量 = 池大小-1：必须严格小于池大小，保证"窗外始终有曲子可换"；同时正好保证
	// "任意连续 N 次播放互不相同"（N = 池大小）。（早前写成 min(3,池-1) 会把全部曲子装进
	// 3 首池的窗内 ⇒ 无解可换 ⇒ 反而相邻重复，模拟验证过。）
	var/max_history = length(pool) - 1
	if(length(tianguan_lobby_music_history) > max_history)
		tianguan_lobby_music_history.Cut(max_history + 1)
	return next_track

/// 资源包保底清单：以下曲子以**字面量**引用 ⇒ 编译期必然打进 .rsc。
/// 为什么需要它：login_music 是运行期字符串路径，而 BYOND 只把「编译期出现过字面量」的资源打进 rsc；
/// 仓库自带的 lobby_music 里 title0.ogg 与 title1.mod 全仓无字面量引用 ⇒ 随机挑到它们时
/// SEND_SOUND 会静默失败（客户端没有该文件）。把清单放这里即可，且本文件变动会触发 rsc 重建。
GLOBAL_LIST_INIT(tianguan_lobby_music_rsc_keep, list(
	'sound/music/lobby_music/title0.ogg',
	'sound/music/lobby_music/title1.mod',
	'sound/music/lobby_music/title2.ogg',
	'sound/music/lobby_music/title3.ogg',
	'sound/music/lobby_music/clown.ogg',
))

/// 时长兜底表（分秒）：tracker 模块（.mod/.it/.s3m/.xm）BYOND 客户端**能播**，
/// 但时长探测库（rust-g 的 sound_len，基于 symphonia）**读不了** ⇒ get_sound_length() 返回错误串 → null
/// ⇒ 会撞上"取不到时长"的兜底值、导致提前切歌。这里补上人工核算的时长。
/// 现值来源：按 MOD 演出表逐行累计（含 Fxx 变速/节拍命令）算得 title1.mod = 200.0 秒 = 2000 分秒。
/// 以后新增模块类音乐，把核算值加到这里即可（核算脚本方法见模块 readme）。
GLOBAL_LIST_INIT(tianguan_lobby_music_length_override, list(
	"sound/music/lobby_music/title1.mod" = 2000,
))

/// 取曲目时长（分秒）：优先兜底表，其次 SSsounds.get_sound_length()。
/client/proc/tianguan_lobby_track_length(track)
	var/known = GLOB.tianguan_lobby_music_length_override[track]
	if(known)
		return known
	return SSsounds.get_sound_length(track)

/// 取大厅曲目池（懒加载 + 缓存）。规则与 ticker.Initialize() 对齐，仅保留常规曲目。
/proc/tianguan_lobby_music_pool()
	if(!isnull(GLOB.tianguan_lobby_music_pool))
		return GLOB.tianguan_lobby_music_pool

	var/list/pool = list()
	var/list/files = flist("[global.config.directory]/title_music/sounds/")
	var/use_rare_music = prob(1)
	var/current_map = SSmapping.current_map?.map_name

	for(var/S in files)
		var/lower = LOWER_TEXT(S)
		if(!IS_SOUND_FILE(lower))
			continue
		var/list/L = splittext(lower, "+")
		switch(L.len)
			if(3) // rare+<地图>+x.ogg / <地图>+rare+x.ogg
				if(use_rare_music && ((L[1] == "rare" && L[2] == current_map) || (L[2] == "rare" && L[1] == current_map)))
					continue // 稀有+地图专属：不进常规池
			if(2) // rare+x.ogg / <地图>+x.ogg
				continue // 稀有或地图专属：不进常规池
			if(1)
				if(lower == "exclude")
					continue
				pool += "[global.config.directory]/title_music/sounds/[S]"

	if(!length(pool))
		// 回退①：仓库自带曲目（上面那份字面量清单 ⇒ 已确保编译进 .rsc，客户端一定拿得到）
		for(var/f in GLOB.tianguan_lobby_music_rsc_keep)
			pool += "[f]"

	if(!length(pool))
		// 回退②：与 ticker 相同的文本清单（注意：其中未被任何字面量引用过的曲子不会进 rsc）
		pool = world.file2list("strings/round_start_sounds.txt", "\n")

	GLOB.tianguan_lobby_music_pool = pool
	return pool

/// 由核心 /client/proc/playtitlemusic() 调用。返回 TRUE 表示本模块已接管播放。
/// ⚠️ 本 proc 内**不能有 sleep**，也**不要**加 `set waitfor = FALSE`：
///    调用点是 `if(tianguan_lobby_playlist_start(volume)) return`，靠返回值决定是否接管；
///    waitfor=FALSE 的返回值语义不可靠（proc 一旦 sleep 就拿不到 TRUE）⇒ 核心会再播一遍。
///    轮播循环放在下面的 spawn 里，proc 本体瞬间返回 ⇒ 依旧不阻塞调用方。
/client/proc/tianguan_lobby_playlist_start(music_volume)
	var/list/pool = tianguan_lobby_music_pool()
	if(!length(pool))
		return FALSE // 池为空：交回核心原逻辑

	// 第一首：沿用 SSticker 已经随机挑好、且已排除"上回合曲目"的那首
	// （若它取不到时长且不在时长兜底表里 ⇒ 改用池中随机一首，避免按兜底值切歌）
	var/current = SSticker.login_music
	if(!current || !tianguan_lobby_track_length(current))
		current = pick(pool)

	var/my_generation = ++tianguan_lobby_music_generation // 新一代：旧循环见代际变化即自行退出
	tianguan_lobby_music_queue = null                      // 重洗牌队：不沿用上一轮/上次会话残留的队列
	tianguan_lobby_music_history.Cut()                     // 新一轮播放序列：清空记忆窗
	tianguan_lobby_music_history.Insert(1, current)        // 首曲也算已播，避免队列首个撞上它

	spawn(0)
		var/safety = 0
		while(safety++ < 500) // 上限保护，防止异常情况下无限循环
			if(my_generation != tianguan_lobby_music_generation)
				break // 已被新一次调用取代（仅判代际：登录瞬间 src.mob 未必就绪，故首轮不判 mob）
			// 先播当前曲目：本 proc 的调用点是"登录过程中"（login.dm 的 new_player/Login），
			// 那一刻 client.mob 未必已就绪 —— 故首轮不设前置条件，与原版 SEND_SOUND 行为一致。
			SEND_SOUND(src, sound(current, repeat = 0, wait = 0, volume = music_volume, channel = CHANNEL_LOBBYMUSIC))

			var/len = tianguan_lobby_track_length(current)
			if(!len || len <= 0)
				len = 2 MINUTES // 仅当取不到时长时兜底
			// 注：不要写成 `len < 5 SECONDS` 那种"最短时长"判断 —— 短曲子（铃声/jingle/音效型 BGM）
			// 会被误判成兜底值 ⇒ 循环睡上 2 分钟，表现为"播一首就停了"（实测踩过）。
			sleep(len)

			// 换台前判终止：被新调用取代 / 断线 / 已进场 / 服务器禁用 / 玩家大厅音量为 0
			// 注：不再判 SSticker.current_state —— 本 fork 的 GAME_STATE_* 与上游不同位
			// （STARTUP=0 / PREGAME=1），且"是否还在大厅"由 mob 类型已能准确判定。
			if(my_generation != tianguan_lobby_music_generation)
				break
			if(QDELETED(src) || !src.mob || !istype(src.mob, /mob/dead/new_player))
				break
			if(CONFIG_GET(flag/disallow_title_music))
				break
			if(!(prefs?.read_preference(/datum/preference/numeric/volume/sound_lobby_volume)))
				break

			// 下一首：洗牌队列（一轮内不重复；跨轮也不会与上一首相同）
			current = tianguan_lobby_next_track(pool)
		// 收尾：把本频道音量归零，避免残留（/client 上没有 stop_sound_channel，那是 /mob 的 proc，故直接发静音包）
		// 但若本次循环已被新一次调用取代（代际已变），频道归新一代所有 —— 此时再发静音包会把新一代
		// 刚播的曲子掐掉（读码时发现的竞态：登录 / 音量偏好变更 / 回合结束都会再调一次 playtitlemusic）。
		if(!QDELETED(src) && my_generation == tianguan_lobby_music_generation)
			SEND_SOUND(src, sound(null, repeat = 0, wait = 0, channel = CHANNEL_LOBBYMUSIC))

	return TRUE
