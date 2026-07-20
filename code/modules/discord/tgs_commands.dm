/datum/tgs_chat_command/tgscheck
	name = "check"
	help_text = "查看服务器人数、地图、回合状态与连接地址" // NOVA EDIT CHANGE - I18N - ORIGINAL: "Gets the playercount, gamemode, and address of the server"

/datum/tgs_chat_command/tgscheck/Run(datum/tgs_chat_user/sender, params)
	var/server = CONFIG_GET(string/public_address) || CONFIG_GET(string/server)
	// NOVA EDIT REMOVAL - I18N - ORIGINAL: return new /datum/tgs_message_content("[GLOB.round_id ? "Round #[GLOB.round_id]: " : ""][GLOB.clients.len] players on [SSmapping.current_map.map_name]; Round [SSticker.HasRoundStarted() ? (SSticker.IsRoundInProgress() ? "Active" : "Finishing") : "Starting"] -- [server ? server : "[world.internet_address]:[world.port]"]")
	// NOVA EDIT ADDITION START - I18N - Localized Discord status card
	var/round_status
	if(!SSticker.HasRoundStarted())
		round_status = "🟡 准备中"
	else if(SSticker.IsRoundInProgress())
		round_status = "🟢 进行中"
	else
		round_status = "🟠 正在结束"

	var/map_name = SSmapping.current_map.map_name
	var/localized_map_name = lang_reverse_text(map_name)
	if(localized_map_name != map_name)
		map_name = "[localized_map_name]（[map_name]）"

	var/connect_address
	if(server)
		connect_address = server
	else if(world.internet_address)
		connect_address = "[world.internet_address]:[world.port]"
	else
		connect_address = "端口 [world.port]"

	var/address_display = "`[connect_address]`"
	if(server || world.internet_address)
		if(findtext(connect_address, "byond://") != 1)
			connect_address = "byond://[connect_address]"
		address_display = "`[connect_address]`"

	return new /datum/tgs_message_content("## 🎮 NovaSector 服务器状态\n> 🔢 **回合编号：** [GLOB.round_id ? "#[GLOB.round_id]" : "尚未生成"]\n> 👥 **在线玩家：** [GLOB.clients.len] 人\n> 🗺️ **当前地图：** [map_name]\n> 🔄 **回合状态：** [round_status]\n> 🔗 **连接地址：** [address_display]")
	// NOVA EDIT ADDITION END

/datum/tgs_chat_command/gameversion
	name = "gameversion"
	help_text = "查看 BYOND、编译版本、代码提交与测试合并信息" // NOVA EDIT CHANGE - I18N - ORIGINAL: "Gets the version details from the show-server-revision verb, basically"

/datum/tgs_chat_command/gameversion/Run(datum/tgs_chat_user/sender, params)
	var/list/msg = list("## 🧩 NovaSector 版本信息\n") // NOVA EDIT CHANGE - I18N - ORIGINAL: list("")
	msg += "> ⚙️ **BYOND 运行版本：** [world.byond_version].[world.byond_build]\n> 🛠️ **DreamMaker 编译版本：** [DM_VERSION].[DM_BUILD]\n" // NOVA EDIT CHANGE - I18N - ORIGINAL: "BYOND Server Version: ..."

	if (!GLOB.revdata)
		msg += "> ⚠️ **代码版本：** 未找到提交信息。" // NOVA EDIT CHANGE - I18N - ORIGINAL: "No revision information found."
	else
		msg += "> 📦 **当前提交：** `[copytext_char(GLOB.revdata.commit, 1, 9)]`" // NOVA EDIT CHANGE - I18N - ORIGINAL: "Revision ..."
		if (GLOB.revdata.date)
			msg += "（编译于 [GLOB.revdata.date]）" // NOVA EDIT CHANGE - I18N - ORIGINAL: " compiled on ..."

		if(GLOB.revdata.originmastercommit)
			msg += "\n> 🌐 **上游提交：** <[CONFIG_GET(string/githuburl)]/commit/[GLOB.revdata.originmastercommit]>" // NOVA EDIT CHANGE - I18N - ORIGINAL: ", from origin commit: ..."

		if(GLOB.revdata.testmerge.len)
			msg += "\n> 🧪 **测试合并：**\n" // NOVA EDIT CHANGE - I18N - ORIGINAL: "\n"
			for(var/datum/tgs_revision_information/test_merge/PR as anything in GLOB.revdata.testmerge)
				msg += "> • PR #[PR.number] · `[copytext_char(PR.head_commit, 1, 9)]` · [PR.title]\n" // NOVA EDIT CHANGE - I18N - ORIGINAL: "PR #..."
				if (PR.url)
					msg += ">   <[PR.url]>\n" // NOVA EDIT CHANGE - I18N - ORIGINAL: "<[PR.url]>\n"
	return new /datum/tgs_message_content(msg.Join(""))

// Notify
/datum/tgs_chat_command/notify
	name = "notify"
	help_text = "订阅或取消订阅下一回合开始提醒" // NOVA EDIT CHANGE - I18N - ORIGINAL: "Pings the invoker when the round ends"

/datum/tgs_chat_command/notify/Run(datum/tgs_chat_user/sender, params)
	if(!CONFIG_GET(str_list/channel_announce_new_game))
		return new /datum/tgs_message_content("⚠️ **回合通知当前未启用。**") // NOVA EDIT CHANGE - I18N - ORIGINAL: "Notifcations are currently disabled"

	for(var/member in SSdiscord.notify_members) // If they are in the list, take them out
		if(member == sender.mention)
			SSdiscord.notify_members -= sender.mention
			return new /datum/tgs_message_content("🔕 **已取消订阅**\n> 服务器进入下一回合时将不再提醒你。") // NOVA EDIT CHANGE - I18N - ORIGINAL: "You will no longer be notified when the server restarts"

	// If we got here, they arent in the list. Chuck 'em in!
	SSdiscord.notify_members += sender.mention
	return new /datum/tgs_message_content("🔔 **订阅成功**\n> 服务器进入下一回合时会提醒你。") // NOVA EDIT CHANGE - I18N - ORIGINAL: "You will now be notified when the server restarts"
