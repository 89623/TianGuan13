/datum/tgs_chat_command/tgscheck
	name = "check"
	help_text = "查看当前回合、在线人数、地图和连接地址" // NOVA EDIT CHANGE - TGS-DISCORD-I18N - ORIGINAL: Gets the playercount, gamemode, and address of the server

/datum/tgs_chat_command/tgscheck/Run(datum/tgs_chat_user/sender, params)
	// NOVA EDIT ADDITION START - TGS-DISCORD-I18N
	var/server = CONFIG_GET(string/public_address) || CONFIG_GET(string/server)
	if(!server)
		server = "byond://m.ctymc.cn:[world.port]"

	var/round_status = "准备中"
	var/embed_colour = "#F1C40F"
	if(SSticker.HasRoundStarted())
		if(SSticker.IsRoundInProgress())
			round_status = "进行中"
			embed_colour = "#2ECC71"
		else
			round_status = "即将结束"
			embed_colour = "#E67E22"

	var/datum/tgs_chat_embed/field/player_field = new("在线玩家", "[GLOB.clients.len] 人")
	player_field.is_inline = TRUE
	var/datum/tgs_chat_embed/field/map_field = new("当前地图", SSmapping.current_map.map_name)
	map_field.is_inline = TRUE
	var/datum/tgs_chat_embed/field/address_field = new("连接地址", server)

	var/datum/tgs_chat_embed/structure/status_embed = new
	status_embed.title = GLOB.round_id ? "第 [GLOB.round_id] 局 · [round_status]" : "服务器状态 · [round_status]"
	status_embed.colour = embed_colour
	status_embed.fields = list(player_field, map_field, address_field)

	var/datum/tgs_message_content/response = new("📡 天官十三号服务器状态")
	response.embed = status_embed
	return response
	// NOVA EDIT ADDITION END
	/* // NOVA EDIT REMOVAL START - TGS-DISCORD-I18N
	var/server = CONFIG_GET(string/public_address) || CONFIG_GET(string/server)
	return new /datum/tgs_message_content("[GLOB.round_id ? "Round #[GLOB.round_id]: " : ""][GLOB.clients.len] players on [SSmapping.current_map.map_name]; Round [SSticker.HasRoundStarted() ? (SSticker.IsRoundInProgress() ? "Active" : "Finishing") : "Starting"] -- [server ? server : "[world.internet_address]:[world.port]"]")
	*/ // NOVA EDIT REMOVAL END

/datum/tgs_chat_command/gameversion
	name = "gameversion"
	help_text = "Gets the version details from the show-server-revision verb, basically"

/datum/tgs_chat_command/gameversion/Run(datum/tgs_chat_user/sender, params)
	var/list/msg = list("")
	msg += "BYOND Server Version: [world.byond_version].[world.byond_build] (Compiled with: [DM_VERSION].[DM_BUILD])\n"

	if (!GLOB.revdata)
		msg += "No revision information found."
	else
		msg += "Revision [copytext_char(GLOB.revdata.commit, 1, 9)]"
		if (GLOB.revdata.date)
			msg += " compiled on '[GLOB.revdata.date]'"

		if(GLOB.revdata.originmastercommit)
			msg += ", from origin commit: <[CONFIG_GET(string/githuburl)]/commit/[GLOB.revdata.originmastercommit]>"

		if(GLOB.revdata.testmerge.len)
			msg += "\n"
			for(var/datum/tgs_revision_information/test_merge/PR as anything in GLOB.revdata.testmerge)
				msg += "PR #[PR.number] at [copytext_char(PR.head_commit, 1, 9)] [PR.title].\n"
				if (PR.url)
					msg += "<[PR.url]>\n"
	return new /datum/tgs_message_content(msg.Join(""))

// Notify
/datum/tgs_chat_command/notify
	name = "notify"
	help_text = "切换下一局开始时的 Discord 提醒" // NOVA EDIT CHANGE - TGS-DISCORD-I18N - ORIGINAL: Pings the invoker when the round ends

/datum/tgs_chat_command/notify/Run(datum/tgs_chat_user/sender, params)
	if(!CONFIG_GET(str_list/channel_announce_new_game))
		return new /datum/tgs_message_content("开局提醒当前未启用。") // NOVA EDIT CHANGE - TGS-DISCORD-I18N - ORIGINAL: Notifcations are currently disabled

	for(var/member in SSdiscord.notify_members) // If they are in the list, take them out
		if(member == sender.mention)
			SSdiscord.notify_members -= sender.mention
			return new /datum/tgs_message_content("已取消提醒；下一局开始时将不再 @ 你。") // NOVA EDIT CHANGE - TGS-DISCORD-I18N - ORIGINAL: You will no longer be notified when the server restarts

	// If we got here, they arent in the list. Chuck 'em in!
	SSdiscord.notify_members += sender.mention
	return new /datum/tgs_message_content("已开启提醒；下一局开始时会 @ 你。") // NOVA EDIT CHANGE - TGS-DISCORD-I18N - ORIGINAL: You will now be notified when the server restarts
