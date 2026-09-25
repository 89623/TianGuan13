// CUSTOM_EMPLOYERS - 天关模块：可配置的叛徒(Traitor)雇主扩展
//
// 上游把「雇主」拆成三份互不相干的数据，三者必须同时命中，雇主才会被
// /datum/antagonist/traitor/proc/pick_employer() 抽中并在 AntagInfoTraitor(tgui) 里显示：
//   1. 阵营名表：GLOB.syndicate_employers / GLOB.nanotrasen_employers
//   2. 结局表：GLOB.hijack_employers / GLOB.normal_employers —— pick 时按 ending_objective 从候选里
//      **减掉**其中一张表，所以「进哪张表」等于「限定哪种结局能出现」，「哪张都不进」才是不限结局。
//      详见 inject_tianguan_single_employer() 里 outcome 那段注释。
//   3. 文本表：strings/antagonist_flavor/traitor_flavor.json（pick 后由 strings() 查表，查不到直接 CRASH）
//
// 本模块读 config/tianguan/employers.json，把管理员填写的雇主一次性注入这三处。
//
// 注入时机选在子系统 Initialize()：此时 GLOB 全局表与 i18n 都已就绪，而任何叛徒都还没生成
// （见 code/game/world.dm 顶部的初始化顺序说明）。不依赖 GLOB 初始化 proc 的调用顺序
// （typesof() 的顺序不可保证），也不修改任何核心文件。
//
// 文本字段直接按最终显示语言填写（中文服就填中文），不经过 i18n 目录：i18n 的反查只会把
// 「目录里的英文」换成译文，中文原文查不到表，原样保留。

#define TIANGUAN_CUSTOM_EMPLOYERS_FILE "config/tianguan/employers.json"

/// 文本里可用的雇主名占位符，会被替换成该条目的 name
#define TIANGUAN_EMPLOYER_NAME_TOKEN "{name}"

#define TIANGUAN_EMPLOYER_FACTION_SYNDICATE "syndicate"
#define TIANGUAN_EMPLOYER_FACTION_NANOTRASEN "nanotrasen"
/// 第三阵营（团结联盟）。核心那份三元定义在 datum_traitor.dm 里，这里沿用同一批字符串值。
#define TIANGUAN_EMPLOYER_FACTION_UAR "uar"

/// 合法的 ui_theme（tgui 主题类名，traitor 界面直接拿去用）。填非法值会回退到阵营默认，
/// 避免 tgui 拿到未知主题。`uar` 是天关自带主题（tgui/packages/tgui/styles/themes/uar.scss，
/// 团结联盟雇主用，界面会额外铺那张徽记背景）。
GLOBAL_LIST_INIT(tianguan_employer_themes, list(
	"syndicate",
	"neutral",
	"ntos",
	"abductor",
	"uar",
))

/// 阵营 → 默认界面主题（雇主没填 ui_theme、或填了白名单外的值时用它兜底）
GLOBAL_LIST_INIT(tianguan_employer_faction_themes, list(
	TIANGUAN_EMPLOYER_FACTION_SYNDICATE = "syndicate",
	TIANGUAN_EMPLOYER_FACTION_NANOTRASEN = "ntos",
	TIANGUAN_EMPLOYER_FACTION_UAR = "uar",
))

/// 第三阵营的雇主名表。前两个阵营用的是核心的 GLOB.syndicate_employers / GLOB.nanotrasen_employers；
/// 第三个核心没有位子，由本模块自己持有，datum_traitor.dm 里那句 TIANGUAN EDIT 会把这张表并进候选池。
GLOBAL_LIST_EMPTY(tianguan_uar_employers)

/// 三个阵营的抽取权重（pick_weight 按比例抽，不必凑够 100）。改这里就能调阵营出现比例。
GLOBAL_LIST_INIT(tianguan_employer_faction_weights, list(
	TIANGUAN_EMPLOYER_FACTION_SYNDICATE = 40,
	TIANGUAN_EMPLOYER_FACTION_NANOTRASEN = 30,
	TIANGUAN_EMPLOYER_FACTION_UAR = 30,
))

/// 雇主阵营掷骰。调用点在 /datum/antagonist/traitor/proc/pick_employer()（上游那行二元掷骰被
/// TIANGUAN EDIT 换成了这个调用，好让第三个阵营参与）。
/// 权重表坏掉/为空时退回上游原来的 75/25 二元结果，保证不会出现「一个雇主都选不出来」。
/proc/tianguan_roll_employer_faction()
	var/list/weights = GLOB.tianguan_employer_faction_weights
	if(!islist(weights) || !length(weights))
		return prob(75) ? TIANGUAN_EMPLOYER_FACTION_SYNDICATE : TIANGUAN_EMPLOYER_FACTION_NANOTRASEN
	return pick_weight(weights)

/// 阵营 → 该阵营的雇主名单（自检用；pick_employer() 里是写死的三个分支）
/proc/tianguan_faction_employers(faction)
	switch(faction)
		if(TIANGUAN_EMPLOYER_FACTION_NANOTRASEN)
			return GLOB.nanotrasen_employers
		if(TIANGUAN_EMPLOYER_FACTION_UAR)
			return GLOB.tianguan_uar_employers
	return GLOB.syndicate_employers

/// 发牌抽样自检：池构造与 /datum/antagonist/traitor/proc/pick_employer() 逐句对应，
/// 报「实际抽到的雇主属于哪个阵营」。一眼确认三件事：三个阵营都在出货 / 没有空池 /
/// 没有跨阵营串味（抽到辛迪加那支却抓到纳米雇主 = 减集写错了）。
/// 结局按「逃脱局」算 —— 人数不够 30 的测试服只会遇到这种。
/proc/tianguan_sample_employer_dealing(sample_count = 2000)
	var/syn_hits = 0
	var/nt_hits = 0
	var/uar_hits = 0
	var/empty_pools = 0
	var/cross_faction = 0
	for(var/i in 1 to sample_count)
		var/faction = tianguan_roll_employer_faction()
		var/list/own_pool = tianguan_faction_employers(faction)
		// ↓ 与 pick_employer() 里的池构造逐句对应，别改成等价写法 —— 那样测的就不是真代码了
		var/list/pool = list()
		pool.Add(GLOB.syndicate_employers, GLOB.nanotrasen_employers, GLOB.tianguan_uar_employers)
		pool -= GLOB.hijack_employers
		switch(faction)
			if(TIANGUAN_EMPLOYER_FACTION_SYNDICATE)
				pool -= GLOB.nanotrasen_employers
				pool -= GLOB.tianguan_uar_employers
			if(TIANGUAN_EMPLOYER_FACTION_NANOTRASEN)
				pool -= GLOB.syndicate_employers
				pool -= GLOB.tianguan_uar_employers
			if(TIANGUAN_EMPLOYER_FACTION_UAR)
				pool -= GLOB.syndicate_employers
				pool -= GLOB.nanotrasen_employers
		if(!length(pool))
			empty_pools++
			continue
		var/picked = pick(pool)
		if(!(picked in own_pool))
			cross_faction++
		switch(faction)
			if(TIANGUAN_EMPLOYER_FACTION_NANOTRASEN)
				nt_hits++
			if(TIANGUAN_EMPLOYER_FACTION_UAR)
				uar_hits++
			else
				syn_hits++
	log_world("CUSTOM_EMPLOYERS: 发牌抽样 [sample_count] 次（逃脱局）→ 辛迪加 [syn_hits] / 纳米传讯 [nt_hits] / 团结联盟 [uar_hits] · 空池 [empty_pools] · 跨阵营 [cross_faction]")

GLOBAL_VAR_INIT(tianguan_custom_employers_injected, FALSE)

SUBSYSTEM_DEF(tianguan_employers)
	name = "Tianguan Employers"
	ss_flags = SS_NO_FIRE

/datum/controller/subsystem/tianguan_employers/Initialize()
	inject_tianguan_custom_employers()
	return SS_INIT_SUCCESS

/// 读 config/tianguan/employers.json 并把条目注入雇主池 + flavor 表。幂等。
/// 返回成功注入的条目数。任何一步失败都只记日志，不中断启动。
/proc/inject_tianguan_custom_employers()
	if(GLOB.tianguan_custom_employers_injected)
		return 0
	GLOB.tianguan_custom_employers_injected = TRUE

	if(!fexists(TIANGUAN_CUSTOM_EMPLOYERS_FILE))
		return 0

	var/raw_file = file2text(TIANGUAN_CUSTOM_EMPLOYERS_FILE)
	if(!raw_file)
		log_world("CUSTOM_EMPLOYERS: 无法读取 [TIANGUAN_CUSTOM_EMPLOYERS_FILE]")
		return 0

	var/list/entries = json_decode(raw_file)
	if(!islist(entries))
		log_world("CUSTOM_EMPLOYERS: [TIANGUAN_CUSTOM_EMPLOYERS_FILE] 解析失败（顶层必须是 JSON 数组）")
		return 0

	if(!islist(GLOB.syndicate_employers) || !islist(GLOB.nanotrasen_employers) \
		|| !islist(GLOB.hijack_employers) || !islist(GLOB.normal_employers))
		log_world("CUSTOM_EMPLOYERS: 雇主池全局表未就绪，自定义雇主未注入")
		return 0

	// 先让上游那份 flavor 表进缓存，我们只做追加（也顺带保证 strings() 之后不会重新加载覆盖我们）
	load_strings_file(TRAITOR_FLAVOR_FILE)
	var/list/flavor_table
	if(islist(GLOB.string_cache))
		flavor_table = GLOB.string_cache[TRAITOR_FLAVOR_FILE]
	if(!islist(flavor_table))
		log_world("CUSTOM_EMPLOYERS: 无法加载 [TRAITOR_FLAVOR_FILE]，自定义雇主未注入")
		return 0

	var/injected = 0
	var/disabled = 0
	var/list/injected_names = list()
	for(var/entry in entries)
		// JSON 的 false 解码成 0，而 null == 0 在 BYOND 里成立，所以必须先判 null：
		// 没写 enabled 的条目要当作启用，而不是当作禁用的 0。
		if(islist(entry) && !isnull(entry["enabled"]) && !entry["enabled"])
			disabled++
			continue
		if(inject_tianguan_single_employer(entry, flavor_table))
			injected++
			injected_names += entry["name"]

	// 即使一条都没启用也要出声：否则全禁用的配置看起来就像模块没跑。
	var/injected_list = injected ? jointext(injected_names, "、") : "无"
	log_world("CUSTOM_EMPLOYERS: [TIANGUAN_CUSTOM_EMPLOYERS_FILE] 读到 [length(entries)] 条，启用 [injected] 条，已禁用 [disabled] 条 → [injected_list]")
	if(injected)
		verify_tianguan_custom_employers(injected_names)
	return injected

/// 部署自检：按上游 pick_employer() 的候选池算法复核每个自定义雇主真的能被抽到，并按
/// pick 之后的同一条 strings() 路径取一次文本。结果写进启动日志（条目多时日志会略长，只在启动时一次）。
/proc/verify_tianguan_custom_employers(list/employer_names)
	if(!length(employer_names))
		return

	// 复刻 pick_employer()：先合并三张阵营表，再按本局 ending_objective 减掉另一边的结局表。
	// （阵营筛是正交的：每个雇主只在一张阵营表里，能过结局这一关就一定抽得到。）
	var/list/normal_ending_pool = list()
	normal_ending_pool.Add(GLOB.syndicate_employers, GLOB.nanotrasen_employers, GLOB.tianguan_uar_employers)
	normal_ending_pool -= GLOB.hijack_employers
	var/list/hijack_ending_pool = list()
	hijack_ending_pool.Add(GLOB.syndicate_employers, GLOB.nanotrasen_employers, GLOB.tianguan_uar_employers)
	hijack_ending_pool -= GLOB.normal_employers

	log_world("CUSTOM_EMPLOYERS: 自检（辛迪加池 [length(GLOB.syndicate_employers)] 条 / 纳米传讯池 [length(GLOB.nanotrasen_employers)] 条 / 团结联盟池 [length(GLOB.tianguan_uar_employers)] 条）")
	log_world("CUSTOM_EMPLOYERS: 阵营权重 辛迪加 [GLOB.tianguan_employer_faction_weights[TIANGUAN_EMPLOYER_FACTION_SYNDICATE]] / 纳米传讯 [GLOB.tianguan_employer_faction_weights[TIANGUAN_EMPLOYER_FACTION_NANOTRASEN]] / 团结联盟 [GLOB.tianguan_employer_faction_weights[TIANGUAN_EMPLOYER_FACTION_UAR]]（相对比例）")
	tianguan_sample_employer_dealing()
	// 主题抽查：上游雇主的 ui_theme 必须是 canonical 英文。NOVA 的 i18n（load_strings_file 里的
	// lang_reverse_tree）会递归反查翻译整张 flavor 表，万一翻到 ui_theme，tgui 拿到「theme-中文」这种
	// 类名匹配不到任何 CSS，窗口就掉回默认蓝（看着像纳米的）。
	for(var/sample_name in list("Cybersun Industries", "Donk Corporation", "Waffle Corporation"))
		var/list/sample_flavor = strings(TRAITOR_FLAVOR_FILE, sample_name)
		var/sample_theme = sample_flavor["ui_theme"]
		log_world("CUSTOM_EMPLOYERS: 主题抽查 [sample_name] → ui_theme=[sample_theme]")
	for(var/employer_name in employer_names)
		// 与 pick_employer() 末尾完全相同的查表调用（查不到会 CRASH，所以这里跑通即代表不会 CRASH）
		var/list/flavor = strings(TRAITOR_FLAVOR_FILE, employer_name)
		var/introduction = flavor["introduction"]
		log_world("CUSTOM_EMPLOYERS: [employer_name] 普通结局可抽=[(employer_name in normal_ending_pool)] 劫机结局可抽=[(employer_name in hijack_ending_pool)] 开场白=[introduction]")

/// 注入单个雇主条目：阵营池 + 结局池 + flavor 文本。返回是否注入成功。
/// enabled 的判定留在调用方（inject_tianguan_custom_employers）做，因为它要顺带统计禁用条数。
/// 入参刻意不加 list 类型约束：JSON 数组里混进字符串/数字时，类型化参数会在调用点直接抛错，
/// 而不是走到下面那句 islist 守卫里。
/proc/inject_tianguan_single_employer(entry, list/flavor_table)
	if(!islist(entry))
		log_world("CUSTOM_EMPLOYERS: 跳过一条非对象条目")
		return FALSE

	var/employer_name = entry["name"]
	if(!istext(employer_name) || !length(employer_name))
		log_world("CUSTOM_EMPLOYERS: 跳过一条缺少 name 的条目")
		return FALSE
	if(flavor_table[employer_name] || (employer_name in GLOB.syndicate_employers) || (employer_name in GLOB.nanotrasen_employers) || (employer_name in GLOB.tianguan_uar_employers))
		log_world("CUSTOM_EMPLOYERS: 跳过 [employer_name]（与现有雇主重名，改名或删掉上游同名条目）")
		return FALSE

	var/introduction = entry["introduction"]
	if(!istext(introduction) || !length(introduction))
		log_world("CUSTOM_EMPLOYERS: 跳过 [employer_name]（缺少 introduction，界面会没有开场白）")
		return FALSE

	// 1) 阵营池：syndicate / nanotrasen / uar（第三个是天关加的，见 datum_traitor.dm 的 TIANGUAN EDIT）
	var/faction = entry["faction"]
	if(!istext(faction))
		faction = TIANGUAN_EMPLOYER_FACTION_SYNDICATE
	faction = LOWER_TEXT(faction)
	if(faction != TIANGUAN_EMPLOYER_FACTION_NANOTRASEN && faction != TIANGUAN_EMPLOYER_FACTION_UAR)
		faction = TIANGUAN_EMPLOYER_FACTION_SYNDICATE
	if(faction == TIANGUAN_EMPLOYER_FACTION_NANOTRASEN)
		GLOB.nanotrasen_employers += employer_name
	else if(faction == TIANGUAN_EMPLOYER_FACTION_UAR)
		GLOB.tianguan_uar_employers += employer_name
	else
		GLOB.syndicate_employers += employer_name

	// 2) 结局归属。pick_employer() 拿两张结局表当**减集**用：劫机局减 normal_employers，
	//    非劫机局减 hijack_employers。「减」= 把候选里出现在该表中的名字移除，于是：
	//      · outcome = normal → 进 normal_employers，只在非劫机局（逃脱）出现
	//      · outcome = hijack → 进 hijack_employers，只在劫机局出现。注意劫机局本身极稀有：
	//        datum_traitor.dm 要求 joined_player_list ≥ HIJACK_MIN_PLAYERS(30) 且 prob(HIJACK_PROB=10)，
	//        人数不足 30 时 is_hijacker 恒为 FALSE、一局都不会有 —— 单人测试想验证就别用 hijack。
	//      · outcome = both   → 两张表都不进，两个分支都不动它，两种局都能出现（本模块新增的口径）
	//    同时进两张表反而是唯一必死的写法：两个分支都会把它减掉，永远抽不到。
	var/outcome = entry["outcome"]
	if(islist(outcome)) // 兼容误写成数组
		var/list/outcome_list = outcome
		if(length(outcome_list) > 1)
			log_world("CUSTOM_EMPLOYERS: [employer_name] 的 outcome 写了多个值；同时进两张结局表会永远抽不到，已取第一个")
		outcome = length(outcome_list) ? outcome_list[1] : null
	outcome = LOWER_TEXT(outcome)
	if(outcome == "hijack")
		GLOB.hijack_employers += employer_name
	else if(outcome != "both")
		GLOB.normal_employers += employer_name

	// 3) flavor 文本（照上游 traitor_flavor.json 的键名；ui_theme 非法时回退阵营默认）
	var/theme = entry["ui_theme"]
	if(istext(theme))
		theme = LOWER_TEXT(theme)
	if(!(theme in GLOB.tianguan_employer_themes))
		theme = GLOB.tianguan_employer_faction_themes[faction] || "syndicate"

	flavor_table[employer_name] = list(
		"allies" = tianguan_employer_text(entry["allies"], employer_name, "没有额外的盟友指示。"),
		"goal" = tianguan_employer_text(entry["goal"], employer_name, "雇主这次没留下什么想法。"),
		"introduction" = tianguan_employer_text(introduction, employer_name),
		"roundend_report" = tianguan_employer_text(entry["roundend_report"], employer_name, "曾是[employer_name]的叛徒。"),
		"ui_theme" = theme,
		"uplink" = tianguan_employer_text(entry["uplink"], employer_name, "你已获得一台标准上行链路，用它完成任务。"),
	)
	return TRUE

/// 取一条 flavor 文本：空/缺失时用默认句，并把 {name} 换成雇主名。
/proc/tianguan_employer_text(value, employer_name, default_text = "")
	if(!istext(value) || !length(value))
		return default_text
	return replacetext(value, TIANGUAN_EMPLOYER_NAME_TOKEN, employer_name)

#undef TIANGUAN_CUSTOM_EMPLOYERS_FILE
#undef TIANGUAN_EMPLOYER_NAME_TOKEN
#undef TIANGUAN_EMPLOYER_FACTION_SYNDICATE
#undef TIANGUAN_EMPLOYER_FACTION_NANOTRASEN
#undef TIANGUAN_EMPLOYER_FACTION_UAR
