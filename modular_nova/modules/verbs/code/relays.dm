/datum/config_entry/flag/enable_relays

/datum/config_entry/keyed_list/relay_option
	key_mode = KEY_MODE_TEXT
	value_mode = VALUE_MODE_TEXT
	lowercase_key = FALSE
	splitter = ","

/client/verb/connect_to_relay()
	set name = "Connect to Relay"
	set hidden = TRUE

	if(!CONFIG_GET(flag/enable_relays))
		to_chat(src, span_danger(LANG("client.e735287b", null)))
		return

	var/static/list/available_relays
	if(isnull(available_relays))
		available_relays = CONFIG_GET(keyed_list/relay_option)

	if(!length(available_relays))
		to_chat(src, span_danger(LANG("client.dd83f55e", null)))
		return

	var/choice = tgui_input_list(usr, LANG("client.ad08a62a", null), LANG("client.a135c8d5", null), available_relays)
	if(isnull(choice))
		return
	var/address = available_relays[choice]
	if(isnull(address))
		return

	usr << link(address)
	sleep(1 SECONDS)
	winset(usr, null, "command=.quit")
