/datum/security_level/zeta
	name = "zeta"
	name_shortform = "ζ"
	announcement_color = "pink"
	number_level = SEC_LEVEL_ZETA
	status_display_icon_state = "epsilonalert"
	fire_alarm_light_color = COLOR_BLACK
	elevating_to_configuration_key = /datum/config_entry/string/alert_zeta
	shuttle_call_time_mod = 1.5
	sound = 'modular_tianguan/sound/security_levels/Zeta.ogg'

/datum/config_entry/string/alert_zeta
	config_entry_value = "全体船员注意。中央指挥部已启用 Zeta 协议。本站已被定义为不可恢复的损失。所有合同都已终止。"

/datum/ert/deathsquad
	code = "Zeta"
