/// 天关大厅侧边栏「角色卡」——头像 + 偏好摘要 + 变化推送。
///
/// 全部为**新增** proc 与**新增** middleware 子类型，不覆盖任何上游 proc：
///   - /datum/preferences/proc/tg_*  是新 proc（同名冲突只发生在重定义已有 proc 时）
///   - /datum/preference_middleware 由 subtypesof() 自动注册（code/modules/client/preferences/assets.dm:44），
///     加一个子类型即可收到回调，无需改动上游 middleware
///
/// 头像渲染直接复用「角色设置」那套（render_new_preview_appearance），见 tg_lobby_avatar_icon()。

/// 头像朝向：只渲南向一帧，与角色设置预览的观感一致。
#define TG_LOBBY_AVATAR_DIRS SOUTH

/// 配装轮询间隔（见 tg_start_lobby_watch 的说明）。
#define TG_LOBBY_WATCH_INTERVAL (2 SECONDS)

/mob/dead/new_player
	/// 大厅配装轮询是否已启动（防止重复开循环）
	var/tg_lobby_watch_running = FALSE
	/// 上一次的监听指纹，只在变化时才重算头像
	var/tg_last_watch_fingerprint

/// 生成侧边栏角色头像。
///
/// 直接复用「角色设置」里那套渲染 —— /datum/preferences/proc/render_new_preview_appearance()
/// （code/modules/mob/dead/new_player/preferences_setup.dm:97）。
/// 它会自己取最高优先职业、套用外观、按玩家自己的 preview_pref 决定穿制服 / loadout /
/// 内衣 / 裸体，再叠加视觉 trait 和身高。于是「角色设置里什么样，大厅里就什么样」。
///
/// 早先走的是 get_flat_human_icon() → job.outfit 那条粗路径：既漏掉 loadout，
/// 又完全无视玩家的 preview_pref，所以配装渲染不出来。
/datum/preferences/proc/tg_lobby_avatar_icon()
	var/mob/living/carbon/human/dummy/mannequin = new
	var/image/mannequin_appearance = render_new_preview_appearance(mannequin)
	var/icon/avatar = getFlatIcon(mannequin_appearance, TG_LOBBY_AVATAR_DIRS, no_anim = TRUE)
	SSatoms.prepare_deletion(mannequin)
	avatar?.Scale(64, 64)   // 32→64，浏览器端放大时锯齿更少
	return avatar

/// 侧边栏偏好摘要（键值行 HTML 片段）。
/datum/preferences/proc/tg_lobby_prefs_html()
	var/datum/species/selected_species = read_preference(/datum/preference/choiced/species)
	var/gender_value = read_preference(/datum/preference/choiced/gender)
	var/gender_text = "其他"
	if(gender_value == MALE)
		gender_text = "男"
	else if(gender_value == FEMALE)
		gender_text = "女"
	var/job_title = get_highest_priority_job()?.title   // 上游现成的取值，别自己遍历 job_preferences
	if(!job_title)
		job_title = "无"

	var/list/rows = list(
		list("种族", selected_species?.name || "未知"),
		list("年龄", "[read_preference(/datum/preference/numeric/age)]"),
		list("性别", gender_text),
		list("职位", job_title),
	)
	var/result = ""
	for(var/list/row in rows)
		result += {"<div class="tg_prow"><span class="k">[row[1]]</span><span class="v">[row[2]]</span></div>"}
	return result

/// 侧边栏角色卡（头像 + 名字 + ID + 槽位 + 偏好）的初始 HTML。
/mob/dead/new_player/proc/tg_lobby_card_html()
	if(!client || !client.prefs)
		return ""

	// 页面每次生成都顺手挂一次职业变更信号（override = TRUE 使重复进入幂等）。
	// 改职业走的是 action_delegations → /datum/preference_middleware/jobs，不经过
	// post_set_preference，所以只能靠上游在那里发的 COMSIG_JOB_PREF_UPDATED 感知；
	// 否则改完职业要切一次角色槽位才反映到大厅上。
	RegisterSignal(src, COMSIG_JOB_PREF_UPDATED, PROC_REF(tg_on_job_pref_updated), override = TRUE)
	tg_start_lobby_watch()

	var/datum/preferences/prefs = client.prefs
	var/icon/avatar = prefs.tg_lobby_avatar_icon()
	var/avatar_tag = {"<img id="tg_avatar" class="tg_avatar" src="data:image/png;base64,[icon2base64(avatar)]" alt="">"}
	var/name_text = uppertext(prefs.read_preference(/datum/preference/name/real_name))

	return {"
		<div class="tg_card">
			[avatar_tag]
			<div class="tg_pname" id="tg_pname">[name_text]</div>
			<div class="tg_pid" id="tg_pid">ID: [client.ckey] &nbsp;·&nbsp; 槽位 [prefs.default_slot]</div>
		</div>
		<div class="tg_prefs" id="tg_prefs">[prefs.tg_lobby_prefs_html()]</div>
	"}

/// 上游 /datum/preference_middleware/jobs 在玩家改职业优先级时会发这个信号
/// （code/modules/client/preferences/middleware/jobs.dm:29）。改职业不经过
/// post_set_preference，所以这是唯一能实时感知它的途径。
/mob/dead/new_player/proc/tg_on_job_pref_updated(datum/source, ...)
	SIGNAL_HANDLER
	log_world("TG_LOBBY: got COMSIG_JOB_PREF_UPDATED")
	if(client)
		INVOKE_ASYNC(client, TYPE_PROC_REF(/client, tg_push_lobby_card), "job_pref_signal")

/// 配装是唯一**没有**通知机制的改动路径 ——
/// Nova 的 save_current_loadout()（modular_nova/master_files/code/modules/loadout/loadout_menu.dm:83）
/// 直接调 update_preference()，而 middleware 的 post_set_preference 只在 ui_act 的
/// "set_preference" 分支里被手动遍历调用（preferences.dm:284）；上游也没为配装变更发任何信号。
/// 所以只能在「角色设置窗口开着」时轻量轮询一个配装指纹，变了才重算头像。
///
/// 各触发源分工（互不重复）：配装 → 这里轮询；职业 → COMSIG_JOB_PREF_UPDATED；
/// 其他偏好 → post_set_preference；角色槽位 → on_new_character。
/mob/dead/new_player/proc/tg_start_lobby_watch()
	if(tg_lobby_watch_running)
		return
	tg_lobby_watch_running = TRUE
	INVOKE_ASYNC(src, TYPE_PROC_REF(/mob/dead/new_player, tg_lobby_watch_loop))

/mob/dead/new_player/proc/tg_lobby_watch_loop()
	set waitfor = FALSE
	while(!QDELETED(src) && client)
		sleep(TG_LOBBY_WATCH_INTERVAL)
		// 角色设置没开着就不用查 —— 改配装必须先开着它。
		// character_preview_view 只在该界面打开时创建、关闭时 qdel，正好当"窗口开着"的标志。
		if(!client?.prefs?.character_preview_view)
			continue
		var/fingerprint = client.prefs.tg_lobby_watch_fingerprint()
		if(fingerprint == tg_last_watch_fingerprint)
			continue
		tg_last_watch_fingerprint = fingerprint
		INVOKE_ASYNC(client, TYPE_PROC_REF(/client, tg_push_lobby_card), "watch_poll")

/// 监听指纹：配装 + 职业优先级。
/// 职业本来有 COMSIG_JOB_PREF_UPDATED 可瞬时感知，这里再算一遍是**兜底** ——
/// 万一那条信号在某个路径上没发出来，轮询还能在 2 秒内补上。
/// 直接比 json_encode 的结果：DM 的字符串 == 就是内容比较，不必再算哈希。
/datum/preferences/proc/tg_lobby_watch_fingerprint()
	return json_encode(list(
		read_preference(/datum/preference/loadout),
		job_preferences,
	))

/// 把最新的角色卡数据推给已经在看大厅页面的客户端。
/// 页面里由 JS 函数 tg_set_avatar / tg_set_prefs / tg_set_name 接收（定义在 title_screen_html.dm）。
///
/// 每个字段**单独调用一次**、每次只传一个标量。
/// 不用 list2params(lst) 打包：BYOND 的 output() 到 browser 会把文本按 URL 参数解析，
/// 而 list2params 要求列表是 key/value 交替，直接塞 list(a, b, c) 只会得到畸形串，
/// JS 侧收不到多个参数（上游 Nova 的 update_loading_progress 就踩了这个坑）。
/client/proc/tg_push_lobby_card(reason = "unknown")
	var/mob/dead/new_player/player = mob
	if(!istype(player) || !prefs)
		log_world("TG_LOBBY: push aborted ([reason]) - not a lobby new_player, or no prefs")
		return

	// 刻意不把 player.title_screen_is_ready 当门槛。
	// 该标志唯一的置位点是页面底部那句 XHR 回报（?src=...;title_is_ready=1），
	// 实测在本环境从未置位过，于是所有推送被静默丢弃
	// （上游 Nova 的 update_character_name() 与 add_startup_message() 栽在同一个标志上）。
	// 而"玩家能改偏好"本身就证明大厅页面已经加载在那个 browser 里了。
	if(!player.title_screen_is_ready)
		log_world("TG_LOBBY: note - title_screen_is_ready still false, pushing anyway")

	var/name_text = uppertext(prefs.read_preference(/datum/preference/name/real_name))
	var/prefs_html = prefs.tg_lobby_prefs_html()
	// output() 会把文本当 URL 参数解析，& 会把它拆成多个 JS 参数。物种名/职位名正常不含 &，
	// 这里留个哨兵：真出现了就在日志留痕，免得以后对着怪现象无从下手。
	if(findtext(prefs_html, "&"))
		log_world("TG_LOBBY: warning - prefs html contains '&', output() may split it")
	var/icon/avatar = prefs.tg_lobby_avatar_icon()

	src << output(icon2base64(avatar), "nova_title_browser:tg_set_avatar")
	src << output(prefs_html, "nova_title_browser:tg_set_prefs")
	src << output(name_text, "nova_title_browser:tg_set_name")
	src << output("ID: [key] · 槽位 [prefs.default_slot]", "nova_title_browser:tg_set_pid")
	// 顺手补上被同一标志挡掉的上游那条（「角色设置」按钮上的名字）
	src << output(name_text, "nova_title_browser:update_current_character")
	// 推送后同步指纹：否则轮询会把刚推过的那次变化再推一遍
	player.tg_last_watch_fingerprint = prefs.tg_lobby_watch_fingerprint()
	log_world("TG_LOBBY: pushed card -> [key] (reason: [reason])")

/// 挂钩：角色槽位切换。上游 /datum/preference_middleware/titlescreen 也会收到，
/// 两者互不干扰（各自是独立的 middleware 实例）。
/datum/preference_middleware/tianguan_lobby

/datum/preference_middleware/tianguan_lobby/on_new_character(mob/user)
	. = ..()
	if(!istype(user, /mob/dead/new_player))
		return
	if(user.client)
		INVOKE_ASYNC(user.client, TYPE_PROC_REF(/client, tg_push_lobby_card), "new_character")

/// 挂钩：角色设置里改了某项偏好。头像涉及外观/制服，成本不低，
/// 因此放在 INVOKE_ASYNC 里，避免阻塞设置界面的响应。
/datum/preference_middleware/tianguan_lobby/post_set_preference(mob/user, preference, value)
	. = ..()
	if(!istype(user, /mob/dead/new_player))
		return
	if(user.client)
		INVOKE_ASYNC(user.client, TYPE_PROC_REF(/client, tg_push_lobby_card), "pref:[preference]")

#undef TG_LOBBY_AVATAR_DIRS
#undef TG_LOBBY_WATCH_INTERVAL
