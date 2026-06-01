/mob/living/carbon/human/can_use_guns(obj/item/G)
	. = ..()
	if(HAS_TRAIT(src, TRAIT_PRONE))
		to_chat(src, span_warning(LANG("mob.cfe3c642", null)))
		return FALSE
