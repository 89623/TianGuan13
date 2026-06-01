// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
/* CONTAINS:
 * /obj/item/ai_module/core/freeformcore
 * /obj/item/ai_module/supplied/freeform
**/

/obj/item/ai_module/core/freeformcore
	name = "'Freeform' Core AI Module"
	laws = list("")

/obj/item/ai_module/core/freeformcore/attack_self(mob/user)
	var/targName = tgui_input_text(user, LANG("obj.c38e88d5", null), LANG("obj.f2d27273", null), laws[1], max_length = CONFIG_GET(number/max_law_len), multiline = TRUE)
	if(!targName || !user.is_holding(src))
		return
	if(is_ic_filtered(targName))
		to_chat(user, span_warning(LANG("obj.b74e9614", null)))
		return
	var/list/soft_filter_result = is_soft_ooc_filtered(targName)
	if(soft_filter_result)
		if(tgui_alert(user,LANG("obj.785540fc", list(soft_filter_result[CHAT_FILTER_INDEX_WORD], soft_filter_result[CHAT_FILTER_INDEX_REASON])), LANG("obj.b0fe106c", null), list("Yes", "No")) != "Yes")
			return
		message_admins("[ADMIN_LOOKUPFLW(user)] has passed the soft filter for \"[soft_filter_result[CHAT_FILTER_INDEX_WORD]]\" they may be using a disallowed term for an AI law. Law: \"[html_encode(targName)]\"")
		log_admin_private("[key_name(user)] has passed the soft filter for \"[soft_filter_result[CHAT_FILTER_INDEX_WORD]]\" they may be using a disallowed term for an AI law. Law: \"[targName]\"")
	laws[1] = targName
	..()

/obj/item/ai_module/core/freeformcore/transmitInstructions(datum/ai_laws/law_datum, mob/sender, overflow)
	..()
	return laws[1]

/obj/item/ai_module/supplied/freeform
	name = "'Freeform' AI Module"
	lawpos = 15
	laws = list("")

/obj/item/ai_module/supplied/freeform/attack_self(mob/user)
	var/newpos = tgui_input_number(user, LANG("obj.440d46d1", null), LANG("obj.2b743674", null), lawpos, 50, 15)
	if(!newpos || !user.is_holding(src) || !usr.can_perform_action(src, FORBID_TELEKINESIS_REACH))
		return
	lawpos = newpos
	var/targName = tgui_input_text(user, LANG("obj.dded9ced", null), LANG("obj.f2d27273", null), laws[1], max_length = CONFIG_GET(number/max_law_len), multiline = TRUE)
	if(!targName || !user.is_holding(src))
		return
	if(is_ic_filtered(targName))
		to_chat(user, span_warning(LANG("obj.b74e9614", null))) // AI LAW 2 SAY U W U WITHOUT THE SPACES
		return
	var/list/soft_filter_result = is_soft_ooc_filtered(targName)
	if(soft_filter_result)
		if(tgui_alert(user,LANG("obj.785540fc", list(soft_filter_result[CHAT_FILTER_INDEX_WORD], soft_filter_result[CHAT_FILTER_INDEX_REASON])), LANG("obj.b0fe106c", null), list("Yes", "No")) != "Yes")
			return
		message_admins("[ADMIN_LOOKUPFLW(user)] has passed the soft filter for \"[soft_filter_result[CHAT_FILTER_INDEX_WORD]]\" they may be using a disallowed term for an AI law. Law: \"[html_encode(targName)]\"")
		log_admin_private("[key_name(user)] has passed the soft filter for \"[soft_filter_result[CHAT_FILTER_INDEX_WORD]]\" they may be using a disallowed term for an AI law. Law: \"[targName]\"")
	laws[1] = targName
	..()

/obj/item/ai_module/supplied/freeform/transmitInstructions(datum/ai_laws/law_datum, mob/sender, overflow)
	if(!overflow)
		..()
	else if(law_datum.owner)
		law_datum.owner.replace_random_law(laws[1], list(LAW_SUPPLIED), LAW_SUPPLIED)
	else
		law_datum.replace_random_law(laws[1], list(LAW_SUPPLIED), LAW_SUPPLIED)
	return laws[1]

/obj/item/ai_module/supplied/freeform/install(datum/ai_laws/law_datum, mob/user)
	if(laws[1] == "")
		to_chat(user, span_alert(LANG("obj.7bb84693", null)))
		return 0
	..()
