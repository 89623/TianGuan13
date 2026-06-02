#define pick_list(FILE, KEY) (pick(strings(FILE, KEY)))
#define pick_list_weighted(FILE, KEY) (pick_weight(strings(FILE, KEY)))
#define pick_list_replacements(FILE, KEY) (strings_replacement(FILE, KEY))
#define json_load(FILE) (json_decode(file2text(FILE)))

GLOBAL_LIST(string_cache)
GLOBAL_VAR(string_filename_current_key)


/proc/strings_replacement(filepath, key)
	filepath = sanitize_filepath(filepath)
	load_strings_file(filepath)

	if((filepath in GLOB.string_cache) && (key in GLOB.string_cache[filepath]))
		var/response = pick(GLOB.string_cache[filepath][key])
		var/regex/needs_replacing = regex("@pick\\((\\D+?)\\)", "g")
		response = needs_replacing.Replace(response, GLOBAL_PROC_REF(strings_subkey_lookup))
		return response
	else
		CRASH("strings list not found: [STRING_DIRECTORY]/[filepath], index=[key]")

/proc/strings(filepath as text, key as text, directory = STRING_DIRECTORY)
	if(IsAdminAdvancedProcCall())
		return

	filepath = sanitize_filepath(filepath)
	load_strings_file(filepath, directory)
	if((filepath in GLOB.string_cache) && (key in GLOB.string_cache[filepath]))
		return GLOB.string_cache[filepath][key]
	else
		CRASH("strings list not found: [directory]/[filepath], index=[key]")

/proc/strings_subkey_lookup(match, group1)
	return pick_list(GLOB.string_filename_current_key, group1)

/proc/load_strings_file(filepath, directory = STRING_DIRECTORY)
	if(IsAdminAdvancedProcCall())
		return

	GLOB.string_filename_current_key = filepath
	if(filepath in GLOB.string_cache)
		return //no work to do

	if(!GLOB.string_cache)
		GLOB.string_cache = new

	// NOVA EDIT ADDITION START - i18n - 全服非英文时优先读本地化副本 [directory]/[locale]/[filepath]
	// （如 strings/zh-Hans/fishing_tips.txt）；缺则回退英文原文件。接入 strings/ 里的玩家可见 flavor。
	var/effective_path = "[directory]/[filepath]"
	if(GLOB.i18n_server_locale != DEFAULT_UI_LOCALE)
		var/localized_path = "[directory]/[GLOB.i18n_server_locale]/[filepath]"
		if(fexists(localized_path))
			effective_path = localized_path
	if(fexists(effective_path))
		GLOB.string_cache[filepath] = json_load(effective_path)
	else
		CRASH("file not found: [directory]/[filepath]")
	// NOVA EDIT ADDITION END
