// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
ADMIN_VERB(cinematic, R_FUN, "电影感", "Show a cinematic to all players.", ADMIN_CATEGORY_FUN)
	var/datum/cinematic/choice = tgui_input_list(
		user,
		LANG("datum.c0d105b5", null),
		LANG("datum.fed0a958", null),
		sort_list(subtypesof(/datum/cinematic), GLOBAL_PROC_REF(cmp_typepaths_asc)),
	)
	if(!choice || !ispath(choice, /datum/cinematic))
		return
	play_cinematic(choice, world)
