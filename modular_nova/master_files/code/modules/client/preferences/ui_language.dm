// NovaSector 全量汉化 (i18n) —— 玩家界面语言偏好。
//
// 该偏好驱动：1) TGUI 的 config.locale（见 code/modules/tgui/tgui.dm 的 NOVA EDIT 注入）；
//            2) 定向消息 LANGU(user, …) 的接收者 locale。
// 广播类文本（visible_message 等）用全服 locale（GLOB.i18n_server_locale），与本偏好无关。

/datum/preference/choiced/ui_language
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_identifier = PREFERENCE_PLAYER
	savefile_key = "ui_language"
	can_randomize = FALSE

/datum/preference/choiced/ui_language/init_possible_values()
	return list(
		LANGUAGE_LOCALE_EN,
		LANGUAGE_LOCALE_ZH_HANS,
	)

/datum/preference/choiced/ui_language/create_default_value()
	return DEFAULT_UI_LOCALE
