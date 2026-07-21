// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
// Server Tab - Server Verbs

ADMIN_VERB(toggle_random_events, R_SERVER, "切换随机事件", "Toggles random events on or off.", ADMIN_CATEGORY_SERVER)
	var/new_are = !CONFIG_GET(flag/allow_random_events)
	CONFIG_SET(flag/allow_random_events, new_are)
	message_admins("[key_name_admin(user)] has [new_are ? "enabled" : "disabled"] random events.")
	SSblackbox.record_feedback("nested tally", "admin_toggle", 1, list("Toggle Random Events", "[new_are ? "Enabled" : "Disabled"]")) // If you are copy-pasting this, ensure the 4th parameter is unique to the new proc!

ADMIN_VERB(toggle_hub, R_SERVER, "切换 Hub", "Toggles the server's visilibility on the BYOND Hub.", ADMIN_CATEGORY_SERVER)
	world.update_hub_visibility(!GLOB.hub_visibility)

	log_admin("[key_name(user)] has toggled the server's hub status for the round, it is now [(GLOB.hub_visibility?"on":"off")] the hub.")
	message_admins("[key_name_admin(user)] has toggled the server's hub status for the round, it is now [(GLOB.hub_visibility?"on":"off")] the hub.")
	if (GLOB.hub_visibility && !world.reachable)
		message_admins("WARNING: The server will not show up on the hub because byond is detecting that a filewall is blocking incoming connections.")

	SSblackbox.record_feedback("nested tally", "admin_toggle", 1, list("Toggled Hub Visibility", "[GLOB.hub_visibility ? "Enabled" : "Disabled"]")) // If you are copy-pasting this, ensure the 4th parameter is unique to the new proc!

#define REGULAR_RESTART "Regular Restart"
#define REGULAR_RESTART_DELAYED "Regular Restart (with delay)"
#define NO_EVENT_RESTART "Restart, Skip TGS Event"
#define HARD_RESTART "Hard Restart (No Delay/Feedback Reason)"
#define HARDEST_RESTART "Hardest Restart (No actions, just reboot)"
#define TGS_RESTART "Server Restart (Kill and restart DD)"
ADMIN_VERB(restart, R_SERVER, "重启世界", "Restarts the world immediately.", ADMIN_CATEGORY_SERVER)
	var/list/options = list(REGULAR_RESTART, REGULAR_RESTART_DELAYED, HARD_RESTART)

	// this option runs a codepath that can leak db connections because it skips subsystem (specifically SSdbcore) shutdown
	if(!SSdbcore.IsConnected())
		options += HARDEST_RESTART

	if(world.TgsAvailable())
		options.Insert(3, NO_EVENT_RESTART)
		options += TGS_RESTART;

	if(SSticker.admin_delay_notice)
		if(alert(user, LANG("datum.94dee4b3", list(SSticker.admin_delay_notice)), LANG("datum.15bc27b6", null), "Yes", "No") != "Yes")
			return FALSE

	var/result = input(user, LANG("datum.d218dc1f", null), LANG("datum.f801363f", null), options[1]) as null|anything in options
	if(isnull(result))
		return

	BLACKBOX_LOG_ADMIN_VERB("Reboot World")
	var/init_by = "Initiated by [user.holder.fakekey ? "Admin" : user.key]."
	switch(result)
		if(REGULAR_RESTART, REGULAR_RESTART_DELAYED, NO_EVENT_RESTART)
			var/delay = 1
			if(result == REGULAR_RESTART_DELAYED)
				delay = input(LANG("datum.14beaff1", null), LANG("datum.d3863989", null), 5) as num|null
			if(!delay)
				return FALSE
			if(!user.is_localhost())
				if(alert(user,LANG("datum.83714097", null),LANG("datum.311a780e", null), "Restart", "Cancel") != "Restart")
					return FALSE

			if (result != NO_EVENT_RESTART)
				SSticker.TriggerRoundEndTgsEvent()

			SSticker.Reboot(init_by, "admin reboot - by [user.key] [user.holder.fakekey ? "(stealth)" : ""]", delay * 10)
		if(HARD_RESTART)
			to_chat(world, LANG("datum.4a152bc2", list(init_by)))
			world.Reboot()
		if(HARDEST_RESTART)
			to_chat(world, LANG("datum.ffaeb44e", list(init_by)))
			world.Reboot(fast_track = TRUE)
		if(TGS_RESTART)
			to_chat(world, LANG("datum.589a8707", list(init_by)))
			world.TgsEndProcess()

#undef REGULAR_RESTART
#undef REGULAR_RESTART_DELAYED
#undef NO_EVENT_RESTART
#undef HARD_RESTART
#undef HARDEST_RESTART
#undef TGS_RESTART

ADMIN_VERB(cancel_reboot, R_SERVER, "取消重启", "Cancels a pending world reboot.", ADMIN_CATEGORY_SERVER)
	if(!SSticker.cancel_reboot(user))
		return
	log_admin("[key_name(user)] cancelled the pending world reboot.")
	message_admins("[key_name_admin(user)] cancelled the pending world reboot.")

ADMIN_VERB(end_round, R_SERVER, "结束回合", "Forcibly ends the round and allows the server to restart normally.", ADMIN_CATEGORY_SERVER)
	var/confirm = tgui_alert(user, LANG("datum.35cf047f", null), LANG("datum.90364329", null), list("Yes", "Cancel"))
	if(confirm != "Yes")
		return
	SSticker.force_ending = FORCE_END_ROUND
	BLACKBOX_LOG_ADMIN_VERB("End Round")

ADMIN_VERB(toggle_ooc, R_ADMIN, "切换 OOC", "Toggle the OOC channel on or off.", ADMIN_CATEGORY_SERVER)
	toggle_ooc()
	log_admin("[key_name(user)] toggled OOC.")
	message_admins("[key_name_admin(user)] toggled OOC.")
	SSblackbox.record_feedback("nested tally", "admin_toggle", 1, list("Toggle OOC", "[GLOB.ooc_allowed ? "Enabled" : "Disabled"]"))

ADMIN_VERB(toggle_ooc_dead, R_ADMIN, "切换死亡 OOC", "Toggle the OOC channel for dead players on or off.", ADMIN_CATEGORY_SERVER)
	toggle_dooc()
	log_admin("[key_name(user)] toggled OOC.")
	message_admins("[key_name_admin(user)] toggled Dead OOC.")
	SSblackbox.record_feedback("nested tally", "admin_toggle", 1, list("Toggle Dead OOC", "[GLOB.dooc_allowed ? "Enabled" : "Disabled"]"))

ADMIN_VERB(toggle_vote_dead, R_ADMIN, "切换死者投票", "Toggle the vote for dead players on or off.", ADMIN_CATEGORY_SERVER)
	SSvote.toggle_dead_voting(user)

ADMIN_VERB(start_now, R_SERVER, "立即开始", "Start the round RIGHT NOW.", ADMIN_CATEGORY_SERVER)
	var/static/list/waiting_states = list(GAME_STATE_PREGAME, GAME_STATE_STARTUP)
	if(!(SSticker.current_state in waiting_states))
		to_chat(user, span_warning(span_red(LANG("datum.5aae0bb8", null))))
		return

	if(SSticker.start_immediately)
		SSticker.start_immediately = FALSE
		SSticker.SetTimeLeft(3 MINUTES)
		to_chat(world, span_big(span_notice(LANG("datum.b6af2aca", null))))
		SEND_SOUND(world, sound('sound/announcer/default/attention.ogg'))
		message_admins(span_adminnotice("[key_name_admin(user)] has cancelled immediate game start. Game will start in 3 minutes."))
		log_admin("[key_name(user)] has cancelled immediate game start.")
		return

	if(!user.is_localhost())
		var/response = tgui_alert(user, LANG("datum.fc7fa821", null), LANG("datum.4aef6455", null), list("Start Now", "Cancel"))
		if(response != "Start Now")
			return
	SSticker.start_immediately = TRUE

	log_admin("[key_name(user)] has started the game.")
	message_admins("[key_name_admin(user)] has started the game.")
	if(SSticker.current_state == GAME_STATE_STARTUP)
		message_admins("The server is still setting up, but the round will be started as soon as possible.")
	BLACKBOX_LOG_ADMIN_VERB("Start Now")

ADMIN_VERB(delay_round_end, R_ADMIN, "延迟回合结束", "Prevent the server from restarting.", ADMIN_CATEGORY_SERVER) // NOVA EDIT CHANGE - Admins can delay the round end - ORIGINAL: ADMIN_VERB(delay_round_end, R_SERVER, "Delay Round End", "Prevent the server from restarting.", ADMIN_CATEGORY_SERVER)
	if(SSticker.delay_end)
		tgui_alert(user, LANG("datum.cc553680", list(SSticker.admin_delay_notice)), LANG("datum.055c248b", null), list("Ok"))
		return

	var/delay_reason = input(user, LANG("datum.dfaedb85", null), LANG("datum.3ec40d76", null)) as null|text

	if(isnull(delay_reason))
		return

	if(SSticker.delay_end)
		tgui_alert(user, LANG("datum.cc553680", list(SSticker.admin_delay_notice)), LANG("datum.055c248b", null), list("Ok"))
		return

	SSticker.delay_end = TRUE
	SSticker.admin_delay_notice = delay_reason
	if(SSticker.reboot_timer)
		SSticker.cancel_reboot(user)

	log_admin("[key_name(user)] delayed the round end for reason: [SSticker.admin_delay_notice]")
	message_admins("[key_name_admin(user)] delayed the round end for reason: [SSticker.admin_delay_notice]")
	SSblackbox.record_feedback("nested tally", "admin_toggle", 1, list("Delay Round End", "Reason: [delay_reason]")) // If you are copy-pasting this, ensure the 4th parameter is unique to the new proc!

ADMIN_VERB(toggle_enter, R_SERVER, "切换进入", "Toggle the ability to enter the game.", ADMIN_CATEGORY_SERVER)
	if(!SSlag_switch.initialized)
		return
	SSlag_switch.set_measure(DISABLE_NON_OBSJOBS, !SSlag_switch.measures[DISABLE_NON_OBSJOBS])
	log_admin("[key_name(user)] toggled new player game entering. Lag Switch at index ([DISABLE_NON_OBSJOBS])")
	message_admins("[key_name_admin(user)] toggled new player game entering [SSlag_switch.measures[DISABLE_NON_OBSJOBS] ? "OFF" : "ON"].")
	SSblackbox.record_feedback("nested tally", "admin_toggle", 1, list("Toggle Entering", "[!SSlag_switch.measures[DISABLE_NON_OBSJOBS] ? "Enabled" : "Disabled"]")) // If you are copy-pasting this, ensure the 4th parameter is unique to the new proc!

ADMIN_VERB(toggle_ai, R_SERVER, "切换 AI", "Toggle the ability to choose AI jobs.", ADMIN_CATEGORY_SERVER)
	var/alai = CONFIG_GET(flag/allow_ai)
	CONFIG_SET(flag/allow_ai, !alai)
	if (alai)
		to_chat(world, span_bold(LANG("datum.07e8e149", null)), confidential = TRUE)
	else
		to_chat(world, LANG("datum.889c06c6", null), confidential = TRUE)
	log_admin("[key_name(user)] toggled AI allowed.")
	world.update_status()
	SSblackbox.record_feedback("nested tally", "admin_toggle", 1, list("Toggle AI", "[!alai ? "Disabled" : "Enabled"]")) // If you are copy-pasting this, ensure the 4th parameter is unique to the new proc!

ADMIN_VERB(toggle_respawn, R_SERVER, "切换重生", "Toggle the ability to respawn.", ADMIN_CATEGORY_SERVER)
	var/respawn_state = CONFIG_GET(flag/allow_respawn)
	var/new_state = -1
	var/new_state_text = ""
	switch(respawn_state)
		if(RESPAWN_FLAG_DISABLED) // respawn currently disabled
			new_state = RESPAWN_FLAG_FREE
			new_state_text = "Enabled"
			to_chat(world, span_bold(LANG("datum.53d44fc6", null)), confidential = TRUE)

		if(RESPAWN_FLAG_FREE) // respawn currently enabled
			new_state = RESPAWN_FLAG_NEW_CHARACTER
			new_state_text = "Enabled, Different Slot"
			to_chat(world, span_bold(LANG("datum.abc943d4", null)), confidential = TRUE)

		if(RESPAWN_FLAG_NEW_CHARACTER) // respawn currently enabled for different slot characters only
			new_state = RESPAWN_FLAG_DISABLED
			new_state_text = "Disabled"
			to_chat(world, span_bold(LANG("datum.3e39f8b5", null)), confidential = TRUE)

		else
			WARNING("Invalid respawn state in config: [respawn_state]")

	if(new_state == -1)
		to_chat(user, span_warning(LANG("datum.9418c297", null)))
		new_state = RESPAWN_FLAG_DISABLED
		new_state_text = "Disabled"

	CONFIG_SET(flag/allow_respawn, new_state)

	message_admins(span_adminnotice("[key_name_admin(user)] toggled respawn to \"[new_state_text]\"."))
	log_admin("[key_name(user)] toggled respawn to \"[new_state_text]\".")

	world.update_status()
	SSblackbox.record_feedback("nested tally", "admin_toggle", 1, list("Toggle Respawn", "[new_state_text]")) // If you are copy-pasting this, ensure the 4th parameter is unique to the new proc!

ADMIN_VERB(delay, R_SERVER, "延迟开局", "Delay the game start.", ADMIN_CATEGORY_SERVER)
	var/newtime = input(user, LANG("datum.623c5ef9", null), LANG("datum.8f2b8869", null), round(SSticker.GetTimeLeft()/10)) as num|null
	if(!newtime)
		return
	if(SSticker.current_state > GAME_STATE_PREGAME)
		return tgui_alert(user, LANG("datum.d5a7f84f", null))
	newtime = newtime*10
	SSticker.SetTimeLeft(newtime)
	SSticker.start_immediately = FALSE
	if(newtime < 0)
		to_chat(world, span_infoplain(LANG("datum.0f805894", null)), confidential = TRUE)
		log_admin("[key_name(user)] delayed the round start.")
	else
		to_chat(world, span_infoplain(span_bold(LANG("datum.c3cc2de3", list(DisplayTimeText(newtime))))), confidential = TRUE)
		SEND_SOUND(world, sound('sound/announcer/default/attention.ogg'))
		log_admin("[key_name(user)] set the pre-game delay to [DisplayTimeText(newtime)].")
	BLACKBOX_LOG_ADMIN_VERB("Delay Game Start")

ADMIN_VERB(set_admin_notice, R_SERVER, "设置管理员通知", "Set an announcement that appears to everyone who joins the server. Only lasts this round.", ADMIN_CATEGORY_SERVER)
	var/new_admin_notice = input(
		user,
		LANG("datum.7baedd28", null),
		LANG("datum.b8478097", null),
		GLOB.admin_notice,
	) as message|null
	if(new_admin_notice == null)
		return
	if(new_admin_notice == GLOB.admin_notice)
		return
	if(new_admin_notice == "")
		message_admins("[key_name(user)] removed the admin notice.")
		log_admin("[key_name(user)] removed the admin notice:\n[GLOB.admin_notice]")
	else
		message_admins("[key_name(user)] set the admin notice.")
		log_admin("[key_name(user)] set the admin notice:\n[new_admin_notice]")
		to_chat(world, span_adminnotice(LANG("datum.1a3c22d3", list(new_admin_notice))), confidential = TRUE)
	BLACKBOX_LOG_ADMIN_VERB("Set Admin Notice")
	GLOB.admin_notice = new_admin_notice

ADMIN_VERB(toggle_guests, R_SERVER, "切换访客", "Toggle the ability for guests to enter the game.", ADMIN_CATEGORY_SERVER)
	var/new_guest_ban = !CONFIG_GET(flag/guest_ban)
	CONFIG_SET(flag/guest_ban, new_guest_ban)
	if (new_guest_ban)
		to_chat(world, span_bold(LANG("datum.caea4e05", null)), confidential = TRUE)
	else
		to_chat(world, LANG("datum.f9b477be", null), confidential = TRUE)
	log_admin("[key_name(user)] toggled guests game entering [!new_guest_ban ? "" : "dis"]allowed.")
	message_admins(span_adminnotice("[key_name_admin(user)] toggled guests game entering [!new_guest_ban ? "" : "dis"]allowed."))
	SSblackbox.record_feedback("nested tally", "admin_toggle", 1, list("Toggle Guests", "[!new_guest_ban ? "Enabled" : "Disabled"]")) // If you are copy-pasting this, ensure the 4th parameter is unique to the new proc!
