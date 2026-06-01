// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
/obj/item/book/granter/action/spell/mindswap
	granted_action = /datum/action/cooldown/spell/pointed/mind_transfer
	action_name = "mindswap"
	icon_state ="bookmindswap"
	desc = "This book's cover is pristine, though its pages look ragged and torn."
	remarks = list(
		"If you mindswap from a mouse, they will be helpless when you recover...",
		"Wait, where am I...?",
		"This book is giving me a horrible headache...",
		"This page is blank, but I feel words popping into my head...",
		"GYNU... GYRO... Ugh...",
		"The voices in my head need to stop, I'm trying to read here...",
		"I don't think anyone will be happy when I cast this spell...",
	)
	/// Mob used in book recoils to store an identity for mindswaps
	var/datum/weakref/stored_swap_ref

/obj/item/book/granter/action/spell/mindswap/on_reading_finished()
	. = ..()
	visible_message(span_notice(LANG("obj.96b6ac3f", list(src))))
	action_name = pick(
		"fireball",
		"smoke",
		"blind",
		"forcewall",
		"knock",
		"barnyard",
		"charge",
	)
	icon_state = "book[action_name]"
	name = "spellbook of [action_name]"

/obj/item/book/granter/action/spell/mindswap/recoil(mob/living/user)
	. = ..()
	var/mob/living/real_stored_swap = stored_swap_ref?.resolve()
	if(QDELETED(real_stored_swap))
		stored_swap_ref = WEAKREF(user)
		to_chat(user, span_warning(LANG("obj.caba989d", null)))
		return
	if(real_stored_swap.stat == DEAD)
		stored_swap_ref = null
		return
	if(real_stored_swap == user)
		to_chat(user, span_notice(LANG("obj.18ac145b", null)))
		return

	var/datum/action/cooldown/spell/pointed/mind_transfer/swapper = new(src)

	if(swapper.swap_minds(user, real_stored_swap))
		to_chat(user, span_warning(LANG("obj.0f4b7eea", null)))
		to_chat(real_stored_swap, span_warning(LANG("obj.ab14d389", list(src))))

	else
		// if the mind_transfer failed to transfer mobs (likely due to the target being catatonic).
		user.visible_message(span_warning("[src] fizzles slightly as it stops glowing!"))

	stored_swap_ref = null
