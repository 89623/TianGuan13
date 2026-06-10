// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
/// Docks the target's pay
/datum/smite/dock_pay
	name = "Dock Pay"

/datum/smite/dock_pay/effect(client/user, mob/living/target)
	. = ..()
	if (!iscarbon(target))
		to_chat(user, span_warning(LANG("datum.0c41c4cf", null)), confidential = TRUE)
		return
	var/mob/living/carbon/dude = target
	var/obj/item/card/id/card = dude.get_idcard(TRUE)
	if (!card)
		to_chat(user, span_warning(LANG("datum.80dcf355", list(dude))), confidential = TRUE)
		return
	if (!card.registered_account)
		to_chat(user, span_warning(LANG("datum.d0705bb3", list(dude))), confidential = TRUE)
		return
	if (card.registered_account.account_balance == 0)
		to_chat(user,  span_warning(LANG("datum.170d76a8", null)))
		return
	var/new_cost = input(LANG("datum.90cc6c0b", list(card.registered_account.account_balance, MONEY_NAME)), LANG("datum.6582c9e9", null)) as num|null
	if (!new_cost)
		return
	if(new_cost < 0)
		card.registered_account.adjust_money(new_cost, "Central Command: Pay Bonus")
		card.registered_account.bank_card_talk(LANG("datum.39c1757a", list(new_cost, MONEY_NAME)), force = TRUE)
	else
		SSeconomy.add_audit_entry(card.registered_account, new_cost, "Central Command")
		card.registered_account.adjust_money(-new_cost, "Central Command: Pay Cut")
		card.registered_account.bank_card_talk(LANG("datum.8777ee25", list(new_cost, MONEY_NAME)), force = TRUE)
	SEND_SOUND(target, 'sound/machines/buzz/buzz-sigh.ogg')
