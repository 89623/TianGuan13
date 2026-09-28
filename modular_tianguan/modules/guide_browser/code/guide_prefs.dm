// GUIDE_BROWSER - 天关模块：玩家偏好条目（游戏内 ESC → 设置 = 游戏偏好设置 窗口里那条勾选框）
//
// 语义：勾上「回合开始时自动关闭指南按钮」⇒ **回合开始时**不再自动发放左上角按钮；
// 不勾 ⇒ 每回合照常发放。出厂默认**不勾**（= 每回合都显示）。
//
// 职责分得很清（玩家要求的分工）：
//   **设置只管回合开始时开不开** —— 它在回合开始那一刻被播种成"本回合状态"（见 guide_config.dm 的
//   seed_round_autoclose），之后本回合内再怎么勾/取消**都不影响**按钮。
//   **局内的开关只归 OOC 指令**（「关闭指南按钮」/「打开指南按钮」，本局有效）。
//   所以故意**不**覆写 apply_to_client：改设置不该在局内立刻把按钮收走/放出来（那会很怪）。
//   中途进服/重连不播种（按钮照常给），设置的效力从下一个回合开始。
//
// 为什么放设置窗口而不放指南窗口里：勾了之后按钮就被收走了，玩家也就开不了指南窗口去取消勾选 ——
// 那等于把自己锁死（实测就是这么被问住的）。设置窗口随时能开（ESC → 设置），所以这里是正确的位置。
//
// savefile_identifier = PREFERENCE_PLAYER ⇒ **玩家级**设置（存玩家存档根，跟角色存档槽无关），
// 所以换角色/换职业都保持一致。
//
// 前端条目：tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/game_preferences/
//           tianguan_guide_button.tsx —— 导出的常量名必须与下面的 savefile_key 一致
//           （界面按 savefile_key 取数据；那个常量名是**数据键**，改显示名时别跟着改）。
//           那个目录由 require.context 自动加载，所以本模块**没有改动任何上游文件**。

/datum/preference/toggle/tianguan_guide_button
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "tianguanguidebutton"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = FALSE // 默认不勾 = 每回合都显示
