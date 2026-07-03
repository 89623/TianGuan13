// NovaSector 全量汉化 (i18n) —— 运行时英→中兜底层（Aho-Corasick）。
//
// 对「尚未被 LANG/LANGU 改写」或「无法静态抽取」的残留英文，在输出边界做一次多模式
// 子串替换。字典两来源：
//   1. 主字典——内存反查表 lang_build_reverse(locale)（即已翻译的 name/desc/message/title 等
//      无占位符整串），**仅取含空格的多词短语**：单词做子串替换会误伤（"Door"→"Doorknob"），
//      单词类名靠源头 lang_reverse_text 整串反查覆盖（见 runtime.dm / 各 New() 反查）。
//   2. 可选人工补充——strings/i18n/<locale>/_fallback.json，扁平 {"english": "中文"}（不受多词
//      过滤限制，人工显式覆盖）。
// 注意：纯子串替换，不保证语序正确，仅用于过渡期与长尾「不漏英文」。已被 LANG 处理过的
// 文本不应再过此层（中文不匹配英文 pattern，天然 no-op，但仍尽量避免二次过）。

/// locale -> "ready" | "none"，避免重复读盘/重复 setup。
GLOBAL_LIST_EMPTY(i18n_fallback_state)

/// 惰性为某 locale 注册 AC 字典；返回是否可用。
/proc/lang_fallback_setup(locale)
	var/state = GLOB.i18n_fallback_state[locale]
	if(state)
		return state == "ready"

	// 主字典：内存反查表里「含空格的多词短语」（单词排除，避免子串误伤）。
	var/list/dict = list()
	var/list/reverse = lang_build_reverse(locale)
	for(var/english in reverse)
		if(!findtext(english, " "))
			continue
		dict[english] = reverse[english]

	// 可选人工补充/覆盖（不受多词过滤限制）。
	var/path = "[STRING_DIRECTORY]/[I18N_SUBDIRECTORY]/[locale]/_fallback.json"
	if(fexists(path))
		var/list/manual = json_decode(file2text(path))
		if(islist(manual))
			for(var/english in manual)
				dict[english] = manual[english]

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
	// 剥掉 BYOND 文本宏 \improper / \proper（0xFF 起头的控制字节）：rustg_acreplace 按 UTF-8
	// 处理字符串，这些非 UTF-8 字节会被替换成 U+FFFD（显示为 ��，如「那是 ��space」）。中文无
	// 大小写，这两个宏（控制后随单词首字母大小写）本就无意义 → 直接剥除。findtext 门控让无宏的
	// 热路径（绝大多数聊天行）零额外开销。
	if(findtext(text, "\improper") || findtext(text, "\proper"))
		text = replacetext(text, "\improper ", "")
		text = replacetext(text, "\proper ", "")
		text = replacetext(text, "\improper", "")
		text = replacetext(text, "\proper", "")
	// 先过模板逆匹配（插值句：目录里已译的 {0} 模板按字面段在原文上命中、捕获实参反查后按
	// zh 模板重排填充，见 template_match.dm），再过字面 AC 收剩余短语。
	text = lang_template_apply(text, locale)
	text = rustg_acreplace("i18n_[locale]", text)
	// 漏翻采集：所有层过完仍残留的多词英文 run（config I18N_LOG_MISSES 门控，见 miss_log.dm）。
	if(GLOB.i18n_log_misses)
		lang_log_miss_scan(text, "fallback")
	return text
