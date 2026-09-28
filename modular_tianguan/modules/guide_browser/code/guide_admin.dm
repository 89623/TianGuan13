// GUIDE_BROWSER - 天关模块：管理员「重载指南浏览器配置」指令
//
// 配置是纯数据、只在服务启动与每局开局读一次 ⇒ 改完配置不用重新编译：用这个指令当场生效，
// 或者等下一局自动生效（见 guide_config.dm 的 COMSIG_TICKER_ENTER_PREGAME）。
//
// 本指令做四件事，并把**实际结果**报给管理员（不糊弄）：
//   ① 重扫 icons/ 图标目录（换了 dmi 当场生效）
//   ② 重读 config/tianguan/guide_browser.json，并对齐所有人的按钮
//   ③ 开着的指南窗口**就地刷新**（不关窗）—— 目录变了能立刻看到
//   ④ 报出**文件指纹**（路径 + md5 前 8 位 + 字节数）与「内容到底变没变」
//      —— 这样"改了却没生效"这类问题一眼可判：是对不上指纹（改的是另一份文件），
//         还是内容确实没变（比如只改了某个条目的文字，条数当然还是 91）。
// 说明：BYOND 运行时读的是**磁盘上的最新内容**（已实测：编译后改文件、运行读到的是改后的），
// 不存在"读编译时那份"的情况。

ADMIN_VERB(reload_guide_browser, R_SERVER, "重载指南浏览器配置", "重读指南目录配置 + 重扫图标目录，并让开着的指南窗口就地刷新。", ADMIN_CATEGORY_SERVER)
	var/guide_file = tianguan_guide_config_path()
	var/snapshot_before = GLOB.tianguan_guide_raw_snapshot

	tianguan_guide_load_button_icon() // ① 图标目录
	var/count = tianguan_load_guide_config(TRUE) // ② 目录
	SStianguan_guide_browser.regrant_actions() // 把新图标应用到所有人的按钮上（不关界面）

	var/icon_text = GLOB.tianguan_guide_button_icon ? "icons/ 里的 [GLOB.tianguan_guide_button_icon_state]" : "内置图标"
	if(count < 0)
		// 读不到 / 解析不了：**如实说失败**（以前这里会拿"上次的条数"谎报成功）
		to_chat(user, span_warning("重载失败：读不到或解析不了 [guide_file]（原因见服务器日志里的 GUIDE_BROWSER 行）。当前仍沿用内存里的旧目录（[length(GLOB.tianguan_guide_pages)] 条），界面不会变化。"))
		log_admin("[key_name(user)] 重载指南浏览器配置失败：读不到 [guide_file]。")
		message_admins("[key_name_admin(user)] 重载指南浏览器配置失败：读不到配置文件。")
		return
	if(!count)
		to_chat(user, span_warning("重读成功，但 [guide_file] 里没有任何可用链接（0 条）⇒ 指南按钮不再发放。逐条跳过原因见服务器日志里的 GUIDE_BROWSER 行。"))
		log_admin("[key_name(user)] 重载指南浏览器配置：可用链接 0 条。")
		message_admins("[key_name_admin(user)] 重载指南浏览器配置：可用链接 0 条。")
		return

	var/file_changed = (GLOB.tianguan_guide_raw_snapshot != snapshot_before)
	var/changed_text = file_changed ? "有变化" : "无变化"
	// 指纹：md5 前 8 位 + 字节数，管理员可拿外部工具对同一文件复核
	var/md5_short = istext(GLOB.tianguan_guide_raw_md5) ? copytext(GLOB.tianguan_guide_raw_md5, 1, 9) : "读不到"
	var/bytes = length(GLOB.tianguan_guide_raw_snapshot)
	var/fingerprint = "[guide_file]　md5 [md5_short]　[bytes] 字节"
	if(file_changed)
		to_chat(user, span_notice("指南目录已重载：可用链接 [count] 条（配置有变化），开着的指南窗口已就地刷新。按钮图标：[icon_text]\n文件：[fingerprint]"))
	else
		to_chat(user, span_notice("指南目录重读完成：文件内容与上次读取**一致**（可用链接 [count] 条，条数不变不代表没读——只改条目文字时条数当然不变）。按钮图标：[icon_text]\n文件：[fingerprint]（若你确实改过，请核对服务器读的是不是这一份：md5 可用外部工具复核）"))
	log_admin("[key_name(user)] 重载了指南浏览器配置（可用链接 [count] 条，配置[changed_text]，md5 [md5_short]）。")
	message_admins("[key_name_admin(user)] 重载了指南浏览器配置（可用链接 [count] 条）。")
	SSblackbox.record_feedback("nested tally", "admin_verb", 1, list("Reload Guide Browser"))
