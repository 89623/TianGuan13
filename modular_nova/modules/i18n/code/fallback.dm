// NovaSector 全量汉化 (i18n) —— 运行时英→中兜底层（Aho-Corasick）。
//
// 对「尚未被 LANG/LANGU 改写」或「无法静态抽取」的残留英文，在输出边界做一次多模式
// 子串替换。来源：strings/i18n/<locale>/_fallback.json，扁平的 {"english": "中文"}。
// 注意：纯子串替换，不保证语序正确，仅用于过渡期与长尾「不漏英文」。已被 LANG 处理过的
// 文本不应再过此层（避免二次替换）。

/// locale -> "ready" | "none"，避免重复读盘/重复 setup。
GLOBAL_LIST_EMPTY(i18n_fallback_state)

/// 惰性为某 locale 注册 AC 字典；返回是否可用。
/proc/lang_fallback_setup(locale)
	var/state = GLOB.i18n_fallback_state[locale]
	if(state)
		return state == "ready"

	var/path = "[STRING_DIRECTORY]/[I18N_SUBDIRECTORY]/[locale]/_fallback.json"
	if(!fexists(path))
		GLOB.i18n_fallback_state[locale] = "none"
		return FALSE

	var/list/dict = json_decode(file2text(path))
	if(!length(dict))
		GLOB.i18n_fallback_state[locale] = "none"
		return FALSE

	var/list/patterns = list()
	var/list/replacements = list()
	for(var/english in dict)
		patterns += english
		replacements += dict[english]

	rustg_setup_acreplace("i18n_[locale]", patterns, replacements)
	GLOB.i18n_fallback_state[locale] = "ready"
	return TRUE

/// 对一段文本应用兜底替换。locale 为 null 时用全服 locale；缺省 locale（英文）直接返回。
/proc/lang_fallback_apply(text, locale)
	if(isnull(locale))
		locale = GLOB.i18n_server_locale || DEFAULT_UI_LOCALE
	if(locale == DEFAULT_UI_LOCALE)
		return text
	if(!lang_fallback_setup(locale))
		return text
	return rustg_acreplace("i18n_[locale]", text)
