// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
/client/verb/open_character_preferences()
	set category = "OOC"
	set name = "打开角色偏好设置"
	set desc = "Open Character Preferences"

	if(!prefs)
		return
	prefs.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	prefs.update_static_data(usr)
	prefs.ui_interact(usr)

/client/verb/open_game_preferences()
	set category = "OOC"
	set name = "打开游戏偏好设置"
	set desc = "Open Game Preferences"

	if(!prefs)
		return
	prefs.current_window = PREFERENCE_TAB_GAME_PREFERENCES
	prefs.update_static_data(usr)
	prefs.ui_interact(usr)

