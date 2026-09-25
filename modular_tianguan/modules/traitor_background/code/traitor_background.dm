// TRAITOR_BACKGROUND - 天关模块：给叛徒信息界面（AntagInfoTraitor）加一张自定义背景图
//
// 这张图要生效需要三处同时到位，缺一处图就不显示：
//   1. 图标文件放本模块 icons/ 下（天关资源不往核心 icons/ 里塞）
//   2. 本文件注册 /datum/asset/simple，并让叛徒 antag datum 通过 ui_assets() 把这份资源随界面一起下发。
//      —— code/modules/tgui/tgui.dm 的 send_assets() 会遍历 src_object.ui_assets(user)，而界面 UI 的
//      src_object 就是这个 antag datum（见 /datum/antagonist/ui_interact 里的 new(user, src, ui_name, name)）。
//   3. 前端在 tgui/packages/tgui/interfaces/AntagInfoTraitor.tsx 里用 resolveAsset() 引用同一个文件名。
//
// 之所以不必改核心文件：/datum/antagonist/traitor 上游没有定义 ui_assets()（只有 /datum 上的空实现
// 返回 list()），所以这里可以直接扩展而不是覆盖它。
// 掠夺者 /datum/antagonist/traitor/marauder 是它的子类型，自动继承同一张背景。

/// 资源在 asset 缓存里的键名 —— 前端 resolveAsset() 用的就是它，两边必须逐字一致
#define TIANGUAN_TRAITOR_BACKGROUND_ASSET "tianguan_traitor_background.png"

/datum/asset/simple/tianguan_traitor_background
	assets = list(
		TIANGUAN_TRAITOR_BACKGROUND_ASSET = 'modular_tianguan/modules/traitor_background/icons/background.png',
	)

/datum/antagonist/traitor/ui_assets(mob/user)
	. = ..()
	. += get_asset_datum(/datum/asset/simple/tianguan_traitor_background)

#undef TIANGUAN_TRAITOR_BACKGROUND_ASSET
