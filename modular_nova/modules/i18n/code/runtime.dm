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
/proc/lang_interpolate(template, list/args)
	if(!length(args))
		return template
	var/result = template
	for(var/i in 1 to length(args))
		result = replacetext(result, "{[i - 1]}", "[args[i]]")
	return result

/// BYOND 文法宏（\the \a \improper 等，无参、由引擎按名词上下文在**编译期/输出期**处理）。模板从 JSON
/// 加载后引擎不再处理 → 会字面显示。中文无冠词/复数、且上下文已丢失，直接剥掉。`\b` 防 \theory 等误伤；
/// 已转义的反斜杠（\\）开头不会被这里的单反斜杠模式吃掉。只列已知文法宏，不碰 \n \t \" 等真转义。
GLOBAL_VAR_INIT(i18n_text_macro_regex, regex(@"\\(improper|proper|themselves|theirs|himself|herself|itself|their|them|they|roman|Roman|the|The|hers|she|She|her|his|him|its|it|It|he|He|an|An|a|A)\b", "g"))

/// 处理从 JSON 模板带出的 BYOND 转义/文法宏（rewrite 把编译期字面量改成 LANG 后，这些转义不再被引擎
/// 处理）：① 剥文法宏；② 还原转义引号 \" → "。仅在串含反斜杠时调用。
/proc/lang_process_text_escapes(text)
	if(!istext(text))
		return text
	var/regex/macro_re = GLOB.i18n_text_macro_regex
	text = macro_re.Replace(text, "")
	text = replacetext(text, "\\\"", "\"") // \" → "
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

	GLOB.i18n_reverse[locale] = reverse
	return reverse

/// 把一段英文整串反查为全服 locale 的译文；查不到/缺省 locale 时原样返回。
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
			data[key] = lang_reverse_text(value)
	return data
