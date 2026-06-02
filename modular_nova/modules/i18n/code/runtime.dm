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

/// 核心（纯函数）：按 locale 查模板（缺则回退英文，再缺则返回 key），最后做占位符替换。
/proc/lang_resolve(key, list/args, locale)
	if(isnull(locale))
		locale = GLOB.i18n_server_locale || DEFAULT_UI_LOCALE

	var/template = lang_template(key, locale)
	if(isnull(template) && locale != DEFAULT_UI_LOCALE)
		template = lang_template(key, DEFAULT_UI_LOCALE) // 回退到英文源串

	if(isnull(template))
		return key // 兜底：返回 key，避免崩溃

	return lang_interpolate(template, args)

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
	return reverse[text] || text

/// 「多词」门槛的反查：仅含空白（多词/短语）的串才查表，避免把 On/None/枚举值/ckey 这类
/// 单词误翻（动态数据常正好等于某常见词）。短语类（datum 的 desc、多词 name）才反查。
/proc/lang_reverse_phrase(text)
	if(!istext(text) || !findtext(text, " "))
		return text
	return lang_reverse_text(text)

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
			// 关联项：key -> value，只本地化 value
			if(islist(value))
				lang_reverse_tree(value)
			else if(istext(value))
				data[key] = lang_reverse_phrase(value)
		else
			// flat 元素（无关联值）
			if(islist(key))
				lang_reverse_tree(key)
			else if(istext(key))
				data[i] = lang_reverse_phrase(key)
	return data
