// GUIDE_BROWSER - 天关模块：指南浏览器（内容全部来自 config/tianguan/guide_browser.json）
//
// 玩家身上带一个「指南浏览器」动作按钮，点开是 tgui 窗口 GuideBrowser。左侧的树来自配置文件，
// 两种形态（对应配置里两类条目）：
//   · 有 children 的条目 = 可展开 / 折叠的分组（点击展开）—— 约定写在配置最上面
//   · 只有 url 的条目    = 直接跳转，怎么跳由条目/分组的 open 字段决定（出厂默认 "window"）：
//       "window"  —— 游戏内浏览器弹窗（同一个窗口反复复用）★出厂默认：一定弹出，不依赖客户端布局
//       "panel"   —— 游戏内浏览器面板（嵌在 DreamSeeker 窗口里；面板可不可见取决于客户端设置）
//       "frame"   —— 本窗口右侧 iframe 内嵌渲染（⚠ 目标站点必须允许被内嵌才行）
//       "browser" —— 交给系统默认浏览器
//
// ⚠ 为什么默认不是 "frame"：天关自己的 wiki（Miraheze）**全站**发
//   `X-Frame-Options: SAMEORIGIN`（实测主页/useskin/action=render/REST 等 6 种 URL 都有），
//   而 BYOND 516 起把内置浏览器从 IE 换成了 WebView2（Chromium）会照章执行该头
//   ⇒ iframe 只会得到「拒绝连接」。游戏内浏览走的是 browse()：那是**顶层导航**，
//   不受 X-Frame-Options 约束，而且页面由玩家自己的客户端请求（能过站点的防护）。
//
// 链接与按钮文字全部在配置文件里，本模块不写死任何 URL / 文案 ⇒ 管理员改配置不用重编译。
// 读取时机：子系统 Initialize()（此时 GLOB 与 i18n 已就绪、还没有任何玩家）+ 每局开局
// （COMSIG_TICKER_ENTER_PREGAME）各读一次；文件内容没变时整段短路，不会关掉正在看指南的人的窗口。
//
// 容错纪律：配置写错只 log_world 后跳过那一条，绝不中断开服（容错表见模块 readme.md）。

/// 配置文件路径。用 proc 而不是 #define：需要跨文件使用（管理员指令那边也要报这个路径）。
/proc/tianguan_guide_config_path()
	return "config/tianguan/guide_browser.json"

/// 树的最大嵌套层数（分组里还能放分组，但别无限套）
#define TIANGUAN_GUIDE_MAX_DEPTH 4
/// 整棵树最多允许多少个条目（分组 + 链接），防手滑写出巨型配置
#define TIANGUAN_GUIDE_MAX_NODES 256
/// 按钮文字最长显示字符数，超长截断
#define TIANGUAN_GUIDE_MAX_LABEL 64
/// 跳转链接最长字符数
#define TIANGUAN_GUIDE_MAX_URL 2048

/// 打开方式：游戏内浏览器面板（默认）
#define TIANGUAN_GUIDE_OPEN_PANEL "panel"
/// 打开方式：游戏内浏览器弹窗
#define TIANGUAN_GUIDE_OPEN_WINDOW "window"
/// 打开方式：本窗口右侧 iframe 内嵌（要求目标站点允许被内嵌）
#define TIANGUAN_GUIDE_OPEN_FRAME "frame"
/// 打开方式：系统默认浏览器
#define TIANGUAN_GUIDE_OPEN_BROWSER "browser"
/// 出厂默认打开方式：游戏内浏览器**弹窗** —— 一定弹出、不依赖客户端把浏览器面板摆在哪儿
/// （想把页面嵌在 DreamSeeker 窗口里的面板，就把 open 写成 "panel"）
#define TIANGUAN_GUIDE_OPEN_DEFAULT TIANGUAN_GUIDE_OPEN_WINDOW

/// 游戏内浏览器弹窗的默认尺寸（像素）
#define TIANGUAN_GUIDE_DEFAULT_W 1100
#define TIANGUAN_GUIDE_DEFAULT_H 760

/// 当前生效的树（tgui static_data 直接吃这个）
GLOBAL_LIST_EMPTY(tianguan_guide_tree)
/// 当前生效的叶子条目：id -> list("label" = ..., "url" = ..., "mode" = "panel"/"window"/"frame"/"browser")
GLOBAL_LIST_EMPTY(tianguan_guide_pages)
/// 默认选中项（配置里第一个可用链接）
GLOBAL_VAR_INIT(tianguan_guide_default_id, null)
/// 目录是否可用（一条可用链接都没有时为 FALSE ⇒ 不发放动作按钮）
GLOBAL_VAR_INIT(tianguan_guide_ready, FALSE)
/// 上次成功读取到的配置原文，用来判断「文件没变就不重载、不关界面」
GLOBAL_VAR_INIT(tianguan_guide_raw_snapshot, null)

/// 读配置 → 校验 → 重建 GLOB 表。返回可用的链接条数。任何失败只记日志，不中断启动。
/// force = TRUE 时忽略「文件没变就短路」（管理员手动重载用）。
/proc/tianguan_load_guide_config(force = FALSE)
	var/guide_file = tianguan_guide_config_path()
	var/raw_file = fexists(guide_file) ? file2text(guide_file) : null
	if(raw_file && !force && raw_file == GLOB.tianguan_guide_raw_snapshot)
		return length(GLOB.tianguan_guide_pages) // 文件没变：什么都不做，也不碰任何人的界面

	if(!fexists(guide_file))
		log_world("GUIDE_BROWSER: 找不到 [guide_file]，指南浏览器不发放按钮")
		return length(GLOB.tianguan_guide_pages)
	if(!raw_file)
		log_world("GUIDE_BROWSER: 无法读取 [guide_file]（文件为空或读取失败）")
		return length(GLOB.tianguan_guide_pages)

	var/list/decoded = json_decode(raw_file)
	if(!islist(decoded))
		log_world("GUIDE_BROWSER: [guide_file] 解析失败（顶层必须是 JSON 数组），本次沿用旧目录；修好文件后可用管理员指令 重载指南浏览器配置")
		return length(GLOB.tianguan_guide_pages)

	var/list/state = list(
		"tree" = list(),
		"pages" = list(),
		"nodes" = 0,
		"groups" = 0,
		"next_id" = 1,
		"default_id" = null,
		"modes" = list(),
	)
	var/disabled = 0
	var/skipped = 0
	for(var/entry in decoded)
		// JSON 的 false 解码成 0，而 null == 0 在 BYOND 里成立，所以必须先判 null：
		// 没写 enabled 的条目要当作启用，而不是当作禁用的 0。
		if(islist(entry) && !isnull(entry["enabled"]) && !entry["enabled"])
			disabled++
			continue
		var/list/node = tianguan_guide_build_node(entry, 1, state, TIANGUAN_GUIDE_OPEN_DEFAULT)
		if(node)
			state["tree"] += list(node)
		else
			skipped++

	GLOB.tianguan_guide_raw_snapshot = raw_file
	tianguan_commit_guide_config(state)

	var/group_count = state["groups"]
	var/page_count = length(state["pages"])
	var/list/lines = list()
	lines += "GUIDE_BROWSER: [guide_file] 读到 [length(decoded)] 条，启用 [length(decoded) - disabled] 条（分组 [group_count] 个 / 链接 [page_count] 条），已禁用 [disabled] 条，跳过 [skipped] 条"
	if(!page_count)
		lines += "GUIDE_BROWSER: 没有任何可用链接 ⇒ 指南浏览器不发放按钮（检查每条的 label 与 url）"
	else
		var/list/group_bits = list()
		for(var/list/group_node as anything in state["tree"])
			if(group_node["kind"] != "category")
				continue
			var/group_label = group_node["label"]
			var/group_children = length(group_node["children"])
			group_bits += "[group_label]([group_children])"
		if(length(group_bits))
			var/group_line = jointext(group_bits, " · ")
			lines += "GUIDE_BROWSER: 分组一览 → [group_line]"
		// 打开方式自证：默认应全是「游戏内浏览器」；有人写了 frame/window/browser 时这里会显出来
		var/list/mode_counts = state["modes"]
		var/panel_count = mode_counts[TIANGUAN_GUIDE_OPEN_PANEL] || 0
		var/window_count = mode_counts[TIANGUAN_GUIDE_OPEN_WINDOW] || 0
		var/frame_count = mode_counts[TIANGUAN_GUIDE_OPEN_FRAME] || 0
		var/browser_count = mode_counts[TIANGUAN_GUIDE_OPEN_BROWSER] || 0
		lines += "GUIDE_BROWSER: 打开方式 → 游戏内面板 [panel_count] 条 / 游戏内弹窗 [window_count] 条 / 窗口内嵌 [frame_count] 条 / 系统浏览器 [browser_count] 条"
		// 抽一条实际通过的链接打进日志：一眼确认 URL 真的解析成功、没被校验误杀
		var/list/sample_page = state["pages"][state["default_id"]]
		if(islist(sample_page))
			var/sample_label = sample_page["label"]
			var/sample_url = sample_page["url"]
			lines += "GUIDE_BROWSER: 示例链接 → [sample_label] = [sample_url]"
	for(var/line in lines)
		log_world(line)
	return page_count

/// 把一条配置条目变成树节点。分组返回 kind = "category"，链接返回 kind = "page"，不可用返回 null。
/// 入参刻意不加 list 类型约束：JSON 数组里混进字符串/数字时，类型化参数会在调用点直接抛错，
/// 而不是走到下面那句 islist 守卫里。
/proc/tianguan_guide_build_node(entry, depth, list/state, inherited_mode)
	if(!islist(entry))
		log_world("GUIDE_BROWSER: 跳过一条非对象条目（配置里混进了字符串/数字？）")
		return
	if(depth > TIANGUAN_GUIDE_MAX_DEPTH)
		log_world("GUIDE_BROWSER: 嵌套超过 [TIANGUAN_GUIDE_MAX_DEPTH] 层，已跳过该分支")
		return
	if(state["nodes"] >= TIANGUAN_GUIDE_MAX_NODES)
		log_world("GUIDE_BROWSER: 条目总数超过 [TIANGUAN_GUIDE_MAX_NODES]，后续条目已跳过")
		return

	var/label = tianguan_guide_label(entry["label"])
	if(!label)
		log_world("GUIDE_BROWSER: 跳过一条缺少 label（按钮文字）的条目")
		return

	// open 写在分组上会被组内条目继承；条目自己写了就以自己为准，写错值回退默认。
	var/open_mode = tianguan_guide_open_mode(entry["open"], inherited_mode, label)

	var/list/children = entry["children"]
	if(islist(children))
		var/list/built_children = list()
		for(var/child in children)
			var/list/built_child = tianguan_guide_build_node(child, depth + 1, state, open_mode)
			if(built_child)
				built_children += list(built_child)
		if(!length(built_children))
			log_world("GUIDE_BROWSER: 分组「[label]」里没有一条可用条目，已跳过这个分组")
			return
		state["nodes"]++
		state["groups"]++
		var/group_next_id = state["next_id"]
		var/group_id = "g[group_next_id]"
		state["next_id"]++
		return list(
			"kind" = "category",
			"id" = group_id,
			"label" = label,
			"count" = length(built_children),
			"children" = built_children,
		)

	var/url = tianguan_guide_url(entry["url"])
	if(!url)
		log_world("GUIDE_BROWSER: 跳过「[label]」（没有 url，或不是 http/https 链接）")
		return
	state["nodes"]++
	var/page_next_id = state["next_id"]
	var/page_id = "p[page_next_id]"
	state["next_id"]++
	state["pages"][page_id] = list("label" = label, "url" = url, "mode" = open_mode)
	state["modes"][open_mode] = (state["modes"][open_mode] || 0) + 1
	if(!state["default_id"])
		state["default_id"] = page_id
	return list("kind" = "page", "id" = page_id, "label" = label)

/// 解析一条条目的 open 值：合法值原样返回，写错/没写则继承分组的，分组也没写就是出厂默认。
/proc/tianguan_guide_open_mode(value, inherited_mode, label)
	if(isnull(value))
		return inherited_mode || TIANGUAN_GUIDE_OPEN_DEFAULT
	if(!istext(value))
		log_world("GUIDE_BROWSER: 「[label]」的 open 不是字符串，按 [inherited_mode] 处理")
		return inherited_mode || TIANGUAN_GUIDE_OPEN_DEFAULT
	var/candidate = LOWER_TEXT(trim(value))
	if(candidate == TIANGUAN_GUIDE_OPEN_PANEL || candidate == TIANGUAN_GUIDE_OPEN_WINDOW \
		|| candidate == TIANGUAN_GUIDE_OPEN_FRAME || candidate == TIANGUAN_GUIDE_OPEN_BROWSER)
		return candidate
	log_world("GUIDE_BROWSER: 「[label]」的 open 值不认识（可选 panel / window / frame / browser），按 [inherited_mode] 处理")
	return inherited_mode || TIANGUAN_GUIDE_OPEN_DEFAULT

/// 按钮文字：去首尾空白、限长；非字符串/空串返回 null（调用方当作配置错误跳过）。
/proc/tianguan_guide_label(value)
	if(!istext(value))
		return
	value = trim(value)
	if(!length(value))
		return
	if(length_char(value) > TIANGUAN_GUIDE_MAX_LABEL)
		value = copytext_char(value, 1, TIANGUAN_GUIDE_MAX_LABEL + 1)
	return value

/// 跳转链接：只接受 http/https；其余（含 "tianguanstation.miraheze.org/wiki/x" 这种漏了协议的）返回 null。
/// ⚠ copytext 的结束下标是**排他**的：要取前 8 个字符得写 1, 9（这个 off-by-one 曾让所有链接被误判）。
/proc/tianguan_guide_url(value)
	if(!istext(value))
		return
	value = trim(value)
	if(length(value) > TIANGUAN_GUIDE_MAX_URL)
		return
	var/lower_value = lowertext(value)
	if(copytext(lower_value, 1, 9) != "https://" && copytext(lower_value, 1, 8) != "http://")
		return
	return value

/// 把读好的结果提交为当前生效目录，并对齐所有人的按钮。
/proc/tianguan_commit_guide_config(list/state)
	GLOB.tianguan_guide_tree = state["tree"]
	GLOB.tianguan_guide_pages = state["pages"]
	GLOB.tianguan_guide_default_id = state["default_id"]
	GLOB.tianguan_guide_ready = length(state["pages"]) > 0
	SStianguan_guide_browser.reconcile_actions()

/// 取一条链接条目（界面与动作按钮都用它）。找不到/参数非法返回 null。
/proc/tianguan_guide_get_page(page_id)
	if(!istext(page_id))
		return
	var/list/page = GLOB.tianguan_guide_pages[page_id]
	return islist(page) ? page : null

/// 打开一条链接 —— 界面层与动作层唯一入口。按条目的 open 分派：
///   · "frame" 且 allow_frame（客户端支持内嵌）⇒ 返回 TRUE，交给 tgui 窗口右侧的 iframe 渲染
///   · 其余情况在这里就地打开（游戏内浏览器 / 系统浏览器）并返回 FALSE
/proc/tianguan_guide_open_page(mob/user, page_id, allow_frame = TRUE)
	var/list/page = tianguan_guide_get_page(page_id)
	if(!page || !user?.client)
		return FALSE
	switch(page["mode"])
		if(TIANGUAN_GUIDE_OPEN_FRAME)
			if(allow_frame)
				return TRUE
			// 客户端不支持内嵌 ⇒ 退回游戏内浏览器，别把人踢去系统浏览器
			return tianguan_guide_open_in_game_browser(user, page_id, TIANGUAN_GUIDE_OPEN_DEFAULT)
		if(TIANGUAN_GUIDE_OPEN_BROWSER)
			return tianguan_guide_open_external(user, page_id)
	return tianguan_guide_open_in_game_browser(user, page_id, page["mode"])

/// 从 winget() 读到的 "pos=X;size=WxH" 里挑出**可信**的几何，返回可以直接喂给 winset() 的串；
/// 任何一项不可信就返回 null（调用方退回默认尺寸）。
/// ⚠ 踩过的坑：弹窗不是皮肤窗口，winget() 会返回 "pos=0x0;size=0x0"；无条件 winset 回去会把
/// 窗口缩成只剩标题栏 —— 实测反馈"小到看不见，只剩最小化/关闭按钮"。
/proc/tianguan_guide_sane_geometry(geometry)
	if(!istext(geometry) || !length(geometry))
		return
	var/list/params = params2list(geometry)
	if(!islist(params) || !istext(params["size"]))
		return
	var/list/dims = splittext(params["size"], "x")
	if(length(dims) != 2)
		return
	var/width = text2num(dims[1])
	var/height = text2num(dims[2])
	// 尺寸必须看着像个真窗口（小于 300x200 基本就是 0x0 之类的假值）
	if(isnull(width) || isnull(height) || width < 300 || height < 200 || width > 8000 || height > 8000)
		return
	var/result = "size=[width]x[height]"
	var/pos = params["pos"]
	if(istext(pos) && length(pos))
		var/list/xy = splittext(pos, "x")
		if(length(xy) == 2 && !isnull(text2num(xy[1])) && !isnull(text2num(xy[2])))
			result = "pos=[pos];[result]"
	return result

/// 在**游戏内浏览器**里打开一条链接（mode = "panel" 面板 / "window" 弹窗）。
/// 做法：先送一张"导航垫片" HTML，它加载完立刻把自身/父窗口跳到目标 URL。
/// 这样目标页面是**顶层导航**（不受 X-Frame-Options 约束），且由玩家客户端去请求
/// （服务器不联网，也不用管站点对非浏览器客户端的拦截）。
/proc/tianguan_guide_open_in_game_browser(mob/user, page_id, mode = TIANGUAN_GUIDE_OPEN_DEFAULT)
	var/list/page = tianguan_guide_get_page(page_id)
	if(!page || !user?.client)
		return FALSE
	// 单引号会截断垫片里的 JS 字符串（URL 里极罕见，编码掉更稳）
	var/shim_url = replacetext(page["url"], "'", "%27")
	var/shim = "<html><head><meta charset='utf-8'></head><body onLoad=\"parent.location='[shim_url]'\"></body></html>"
	if(mode == TIANGUAN_GUIDE_OPEN_WINDOW)
		// ⚠ 坑一：同名窗口直接 browse() 只替换内容、**不会把窗口置顶** —— 玩家不关窗再点别条，
		//    新内容就被指南窗口压住了（实测反馈）。BYOND 也没有任何"置顶"参数可用。
		//    所以先关再开：销毁重建 ⇒ 一定出现在最上面（和玩家手动叉掉再点的效果一致）。
		// ⚠ 坑二：别无条件把 winget 读到的几何 winset 回去 —— 弹窗不是皮肤窗口，winget 会返回
		//    "pos=0x0;size=0x0"，照着设置会把窗口缩成只剩标题栏（实测反馈：小到看不见，
		//    只剩最小化/关闭按钮）。所以几何先过 tianguan_guide_sane_geometry()，不可信就显式给默认尺寸。
		var/geometry = tianguan_guide_sane_geometry(winget(user, "tianguan_guide_page", "pos;size"))
		user << browse(null, "window=tianguan_guide_page")
		user << browse(shim, "window=tianguan_guide_page;size=[TIANGUAN_GUIDE_DEFAULT_W]x[TIANGUAN_GUIDE_DEFAULT_H];can_resize=1")
		// 显式兜一次尺寸：万一客户端记住了上一次（被坑二弄坏的）窗口几何，这一步能纠正回来
		winset(user, "tianguan_guide_page", geometry || "size=[TIANGUAN_GUIDE_DEFAULT_W]x[TIANGUAN_GUIDE_DEFAULT_H]")
	else
		// 不指定 window ⇒ DreamSeeker 窗口里的内置浏览器面板（BYOND 参考文档的默认行为）
		user << browse(shim)
	return TRUE

/// 交给系统默认浏览器（link()）。user 必须有 client；confirm = TRUE 时先弹一次确认框。
/proc/tianguan_guide_open_external(mob/user, page_id, confirm = FALSE)
	var/list/page = tianguan_guide_get_page(page_id)
	if(!page)
		return FALSE
	if(!user?.client)
		return FALSE
	if(confirm && tgui_alert(user, "这条指南将在你的系统浏览器中打开。要继续吗？", "指南浏览器", list("Yes", "No")) != "Yes")
		return FALSE
	DIRECT_OUTPUT(user, link(page["url"]))
	return TRUE

SUBSYSTEM_DEF(tianguan_guide_browser)
	name = "Tianguan Guide Browser"
	ss_flags = SS_NO_FIRE

/datum/controller/subsystem/tianguan_guide_browser/Initialize()
	tianguan_load_guide_config()
	RegisterSignal(SSticker, COMSIG_TICKER_ENTER_PREGAME, PROC_REF(on_pregame))
	RegisterSignal(SSdcs, COMSIG_GLOB_CLIENT_CONNECT, PROC_REF(on_client_connect))
	return SS_INIT_SUCCESS

/// 每局开局重读一次：管理员改完配置，开下一局自动生效。
/// （文件没改时 tianguan_load_guide_config 会短路，不会关掉别人正开着的窗口。）
/datum/controller/subsystem/tianguan_guide_browser/proc/on_pregame(datum/source)
	SIGNAL_HANDLER
	tianguan_load_guide_config()

/datum/controller/subsystem/tianguan_guide_browser/proc/on_client_connect(datum/source, client/connected_client)
	SIGNAL_HANDLER
	if(GLOB.tianguan_guide_ready)
		ensure_guide_action(connected_client.persistent_client)

/// 把动作按钮发给某个 persistent_client（幂等；发现多余副本时只保留一个并清掉其余的）。
/datum/controller/subsystem/tianguan_guide_browser/proc/ensure_guide_action(datum/persistent_client/persistent)
	if(!GLOB.tianguan_guide_ready || !persistent)
		return
	var/datum/action/guide_browser/action
	for(var/datum/action/guide_browser/candidate as anything in persistent.player_actions)
		if(action)
			persistent.player_actions -= candidate
			qdel(candidate)
			continue
		action = candidate
	if(!action)
		action = new(persistent)
		persistent.player_actions += action
	if(persistent.mob)
		action.Grant(persistent.mob)
	return action

/// 目录被重载（或变得不可用）时对齐所有人：该发的按钮发下去、选中的条目失效就回到默认项。
/datum/controller/subsystem/tianguan_guide_browser/proc/reconcile_actions()
	for(var/datum/persistent_client/persistent as anything in GLOB.persistent_clients)
		if(!GLOB.tianguan_guide_ready)
			remove_guide_actions(persistent)
			continue
		var/datum/action/guide_browser/action = ensure_guide_action(persistent)
		if(!action)
			continue
		if(!tianguan_guide_get_page(action.selected_page_id))
			action.selected_page_id = GLOB.tianguan_guide_default_id
		SStgui.close_uis(action)

/// 收走某个 persistent_client 身上的指南浏览器按钮。
/datum/controller/subsystem/tianguan_guide_browser/proc/remove_guide_actions(datum/persistent_client/persistent)
	if(!persistent)
		return
	for(var/datum/action/guide_browser/action as anything in persistent.player_actions)
		SStgui.close_uis(action)
		persistent.player_actions -= action
		qdel(action)

#undef TIANGUAN_GUIDE_MAX_DEPTH
#undef TIANGUAN_GUIDE_MAX_NODES
#undef TIANGUAN_GUIDE_MAX_LABEL
#undef TIANGUAN_GUIDE_MAX_URL
#undef TIANGUAN_GUIDE_OPEN_PANEL
#undef TIANGUAN_GUIDE_OPEN_WINDOW
#undef TIANGUAN_GUIDE_OPEN_FRAME
#undef TIANGUAN_GUIDE_OPEN_BROWSER
#undef TIANGUAN_GUIDE_OPEN_DEFAULT
#undef TIANGUAN_GUIDE_DEFAULT_W
#undef TIANGUAN_GUIDE_DEFAULT_H
