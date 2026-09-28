// GUIDE_BROWSER - 天关模块：OOC 栏里的「关闭 / 打开指南按钮」指令
//
// 语义：
//   「关闭指南按钮」= **本局**隐藏按钮；不动设置里的偏好。
//   「打开指南按钮」= **本局**把按钮要回来：会记一个「本局强制显示」标记，盖过设置里的
//     「回合开始时自动关闭指南按钮」（**不修改**玩家的勾选）。
// 优先级（见 guide_config.dm 的 tianguan_guide_button_suppressed）：
//   本局强制 > 本局隐藏 > 设置里的回合开始自动关闭。
//   本局强制必须压过那条偏好 —— 否则会出现"提示说打开了、按钮却没出来"（实测踩过这个坑）。
// 发放失败时**如实告诉玩家**并写服务器日志，不谎报成功。
// 设置里那条偏好的开关在 ESC → 设置（游戏偏好设置）→「指南浏览器」分区，那里随时能开。

GAME_VERB_DESC(/client, hide_guide_button, "关闭指南按钮", "Hide the guide button from the top-left HUD", "OOC")
	if(!GLOB.tianguan_guide_ready)
		to_chat(usr, span_warning("指南目录没加载，按钮本来就没发放。"))
		return
	tianguan_guide_set_hidden(usr, TRUE)
	to_chat(usr, span_notice("指南按钮已关闭（本局不再显示）。想每回合开始都自动关掉它：ESC → 设置 →「指南浏览器」里勾「回合开始时自动关闭指南按钮」。"))

GAME_VERB_DESC(/client, show_guide_button, "打开指南按钮", "Show the guide button in the top-left HUD", "OOC")
	if(!GLOB.tianguan_guide_ready)
		to_chat(usr, span_warning("指南目录没加载，无法发放按钮。"))
		return
	if(!usr?.client)
		return
	var/autoclose_on = tianguan_guide_autoclose_on(usr.client)
	var/shown = tianguan_guide_set_hidden(usr, FALSE, TRUE) // 本局强行要回来（不改玩家设置）
	if(!shown)
		to_chat(usr, span_warning("按钮没能挂到你的界面上（可能当前没有可用的身体/HUD）。失败原因已写进服务器日志的 GUIDE_BROWSER 行，请把这条报给管理员。"))
		return
	if(autoclose_on)
		to_chat(usr, span_notice("指南按钮已打开（本局有效）。你在设置里勾了「回合开始时自动关闭指南按钮」，下一回合开始又会不显示 —— 要改就去 ESC → 设置 →「指南浏览器」。"))
	else
		to_chat(usr, span_notice("指南按钮已打开。"))
