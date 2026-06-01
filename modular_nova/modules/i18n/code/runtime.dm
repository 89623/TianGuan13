// NovaSector 全量汉化 (i18n) —— 运行时查表与格式化。
//
// 目录文件：strings/i18n/<locale>/<namespace>.json，扁平的 {"key": "模板"}。
// 模板用位置占位符 {0}/{1}…，允许按中文语序重排参数。
// 复用 code/__HELPERS/_string_lists.dm 的 json_load / file2text 思路，惰性加载并缓存整个 locale。

/// 全服默认 locale。中文服可在配置/启动时设为 LANGUAGE_LOCALE_ZH_HANS。
GLOBAL_VAR_INIT(i18n_server_locale, DEFAULT_UI_LOCALE)

/// locale -> (key -> 模板) 的二级缓存。
GLOBAL_LIST_EMPTY(i18n_cache)

/// 运行期缺失的 key 集合（locale|key -> TRUE），供单元测试/CI 检查覆盖率。
GLOBAL_LIST_EMPTY(i18n_missing_keys)

/// 惰性加载某个 locale 的全部目录文件到 GLOB.i18n_cache。
/proc/lang_load_locale(locale)
	if(GLOB.i18n_cache[locale])
		return GLOB.i18n_cache[locale]

	var/list/merged = list()
	var/dir = "[STRING_DIRECTORY]/[I18N_SUBDIRECTORY]/[locale]/"
	if(fexists(dir))
		for(var/filename in flist(dir))
			// 只读 .json，跳过子目录（flist 给目录名带尾部 "/"）。
			if(!findtext(filename, ".json", -length(".json")))
				continue
			var/list/decoded = json_decode(file2text("[dir][filename]"))
			if(!islist(decoded))
				continue
			for(var/key in decoded)
				merged[key] = decoded[key]

	GLOB.i18n_cache[locale] = merged
	return merged

/// 取某 locale 下某 key 的模板；缺失返回 null（不缓存缺失，交由调用方回退）。
/proc/lang_template(key, locale)
	var/list/catalog = lang_load_locale(locale)
	return catalog[key]

/// 把模板里的 {0}/{1}… 用 args 依次替换（args 为 /list，元素按位置对应）。
/// 支持 {{ }} 字面花括号转义。
/proc/lang_interpolate(template, list/args)
	if(!length(args))
		return template
	var/result = template
	for(var/i in 1 to length(args))
		result = replacetext(result, "{[i - 1]}", "[args[i]]")
	return result

/// 核心：按给定 locale 查模板（缺则回退英文，再缺则记缺失并返回 key），最后做占位符替换。
/proc/lang_resolve(key, list/args, locale)
	if(isnull(locale))
		locale = GLOB.i18n_server_locale || DEFAULT_UI_LOCALE

	var/template = lang_template(key, locale)
	if(isnull(template) && locale != DEFAULT_UI_LOCALE)
		template = lang_template(key, DEFAULT_UI_LOCALE) // 回退到英文源串

	if(isnull(template))
		GLOB.i18n_missing_keys["[locale]|[key]"] = TRUE
		return key // 兜底：返回 key，避免崩溃；CI 据 GLOB.i18n_missing_keys 发现遗漏

	return lang_interpolate(template, args)

/// 全服 locale 版本（广播类文本用）。见 LANG 宏。
/proc/lang_format(key, list/args)
	return lang_resolve(key, args, null)

/// 单接收者 locale 版本（定向文本用）。见 LANGU 宏。user 为 null 时回退全服 locale。
/proc/lang_format_for(mob/user, key, list/args)
	var/locale
	if(istype(user))
		locale = user.client?.prefs?.read_preference(/datum/preference/choiced/ui_language)
	return lang_resolve(key, args, locale)
