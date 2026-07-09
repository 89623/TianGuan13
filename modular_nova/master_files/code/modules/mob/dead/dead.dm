/mob/dead/get_status_tab_items()
	. = ..()
	if(SSticker.HasRoundStarted())
		return
	var/time_remaining = SSticker.GetTimeLeft()
	if(time_remaining > 0)
		. += LANG("mob.089189a1", list(round(time_remaining/10)))
	else if(time_remaining == -10)
		. += LANG("mob.fb6871ae", null)
	else
		. += LANG("mob.3a00d811", null)

	. += LANG("mob.8044ca8f", list(LAZYLEN(GLOB.clients)))
	if(client.holder)
		. += LANG("mob.7fba5fa7", list(SSticker.totalPlayersReady))
		. += LANG("mob.846d709a", list(SSticker.total_admins_ready, length(GLOB.admins)))
	if(length(SSstatpanels.player_ready_data) || length(SSstatpanels.assistant_player_ready_data) || length(SSstatpanels.command_player_ready_data))
		. += SSstatpanels.get_job_estimation(src)

