#define PERSONAL_SPACE_DAMAGE 2
#define ASS_SLAP_EXTRA_RANGE -1

// Emotes
/mob/living/carbon/disarm(mob/living/carbon/target)
	if(zone_selected == BODY_ZONE_PRECISE_MOUTH)
		var/target_on_help_and_unarmed = !target.combat_mode && !target.get_active_held_item()
		if(target_on_help_and_unarmed || HAS_TRAIT(target, TRAIT_RESTRAINED))
			do_slap_animation(target)
			playsound(target.loc, 'sound/items/weapons/slap.ogg', 50, TRUE, -1)
			visible_message(LANG("mob.9d2c8ef8", list(src, target)),
				LANG("mob.8a0b09fc", list(target)),\
			LANG("mob.977bc069", null))
			target.unwag_tail()
			return
	if(zone_selected == BODY_ZONE_PRECISE_GROIN && target.dir == src.dir)
		if(HAS_TRAIT(target, TRAIT_PERSONALSPACE) && (target.stat != UNCONSCIOUS) && (!target.handcuffed)) //You need to be conscious and uncuffed to use Personal Space
			if(target.combat_mode && (!HAS_TRAIT(target, TRAIT_PACIFISM))) //Being pacified prevents violent counters
				var/obj/item/bodypart/affecting = src.get_bodypart(BODY_ZONE_HEAD)
				if(affecting?.receive_damage(PERSONAL_SPACE_DAMAGE))
					src.update_damage_overlays()
				visible_message(span_danger(LANG("mob.5c9798e0", list(src, target))),
				span_danger(LANG("mob.0b9b9807", list(target))),
				LANG("mob.977bc069", null), ignored_mobs = list(target))
				playsound(target.loc, 'sound/effects/snap.ogg', 50, TRUE, ASS_SLAP_EXTRA_RANGE)
				to_chat(target, span_danger(LANG("mob.070c4b69", list(src))))
				return
			else
				visible_message(span_danger(LANG("mob.d2f98dd8", list(src, target))),
				span_danger(LANG("mob.87ffdab3", list(target))),
				LANG("mob.977bc069", null), ignored_mobs = list(target))
				playsound(target.loc, 'sound/items/weapons/thudswoosh.ogg', 50, TRUE, ASS_SLAP_EXTRA_RANGE)
				to_chat(target, span_danger(LANG("mob.83a01671", list(src))))
				return
		else
			do_ass_slap_animation(target)
			playsound(target.loc, 'sound/items/weapons/slap.ogg', 50, TRUE, ASS_SLAP_EXTRA_RANGE)
			visible_message(LANG("mob.6f21ff2d", list(src, target)),\
				LANG("mob.88ff6e0b", list(target)),\
				LANG("mob.977bc069", null), ignored_mobs = list(target))
			to_chat(target, LANG("mob.49d20886", list(src)))
			return
	return ..()

#undef PERSONAL_SPACE_DAMAGE
#undef ASS_SLAP_EXTRA_RANGE
