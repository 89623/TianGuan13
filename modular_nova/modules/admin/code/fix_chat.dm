ADMIN_VERB(fix_say, R_ADMIN, "修复说话", "Fix say for the players.", ADMIN_CATEGORY_MAIN)
/client/proc/fix_say()
	for(var/player in GLOB.player_list)
		if(!isnull(player))
			continue

		GLOB.player_list -= player
