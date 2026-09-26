// GUIDE_BROWSER - 天关模块：管理员「重载指南浏览器配置」指令
//
// 配置是纯数据、只在服务启动与每局开局读一次 ⇒ 改完配置不用重新编译：用这个指令当场重载，
// 或者等下一局自动生效（见 guide_config.dm 的 COMSIG_TICKER_ENTER_PREGAME）。

ADMIN_VERB(reload_guide_browser, R_SERVER, "重载指南浏览器配置", "从 config/tianguan/guide_browser.json 重新加载指南目录。", ADMIN_CATEGORY_SERVER)
	var/guide_file = tianguan_guide_config_path()
	var/count = tianguan_load_guide_config(TRUE)
	if(!count)
		to_chat(user, span_warning("指南目录重载后仍然没有任何可用链接：检查 [guide_file] 是否存在、JSON 语法是否正确、每条是否都写了 label 与 url。逐条跳过原因见服务器日志里的 GUIDE_BROWSER 行。"))
		log_admin("[key_name(user)] 重载指南浏览器配置失败（可用链接 0 条）。")
		return
	to_chat(user, span_notice("指南目录已重载：可用链接 [count] 条。"))
	log_admin("[key_name(user)] 重载了指南浏览器配置（可用链接 [count] 条）。")
	message_admins("[key_name_admin(user)] 重载了指南浏览器配置（可用链接 [count] 条）。")
	SSblackbox.record_feedback("nested tally", "admin_verb", 1, list("Reload Guide Browser"))
