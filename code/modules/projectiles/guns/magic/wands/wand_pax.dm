// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
/**
 * Pax wand is a minor heal which applies temporary pacifism, gives you time to talk it out?
 */
/obj/item/gun/magic/wand/pax
	name = "rod of compassion"
	desc = "A wand which supernaturally connects victim and target, which renders both unable to fight and makes them feel a little better."
	school = SCHOOL_RESTORATION
	ammo_type = /obj/item/ammo_casing/magic/pax
	icon_state = "peacewand"
	base_icon_state = "peacewand"
	fire_sound = 'sound/effects/emotes/kiss.ogg'
	max_charges = 12

/obj/item/gun/magic/wand/pax/fire_gun(atom/target, mob/living/user, flag, params)
	. = ..()
	if (!.)
		return
	user.apply_status_effect(/datum/status_effect/pacify/visible, 30 SECONDS) // Don't miss!
	user.adjust_brute_loss(-30)

/obj/item/gun/magic/wand/pax/zap_self(mob/living/user, suicide = FALSE)
	if (!suicide)
		user.visible_message(span_notice(LANG("obj.e4689f86", list(user, user.p_their()))))

/obj/item/gun/magic/wand/pax/do_suicide(mob/living/user)
	. = ..()
	user.visible_message(span_suicide(LANG("obj.0d2dcbf7", list(user, user.p_themselves()))))
	return SHAME

/obj/item/ammo_casing/magic/pax
	projectile_type = /obj/projectile/magic/pax
	harmful = FALSE

/obj/projectile/magic/pax
	name = "bolt of compassion"
	icon = 'icons/mob/simple/animal.dmi'
	icon_state = "heart"

/obj/projectile/magic/pax/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	var/mob/living/victim = target
	if (!istype(victim))
		return

	victim.apply_status_effect(/datum/status_effect/pacify/visible, 30 SECONDS)
	victim.adjust_brute_loss(-30)

// Default pacify status effect has no screen alert but I think this should have one
/datum/status_effect/pacify/visible
	alert_type = /atom/movable/screen/alert/status_effect/pacified

/datum/status_effect/pacify/visible/on_apply()
	if (!HAS_TRAIT(owner, TRAIT_PACIFISM))
		owner.visible_message(span_notice(LANG("datum.0309816f", list(owner))), span_notice(LANG("datum.242a2de2", null)))
	return ..()

/datum/status_effect/pacify/visible/on_remove()
	. = ..()
	// Might have it from somewhere else
	if (HAS_TRAIT(owner, TRAIT_PACIFISM))
		return
	owner.visible_message(span_warning(LANG("datum.8a97c00b", list(owner))), span_notice(LANG("datum.20d89dc3", null)))

/atom/movable/screen/alert/status_effect/pacified
	name = "Pacified"
	desc = "You find yourself temporarily incapable of violence."
	icon_state = "in_love"
