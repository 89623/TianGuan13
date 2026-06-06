// i18n：全服中文(locale≠en)时，把"烤了英文字的"大厅按钮精灵换成中文重绘版。
// 核心 .dmi 完全不动(上游合并友好)；中文版在 modular_nova/modules/i18n/icons/lobby/，
// 由 tools/i18n/lobby-buttons/gen_dmi.py 用 Fusion Pixel 像素字体逐帧 blit 生成(状态名/帧数与原图一致)。
// 文字按钮覆盖：join(加入游戏)/observe(旁观)/ready(未准备·准备就绪)/character_setup(角色·设置)。
// start_now 是木牌喷漆手绘体(且仅 localhost)，无法字体生成，保留英文，不在表内。
//
// 钩在 SlowInit：所有大厅按钮创建后都会被 new_player.dm 的循环逐个调用 SlowInit()，且仅基类定义此 proc，
// 故这里扩展(. = ..())即对每个按钮生效。换 icon 后 update_appearance 用同名 state 重渲(中文 .dmi 状态名一致)。
/atom/movable/screen/lobby/SlowInit()
	. = ..()
	if(GLOB.i18n_server_locale == DEFAULT_UI_LOCALE)
		return
	var/static/list/zh_lobby_icons = list(
		'icons/hud/lobby/join.dmi' = 'modular_nova/modules/i18n/icons/lobby/join.dmi',
		'icons/hud/lobby/observe.dmi' = 'modular_nova/modules/i18n/icons/lobby/observe.dmi',
		'icons/hud/lobby/ready.dmi' = 'modular_nova/modules/i18n/icons/lobby/ready.dmi',
		'icons/hud/lobby/character_setup.dmi' = 'modular_nova/modules/i18n/icons/lobby/character_setup.dmi',
	)
	var/replacement = zh_lobby_icons[icon]
	if(replacement)
		icon = replacement
		update_appearance(UPDATE_ICON)
