// This doesn't instantiate right away, since we rely on other GLOBs
GLOBAL_DATUM(escape_menu_title, /atom/movable/screen/escape_menu/title)

/// Provides a singleton for the escape menu details screen.
/proc/give_escape_menu_title()
	if (isnull(GLOB.escape_menu_title))
		GLOB.escape_menu_title = new

	return GLOB.escape_menu_title

/atom/movable/screen/escape_menu/title
	screen_loc = "NORTH:-100,WEST:32"
	maptext_height = 100
	maptext_width = 500

/atom/movable/screen/escape_menu/title/Initialize(mapload, datum/hud/hud_owner)
	. = ..()

	update_text()

	RegisterSignal(SSdcs, COMSIG_GLOB_STATION_NAME_CHANGED, PROC_REF(on_station_name_changed))

/atom/movable/screen/escape_menu/title/Destroy()
	if (GLOB.escape_menu_title == src)
		stack_trace("Something tried to delete the escape menu details screen")
		return QDEL_HINT_LETMELIVE

	return ..()

/atom/movable/screen/escape_menu/title/proc/update_text()
	var/subtitle_text = MAPTEXT("<span style='font-size: 8px'>Another day on...</span>")
	var/title_text = {"
		<span style='font-weight: bolder; font-size: 24px'>
			[station_name()]
		</span>
	"}

	var/full_maptext = "<font align='top'>" + subtitle_text + MAPTEXT_PIXELLARI(title_text) + "</font>"
	// NOVA EDIT ADDITION START - i18n - 逃逸菜单标题 maptext 经 AC 子串兜底（仅全服中文时；"Another day on..." 需进 _fallback.json）
	if(GLOB.i18n_server_locale != DEFAULT_UI_LOCALE)
		full_maptext = lang_fallback_apply(full_maptext)
	// NOVA EDIT ADDITION END
	maptext = full_maptext

/atom/movable/screen/escape_menu/title/proc/on_station_name_changed()
	SIGNAL_HANDLER

	update_text()
