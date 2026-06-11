// NovaSector 全量汉化 (i18n) —— 运行时查表与格式化。
//
// 目录文件：strings/i18n/<locale>/<namespace>.json，扁平的 {"key": "模板"}。
// 模板用位置占位符 {0}/{1}…，允许按中文语序重排参数。
//
// 设计要点：目录在「启动时一次性加载」(GLOBAL_LIST_INIT)，之后 LANG 读取路径**只读**，
// 是纯函数——可安全用于标了 SpacemanDMM_should_be_pure 的 proc（如各类 examine 辅助）。

/// 全服默认 locale。中文服在 config 写 I18N_SERVER_LOCALE zh-Hans（见 config_entries.dm）。
GLOBAL_VAR_INIT(i18n_server_locale, DEFAULT_UI_LOCALE)

/// 是否启用聊天层 AC 子串兜底（默认关）。config I18N_CHAT_FALLBACK 控制（见 config_entries.dm + fallback.dm）。
GLOBAL_VAR_INIT(i18n_chat_fallback, FALSE)

/// locale -> (key -> 模板)。启动时加载，运行期只读。
GLOBAL_LIST_INIT(i18n_cache, build_i18n_cache())

/// 扫描 strings/i18n/ 下各 locale 目录，加载全部 .json。仅启动时调用（GLOBAL_LIST_INIT）。
/proc/build_i18n_cache()
	var/list/cache = list()
	var/base = "[STRING_DIRECTORY]/[I18N_SUBDIRECTORY]/"
	if(!fexists(base))
		return cache
	for(var/locale_entry in flist(base))
		if(!findtext(locale_entry, "/", -1)) // 只要目录（flist 给目录名带尾部 "/"）
			continue
		var/locale = copytext(locale_entry, 1, -1) // 去掉尾部 "/"
		var/list/merged = list()
		var/dir = "[base][locale_entry]"
		for(var/filename in flist(dir))
			if(!findtext(filename, ".json", -length(".json")))
				continue
			var/list/decoded = json_decode(file2text("[dir][filename]"))
			if(!islist(decoded))
				continue
			for(var/key in decoded)
				merged[key] = decoded[key]
		cache[locale] = merged
	return cache

/// 纯读：取某 locale 下某 key 的模板；缺失返回 null。
/proc/lang_template(key, locale)
	var/list/catalog = GLOB.i18n_cache[locale]
	return catalog?[key]

/// 把模板里的 {0}/{1}… 用 args 依次替换（args 为 /list，元素按位置对应）。
/// 文本实参经 lang_localize_arg 本地化链（仅全服 locale≠en；en 零额外开销）。
/proc/lang_interpolate(template, list/args)
	if(!length(args))
		return template
	var/localize = GLOB.i18n_server_locale != DEFAULT_UI_LOCALE
	var/result = template
	for(var/i in 1 to length(args))
		var/arg = args[i]
		if(localize && istext(arg))
			arg = lang_localize_arg(arg)
		result = replacetext(result, "{[i - 1]}", "[arg]")
	return result

/// LANG 实参/引擎捕获的统一本地化链：状态词 → 代词/系动词 → 整串反查 → 冠词剥离反查。
/// 解决「模板译了、运行期填进来的实参却是英文」的四类：
///   ① 开关/状态词（open/closed/lit…，`_state_words.json` 精确表）；
///   ② 代词与系动词（p_They()/p_are() 的 They/are → 他们/是，lang_pronoun 专用小表）；
///   ③ 目录里有的整串（安全等级 "green"→绿色、"None"→无——按值精确反查）；
///   ④ 带英文冠词的名字（"\the [src]"/"\a [x]" 渲染出的 "The wall"/"a Monkey"——剥冠词反查
///      余下部分（再试小写），命中则丢冠词：中文无冠词）。
/// 全部是精确匹配，查不到原样保留（玩家名/数字/已中文串零误伤）。
/proc/lang_localize_arg(arg)
	if(!length(arg))
		return arg
	var/list/state_words = lang_state_words()
	var/translated = state_words[arg]
	if(translated)
		return translated
	translated = lang_pronoun(arg)
	if(translated != arg)
		return translated
	translated = lang_reverse_text(arg)
	if(translated != arg)
		return translated
	var/stripped = lang_strip_article(arg)
	if(stripped)
		translated = lang_reverse_text(stripped)
		if(translated != stripped)
			return translated
		var/lowered = LOWER_TEXT(stripped)
		if(lowered != stripped)
			translated = lang_reverse_text(lowered)
			if(translated != lowered)
				return translated
	return arg

/// 若文本以英文冠词开头（the/a/an，含大写），返回去冠词后的余部；否则 null。
/proc/lang_strip_article(text)
	var/static/list/articles = list("the ", "The ", "a ", "an ", "A ", "An ")
	for(var/article in articles)
		var/alen = length(article)
		if(length(text) > alen && findtextEx(text, article, 1, alen + 1))
			return copytext(text, alen + 1)
	return null

/// 惰性加载「状态词 → 译文」表（全服 locale≠en 时读 strings/i18n/<locale>/_state_words.json；en 为空）。
/// 惰性而非 GLOBAL_LIST_INIT：避免在 i18n_server_locale 设置前被钉死成空表。
GLOBAL_LIST_EMPTY(i18n_state_words)
GLOBAL_VAR_INIT(i18n_state_words_loaded, FALSE)
/proc/lang_state_words()
	if(GLOB.i18n_state_words_loaded)
		return GLOB.i18n_state_words
	var/locale = GLOB.i18n_server_locale || DEFAULT_UI_LOCALE
	if(locale != DEFAULT_UI_LOCALE)
		var/path = "[STRING_DIRECTORY]/[I18N_SUBDIRECTORY]/[locale]/_state_words.json"
		if(fexists(path))
			var/list/decoded = json_decode(file2text(path))
			if(islist(decoded))
				for(var/word in decoded)
					GLOB.i18n_state_words[word] = decoded[word]
	GLOB.i18n_state_words_loaded = TRUE
	return GLOB.i18n_state_words

/// BYOND 文法宏（\the \a \improper 等，无参、由引擎按名词上下文在**编译期/输出期**处理）。模板从 JSON
/// 加载后引擎不再处理 → 会字面显示。中文无冠词/复数、且上下文已丢失，直接剥掉。`\b` 防 \theory 等误伤；
/// 已转义的反斜杠（\\）开头不会被这里的单反斜杠模式吃掉。只列已知文法宏，不碰 \n \t \" 等真转义。
GLOBAL_VAR_INIT(i18n_text_macro_regex, regex(@"\\(improper|proper|themselves|theirs|himself|herself|itself|their|them|they|roman|Roman|the|The|hers|she|She|her|his|him|its|it|It|he|He|an|An|a|A)\b", "g"))

/// 处理从 JSON 模板带出的 BYOND 转义/文法宏（rewrite 把编译期字面量改成 LANG 后，这些转义不再被引擎
/// 处理）：① 剥文法宏；② 还原转义引号 \" → "；③ 还原 \n → 换行、\t → 制表符。
/// 源码里 `"\n"` 是 DM 编译期换行转义；抽取器把它当**字面 2 字符** `\n` 存进 JSON（`"\\n"`），LANG 从
/// JSON 取回后引擎不再解释 → 会字面显示 `\n`（如警棍 examine「\n它当前为…」）。在此还原。仅在串含反斜杠时调用。
/proc/lang_process_text_escapes(text)
	if(!istext(text))
		return text
	var/regex/macro_re = GLOB.i18n_text_macro_regex
	text = macro_re.Replace(text, "")
	text = replacetext(text, "\\\"", "\"") // \" → "
	text = replacetext(text, "\\n", "\n") // 字面 \n → 换行
	text = replacetext(text, "\\t", "\t") // 字面 \t → 制表符
	return text

/// 核心（纯函数）：按 locale 查模板（缺则回退英文，再缺则返回 key），最后做占位符替换。
/proc/lang_resolve(key, list/args, locale)
	if(isnull(locale))
		locale = GLOB.i18n_server_locale || DEFAULT_UI_LOCALE

	var/template = lang_template(key, locale)
	if(isnull(template) && locale != DEFAULT_UI_LOCALE)
		template = lang_template(key, DEFAULT_UI_LOCALE) // 回退到英文源串

	if(isnull(template))
		return key // 兜底：返回 key，避免崩溃

	. = lang_interpolate(template, args)
	if(findtext(., "\\")) // 仅含反斜杠（文法宏/转义）时才处理，绝大多数消息直接返回
		. = lang_process_text_escapes(.)

/// 全服 locale 版本（广播类文本用）。见 LANG 宏。
/proc/lang_format(key, list/args)
	return lang_resolve(key, args, null)

/// 兼容旧调用的单接收者入口；当前部署模式强制使用全服 locale。
/proc/lang_format_for(mob/user, key, list/args)
	return lang_resolve(key, args, null)

// ---- 反查表（name/desc 等「变量类」文本接入运行时）----
//
// 变量初始化（name = "..."）无法改写成 LANG()（DM 变量初值需常量），所以改为：在 Initialize
// 期把英文整串反查成译文。反查表 = 英文原文 -> 译文，仅含「无占位符的纯字符串」（name/desc
// 几乎都是纯字符串）。译文随 Codex/Tolgee 落地自动生效，无需再改代码。

/// locale -> (英文原文 -> 译文)。惰性构建（写 GLOB，仅供 /atom/Initialize 等非纯路径调用）。
GLOBAL_LIST_EMPTY(i18n_reverse)

/// 剥掉 BYOND 文法宏 \improper/\proper，得到「显示形态」串。
/// 两种来源都要剥：① 运行时 name/desc 里是**编译期标记字节**（DM 源写 "\improper" 即该字节，
/// 故 replacetext 用 "\improper" 能匹配）；② 目录 JSON 里存的是**字面** "\improper"（反斜杠+improper，
/// 用 "\\improper" 匹配）。规整到无宏并 trim，使两端对齐（否则带 \improper 的名永远查不中）。
/proc/lang_strip_grammar_macros(text)
	if(!istext(text))
		return text
	text = replacetext(text, "\improper", "") // 运行时标记字节形态
	text = replacetext(text, "\proper", "")
	text = replacetext(text, "\\improper", "") // 目录字面形态
	text = replacetext(text, "\\proper", "")
	return trim(text)

/// 惰性构建某 locale 的反查表（从已加载的 GLOB.i18n_cache 读取）。
/proc/lang_build_reverse(locale)
	if(GLOB.i18n_reverse[locale])
		return GLOB.i18n_reverse[locale]

	var/list/english = GLOB.i18n_cache[DEFAULT_UI_LOCALE]
	var/list/localized = GLOB.i18n_cache[locale]
	// i18n_cache 尚未就绪（极早期 GLOBAL_LIST_INIT 期间被调用）：返回空表但**不缓存**，
	// 否则会把空反查表钉死到 GLOB.i18n_reverse[locale]，毒化之后所有反查。
	if(!islist(english) || !islist(localized))
		return list()
	var/list/reverse = list()
	for(var/key in english)
		var/en_text = english[key]
		if(findtext(en_text, "{")) // 带占位符的走 LANG 调用，不走反查
			continue
		var/translated = localized[key]
		if(translated && translated != en_text)
			reverse[en_text] = translated
			// 文法宏对齐：额外登记「剥宏」形态键，让运行时带标记字节的 name（如
			// "\improper Space Cigarettes packet"）也能命中（值同样剥宏，去掉中文里多余的 \improper）。
			if(findtext(en_text, "\\improper") || findtext(en_text, "\\proper"))
				var/stripped_key = lang_strip_grammar_macros(en_text)
				if(stripped_key && !reverse[stripped_key])
					reverse[stripped_key] = lang_strip_grammar_macros(translated)
			// 转义引号对齐：目录里的 `\"` 是 dreammaker 解析器保留的源码转义，但 BYOND 运行时字符串里
			// 是裸 `"`，反查（输入=运行时串）查带 `\"` 的 key 永远不命中 → 额外登记「裸引号」形态键。
			// 影响所有含转义引号的玩家可见文本（物种 lore、带引号的 name/desc 等）。译文同样去转义。
			if(findtext(en_text, "\\\""))
				var/unescaped_key = replacetext(en_text, "\\\"", "\"")
				if(unescaped_key != en_text && !reverse[unescaped_key])
					reverse[unescaped_key] = replacetext(translated, "\\\"", "\"")

	GLOB.i18n_reverse[locale] = reverse
	return reverse

/// 把一段英文整串反查为全服 locale 的译文；查不到/缺省 locale 时原样返回。
/// 把连续空格/制表符折叠成单空格，对齐抽取器对 DM "\" 续行的归一：源码里
/// `"… foo \`<换行><制表符>`bar …"` 在 DM 运行时会把续行的前导制表符并入字符串
/// （变成 "foo \t\tbar"），而抽取器把它归一成单空格（"foo bar"）→ 整串反查不命中。
/// 只折叠空格/制表符，保留换行（有意的多段 \n 不动）。
/proc/lang_collapse_ws(text)
	if(!istext(text))
		return text
	var/static/regex/ws_run = regex(@"[ \t]+", "g")
	return ws_run.Replace(text, " ")

/proc/lang_reverse_text(text)
	if(!text)
		return text
	var/locale = GLOB.i18n_server_locale || DEFAULT_UI_LOCALE
	if(locale == DEFAULT_UI_LOCALE)
		return text
	var/list/reverse = lang_build_reverse(locale)
	. = reverse[text]
	if(!isnull(.))
		return .
	// 未直接命中：若含文法宏标记字节，剥宏后再查一次（对齐目录里的剥宏形态键）。
	if(findtext(text, "\improper") || findtext(text, "\proper"))
		. = reverse[lang_strip_grammar_macros(text)]
		if(!isnull(.))
			return .
	// 仍未命中：DM 把 "\" 续行的前导制表符并入字符串、抽取器却归一成单空格 → 折叠后再查一次。
	if(findtext(text, "\t"))
		. = reverse[lang_collapse_ws(text)]
		if(!isnull(.))
			return .
	return text

/// 「多词」门槛的反查：仅含空白（多词/短语）的串才查表，避免把 On/None/枚举值/ckey 这类
/// 单词误翻（动态数据常正好等于某常见词）。短语类（datum 的 desc、多词 name）才反查。
/proc/lang_reverse_phrase(text)
	if(!istext(text) || !findtext(text, " "))
		return text
	return lang_reverse_text(text)

/// TGUI 前端目录（en/tgui.json）里的英文串集合。这些串由 TS 端 auto-localize **只翻显示**，
/// 故 P1（lang_reverse_tree）必须跳过它们——很多是 act() 标识符（职业名/怪癖名/配件名…），
/// 改了 ui_data 值会破坏操作；交给 TS 端翻显示、数据保持英文最安全。同时这也覆盖了**单词类**
/// 标识符名（P1 的多词门槛本就漏掉、但 TS 端无门槛能翻）。启动加载、运行只读。
GLOBAL_LIST_INIT(i18n_tgui_strings, build_tgui_string_set())

/proc/build_tgui_string_set()
	var/list/result = list()
	var/path = "[STRING_DIRECTORY]/[I18N_SUBDIRECTORY]/[DEFAULT_UI_LOCALE]/tgui.json"
	if(!fexists(path))
		return result
	var/list/decoded = json_decode(file2text(path))
	if(islist(decoded))
		for(var/key in decoded)
			result[key] = TRUE
	return result

/// TGUI 负载专用反查：若该串属于 TGUI 前端目录（TS 端会翻显示），P1 跳过不动数据（保住标识符）；
/// 否则走多词反查（datum 描述等不在前端目录的长文本）。
/proc/lang_reverse_phrase_tgui(text)
	// islist 守卫：i18n_tgui_strings 是 GLOBAL_LIST_INIT，极早期（如 construct_phobia_regex 等全局变量
	// 初始化期）调用 load_strings_file→lang_reverse_tree 时它可能尚未就绪，直接索引会 bad index 崩溃，
	// 进而把加载的串写成 null、破坏 phobia 等早期数据。未就绪时跳过跳过集判断，走多词反查
	// （lang_build_reverse 已加固：cache 未就绪返回空表、原样返回，不崩不污染）。
	if(istext(text) && islist(GLOB.i18n_tgui_strings) && GLOB.i18n_tgui_strings[text])
		return text
	return lang_reverse_phrase(text)

/// TGUI 负载里**既是显示又是 act() 回传标识符**的列表键——这些 list 的字符串元素会原样回传给
/// 服务端做相等校验（tgui_alert 的 buttons 经 `act('choose',{choice:button})` 校验 `in buttons`；
/// tgui_input_list 的 items 经 `act('choose',{entry})` 校验 `in items`）。若 P1 把它们译成中文，
/// 前端回传中文、服务端用英文校验 → tgui_alert 直接 CRASH「non-existent button choice」、list 静默失败。
/// 故 lang_reverse_tree 必须**跳过这些键的值**（保持英文标识符）；显示交给 TS 端 auto-localize 翻
/// （`{button}` 文本节点过前端目录），值不动。新增同类回传列表键时在此登记即可。
GLOBAL_LIST_INIT(i18n_payload_skip_keys, list(\
	"buttons" = TRUE,\
	"items" = TRUE,\
	"init_value" = TRUE,\
))

/// 递归把一个 list（含嵌套 list / 关联 list）里的字符串「值」按多词门槛反查为全服 locale 译文。
/// 用于 TGUI 的 ui_data/ui_static_data 负载：把非 atom datum 的 name/desc/说明等动态内容本地化。
/// key 不动（程序用的标识）；就地改写并返回。幂等（已译的中文不会再匹配英文 key）。
/proc/lang_reverse_tree(list/data)
	if(!islist(data))
		return data
	for(var/i in 1 to length(data))
		var/key = data[i]
		var/value = (istext(key) || ispath(key)) ? data[key] : null
		if(!isnull(value))
			// act 标识符回传列表（buttons/items/…）：保持英文，否则破坏回传校验（见 i18n_payload_skip_keys）。
			// islist 守卫：早期 load_strings_file→lang_reverse_tree 调用时该 GLOBAL_LIST_INIT 可能未就绪。
			if(istext(key) && islist(GLOB.i18n_payload_skip_keys) && GLOB.i18n_payload_skip_keys[key])
				continue
			// 关联项：key -> value，只本地化 value
			if(islist(value))
				lang_reverse_tree(value)
			else if(istext(value))
				data[key] = lang_reverse_phrase_tgui(value)
		else
			// flat 元素（无关联值）
			if(islist(key))
				lang_reverse_tree(key)
			else if(istext(key))
				data[i] = lang_reverse_phrase_tgui(key)
	return data

/// 偏好菜单「常量数据 asset」(/datum/asset/json/preferences) 是服务器启动生成一次的静态资源，
/// **不经 get_payload**，故 lang_reverse_tree 永远碰不到它。此 pass 专供该 asset：只反查
/// **纯显示字段**（各种 description）——这些绝非 act() 标识符，可安全整串替换（用 lang_reverse_text
/// 全量匹配，无多词门槛，短描述也能命中）；name/title/choices/department 等是标识符，一律不动。
/// 递归走嵌套 list。全服 locale==en 时 lang_reverse_text 直接原样返回（零行为变化）。
GLOBAL_LIST_INIT(i18n_pref_desc_keys, list(\
	"description" = TRUE,\
	"pos_gameplay_description" = TRUE,\
	"neg_gameplay_description" = TRUE,\
	"neut_gameplay_description" = TRUE,\
))

/proc/lang_reverse_pref_descriptions(list/data)
	if(!islist(data))
		return data
	for(var/i in 1 to length(data))
		var/key = data[i]
		var/value = (istext(key) || ispath(key)) ? data[key] : null
		if(isnull(value))
			if(islist(key))
				lang_reverse_pref_descriptions(key)
			continue
		if(islist(value))
			lang_reverse_pref_descriptions(value)
		else if(istext(value) && GLOB.i18n_pref_desc_keys[key])
			// 先折叠续行制表符对齐目录键（job 描述常用 "\" 续行，运行期带制表符 → 否则连基础句都不命中）。
			var/collapsed = lang_collapse_ws(value)
			var/translated = lang_reverse_text(collapsed)
			// 整串无精确匹配时退到 AC 子串层：command/sec 职业描述在运行期是「基础句 + antag 后缀」拼接
			//（" Targetable by contractors." 等），整串不是目录键，但基础句与各后缀短语都在目录里 → 逐段子串命中。
			if(translated == collapsed)
				translated = lang_fallback_apply(collapsed)
			data[key] = translated
	return data

/// 职业描述本地化（偏好菜单职业 tab 的 tooltip）。antag_opt_in 模块把「opt-in 后缀句」拼到
/// description 末尾（`description = initial(description) + suffix`，见 antag_opt_in/code/job.dm），
/// 于是运行期整串 = 基础句 + 后缀，**整串非目录键** → lang_reverse_pref_descriptions 的整串精确
/// 反查必然 miss，AC 子串对长基础句也不稳。这里用 initial() 取回**基础句**单独精确反查（基础句是
/// 目录键，折叠续行制表符后命中），后缀短语各自在目录里 → 走 AC；拼回。无后缀的职业直接整串反查。
/// 全服 locale==en 时原样返回（零行为变化）。供 middleware/jobs.dm 调用。
/proc/lang_localize_job_description(datum/job/job)
	var/desc = job.description
	if(!istext(desc) || GLOB.i18n_server_locale == DEFAULT_UI_LOCALE)
		return desc
	var/base = initial(job.description)
	var/base_collapsed = lang_collapse_ws(base)
	var/base_zh = lang_reverse_text(base_collapsed)
	if(base_zh == base_collapsed) // 精确未命中 → 退 AC 子串
		base_zh = lang_fallback_apply(base_collapsed)
	if(desc == base) // 无 opt-in 后缀
		return base_zh
	// desc = base + suffix：后缀短语（" Targetable by contractors." 等）各自在目录 → AC。
	var/suffix = copytext(desc, length(base) + 1)
	return base_zh + lang_fallback_apply(lang_collapse_ws(suffix))

/// 中文时长格式（无英文复数 / 无 " and " 连接词）。core 的 DisplayTimeText 在全服中文时改调此处。
/// 当前为 zh-Hans 用词（天/小时/分钟/秒）——这是唯一非英文 locale；未来加 locale 时在此分支即可。
/// 与 core DisplayTimeText 的分段逻辑一一对应，只换用词与拼接（中文直接连写）。
/proc/lang_display_time_text(time_value, round_seconds_to = 0.1)
	var/second = FLOOR(time_value * 0.1, round_seconds_to)
	if(!second)
		return "就在此刻"
	if(second < 60)
		return "[second]秒"
	var/minute = FLOOR(second / 60, 1)
	second = FLOOR(MODULUS(second, 60), round_seconds_to)
	var/secondT = second ? "[second]秒" : ""
	if(minute < 60)
		return "[minute]分钟[secondT]"
	var/hour = FLOOR(minute / 60, 1)
	minute = MODULUS(minute, 60)
	var/minuteT = minute ? "[minute]分钟" : ""
	if(hour < 24)
		return "[hour]小时[minuteT][secondT]"
	var/day = FLOOR(hour / 24, 1)
	hour = MODULUS(hour, 24)
	var/hourT = hour ? "[hour]小时" : ""
	return "[day]天[hourT][minuteT][secondT]"

/// 身体部位名的**专用**反查（避开「chest=胸部 vs 储物箱」这类单词全局碰撞——只在部位语境调用）。
/// 当前 zh-Hans 用词；core 的 parse_zone（部位 define→显示名）与 plaintext_zone（部位文本）显示处调用。
/// locale==en 或非部位串 → 原样返回。键含多词部位（与全局目录值一致，无冲突）+ 单词部位（全局不收）。
/proc/lang_zone(zone_text)
	if(!istext(zone_text) || GLOB.i18n_server_locale == DEFAULT_UI_LOCALE)
		return zone_text
	var/static/list/zmap = list(
		"chest" = "胸部",
		"head" = "头部",
		"groin" = "腹股沟",
		"left arm" = "左臂",
		"right arm" = "右臂",
		"left leg" = "左腿",
		"right leg" = "右腿",
		"left hand" = "左手",
		"right hand" = "右手",
		"left foot" = "左脚",
		"right foot" = "右脚",
		"mouth" = "嘴",
		"eyes" = "眼睛",
	)
	return zmap[zone_text] || zone_text

/// 材料名的**专用**反查（gold/glass/iron… → 中文）。不走全局反查——单词类材料名与日常词碰撞
/// （gold=黄金/金色、glass=玻璃/杯，MT 全局已按错义译），专用映射只在「确知是材料」的显示处调用
/// （examine 的「由…制成」），零碰撞、按材料义翻。未来加 locale 时在此分支扩展。
/proc/lang_material(material_name)
	if(!istext(material_name) || GLOB.i18n_server_locale == DEFAULT_UI_LOCALE)
		return material_name
	var/static/list/mmap = list(
		"adamantine" = "精金",
		"alien alloy" = "异星合金",
		"alloy" = "合金",
		"bamboo" = "竹",
		"bananium" = "香蕉合金",
		"biomass" = "生物质",
		"bluespace crystal" = "蓝空间晶体",
		"bone" = "骨",
		"bronze" = "青铜",
		"cardboard" = "瓦楞纸板",
		"diamond" = "钻石",
		"glass" = "玻璃",
		"gold" = "黄金",
		"hauntium" = "怨灵金属",
		"hot ice" = "热冰",
		"iron" = "铁",
		"meat" = "肉",
		"Metal Hydrogen" = "金属氢",
		"mythril" = "秘银",
		"paper" = "纸",
		"pizza" = "披萨",
		"plasma" = "等离子体",
		"plasmaglass" = "等离子玻璃",
		"plasteel" = "塑钢",
		"plastic" = "塑料",
		"plastitanium" = "塑钛",
		"plastitanium glass" = "塑钛玻璃",
		"rock" = "岩石",
		"runed metal" = "符文金属",
		"runite" = "符文矿",
		"sand" = "沙子",
		"sandstone" = "砂岩",
		"silver" = "白银",
		"snow" = "雪",
		"telecrystal" = "电讯水晶",
		"titanium" = "钛",
		"titanium glass" = "钛玻璃",
		"uranium" = "铀",
		"wood" = "木材",
		"zaukerite" = "扎克石",
	)
	return mmap[material_name] || material_name

/// 代词的**专用**反查（he/she/it/is/his/him… → 中文）。不走全局反查——it/is/his 等是极常见短词，
/// 全局整串反查会误伤正好等于这些词的动态数据；专用映射只在代词 proc / 模板代词实参处调用，零碰撞。
/// 只覆盖可干净映射的代词与系动词（is/are→是、has/have→有）；语法后缀（does/do/s/es）保持英文。
/// 大小写无关（中文无大小写）：按小写查，命中返回中文、否则原样（含 capitalize 后的英文回退）。
/proc/lang_pronoun(word)
	if(!istext(word) || GLOB.i18n_server_locale == DEFAULT_UI_LOCALE)
		return word
	var/static/list/pmap = list(
		"he" = "他", "she" = "她", "it" = "它", "they" = "他们",
		"him" = "他", "her" = "她", "them" = "他们",
		"his" = "他的", "hers" = "她的", "its" = "它的", "their" = "他们的", "theirs" = "他们的",
		"himself" = "他自己", "herself" = "她自己", "itself" = "它自己", "themselves" = "他们自己",
		"is" = "是", "are" = "是", "has" = "有", "have" = "有", "was" = "是", "were" = "是",
	)
	return pmap[LOWER_TEXT(word)] || word

/// 物种「描述」可能是字符串（多数物种 `return placeholder_description` / 单段裸串）或字符串列表
/// （shadekin 等多段 `return list("段1","段2")`）——按类型分派反查。get_species_description 两种返回
/// 都有，单用 lang_reverse_text 会漏掉 list 形态（且对 list 反查无意义）。
/proc/lang_reverse_text_or_list(value)
	if(islist(value))
		return lang_reverse_string_list(value)
	return lang_reverse_text(value)

/// 反查一个字符串列表的每个元素（用于物种 lore：list("段1", "段2", …) 逐段整串反查）。
/// 全服中文时就地改写并返回；locale==en 原样返回。
/proc/lang_reverse_string_list(list/strings)
	if(!islist(strings) || GLOB.i18n_server_locale == DEFAULT_UI_LOCALE)
		return strings
	for(var/i in 1 to length(strings))
		if(istext(strings[i]))
			strings[i] = lang_reverse_text(strings[i])
	return strings

/// 反查物种特征(perk)结构里的 name/description（结构：assoc[perk_type] = list of perk(assoc)）。
/// 静态 perk 串命中目录即译；perk 描述经 rewrite 已 LANG 化（模板可译），但插值实参里的**物种名**
/// （[name]/[plural_form]）运行时填的是英文 → 此处按物种名整词替换为中文译名（物种名在目录已译）。
/// 传入 species 以取其 name/plural_form。就地改写并返回。
/proc/lang_reverse_perks(list/perks, datum/species/species)
	if(!islist(perks) || GLOB.i18n_server_locale == DEFAULT_UI_LOCALE)
		return perks
	// 预编译「英文物种名 -> 中文译名」的整词正则（`\b` 词界防 Human→Humanoid 这类子串误伤）。
	var/list/name_subs = list() // regex -> 中文
	if(istype(species))
		for(var/en_name in list(species.name, species.plural_form))
			if(!istext(en_name) || !length(en_name))
				continue
			var/zh = lang_reverse_text(en_name)
			if(zh != en_name && !(en_name in name_subs)) // 已译且未登记
				name_subs[regex("\\b[en_name]\\b")] = zh
	for(var/perk_type in perks)
		var/list/perk_list = perks[perk_type]
		if(!islist(perk_list))
			continue
		for(var/list/perk in perk_list)
			if(!islist(perk))
				continue
			perk[SPECIES_PERK_NAME] = lang_localize_perk_text(perk[SPECIES_PERK_NAME], name_subs)
			perk[SPECIES_PERK_DESC] = lang_localize_perk_text(perk[SPECIES_PERK_DESC], name_subs)
	return perks

/// 单条 perk 文本本地化：先整串反查（兼容未 LANG 化的静态 perk），再按预编译正则替换物种名。
/proc/lang_localize_perk_text(text, list/name_subs)
	if(!istext(text))
		return text
	text = lang_reverse_text(text)
	for(var/regex/word_re in name_subs)
		text = word_re.Replace(text, name_subs[word_re])
	return text
