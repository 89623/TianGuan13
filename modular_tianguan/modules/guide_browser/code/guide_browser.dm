// GUIDE_BROWSER - 天关模块：指南浏览器的动作按钮 + tgui 交互
//
// 两种形态（与配置里的两类条目一一对应）：
//   · 分组条目（有 children）：点击展开 / 折叠，不发请求、不动浏览器
//   · 链接条目（有 url）    ：点击直接跳转，走哪条路由条目的 open 字段决定
//                             （默认 "panel" = 游戏内浏览器面板，见 guide_config.dm 顶部说明）
// 目录数据来自 config/tianguan/guide_browser.json，见 guide_config.dm。

/datum/action/guide_browser
	name = "指南浏览器"
	desc = "浏览服务器维基指南。"
	button_icon_state = "round_end"
	show_to_observers = FALSE

	/// 当前选中的链接条目 id（配置重载后失效时会自动回到默认项）
	var/selected_page_id

/datum/action/guide_browser/New(datum/persistent_client/persistent)
	. = ..()
	selected_page_id = GLOB.tianguan_guide_default_id

/datum/action/guide_browser/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(!. || !GLOB.tianguan_guide_ready)
		return
	var/mob/user = clicker || owner
	if(!user?.client)
		return
	ui_interact(user)

/datum/action/guide_browser/ui_status(mob/user, datum/ui_state/state)
	if(!GLOB.tianguan_guide_ready)
		return UI_CLOSE
	return IsAvailable() ? UI_INTERACTIVE : UI_CLOSE

/datum/action/guide_browser/ui_interact(mob/user, datum/tgui/ui)
	if(!GLOB.tianguan_guide_ready || !user?.client)
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(isnull(ui))
		ui = new(user, src, "GuideBrowser")
		ui.open()

/datum/action/guide_browser/ui_static_data(mob/user)
	return list(
		"guide_tree" = GLOB.tianguan_guide_tree,
	)

/datum/action/guide_browser/ui_data(mob/user)
	if(!tianguan_guide_get_page(selected_page_id))
		selected_page_id = GLOB.tianguan_guide_default_id
	var/list/page = tianguan_guide_get_page(selected_page_id)
	return list(
		"selected_id" = selected_page_id,
		"selected_title" = islist(page) ? page["label"] : null,
		"page_url" = islist(page) ? page["url"] : null,
		"guide_available" = GLOB.tianguan_guide_ready,
		"selected_mode" = islist(page) ? page["mode"] : null,
		"supports_iframe" = user?.client?.byond_version >= 516,
	)

/datum/action/guide_browser/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !GLOB.tianguan_guide_ready)
		return
	switch(action)
		if("select_page")
			var/page_id = params["id"]
			if(!istext(page_id) || !tianguan_guide_get_page(page_id))
				return
			selected_page_id = page_id
			// 返回 TRUE = 交给窗口右侧的 iframe 渲染；FALSE = 已在游戏内浏览器 / 系统浏览器打开
			return tianguan_guide_open_page(ui.user, page_id, ui.user?.client?.byond_version >= 516)
		if("open_external")
			return tianguan_guide_open_external(ui.user, selected_page_id)
		if("open_page")
			// 右侧详情栏的「打开」按钮：按条目自己的 open 走同一套分派
			return tianguan_guide_open_page(ui.user, selected_page_id, ui.user?.client?.byond_version >= 516)
