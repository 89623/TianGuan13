/datum/action/cooldown/spell/pointed/mindread/cast(mob/living/cast_on)
	if(HAS_TRAIT(cast_on, TRAIT_PSIONIC_DAMPENER))
		to_chat(owner, span_warning(LANG("datum.d5208656", list(cast_on))))
		return
	return ..()
