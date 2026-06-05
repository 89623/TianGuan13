// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
/datum/species/abductor
	name = "Abductor"
	id = SPECIES_ABDUCTOR
	sexes = FALSE
	inherent_traits = list(
		TRAIT_ABDUCTOR_HUD,
		TRAIT_CHUNKYFINGERS_IGNORE_BATON,
		TRAIT_NEVER_WOUNDED,
		TRAIT_NOBLOOD,
		TRAIT_NOBREATH,
		TRAIT_NODISMEMBER,
		TRAIT_NOHUNGER,
		TRAIT_NO_UNDERWEAR,
		TRAIT_VIRUSIMMUNE,
	)
	mutanttongue = /obj/item/organ/tongue/abductor
	mutantstomach = null
	mutantheart = null
	mutantlungs = null
	mutantbrain = /obj/item/organ/brain/abductor
	changesource_flags = MIRROR_BADMIN | WABBAJACK | MIRROR_PRIDE | MIRROR_MAGIC | RACE_SWAP | ERT_SPAWN | SLIME_EXTRACT

	bodypart_overrides = list(
		BODY_ZONE_HEAD = /obj/item/bodypart/head/abductor,
		BODY_ZONE_CHEST = /obj/item/bodypart/chest/abductor,
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left/abductor,
		BODY_ZONE_R_ARM = /obj/item/bodypart/arm/right/abductor,
		BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/abductor,
		BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right/abductor,
	)

/datum/species/abductor/get_physical_attributes()
	return "Abductors do not need to breathe, eat, do not have blood, a heart, stomach, or lungs and cannot be infected by human viruses. \
		Their hardy physique prevents their skin from being wounded or dismembered, but their chunky tridactyl hands make it hard to operate human equipment."

/datum/species/abductor/get_species_description()
	return "Abductors, colloquially known as \"Greys\" (or \"Grays\"), \
		are, three fingered, pale skinned inquisitive aliens who can't communicate well to the average crew-member."

/datum/species/abductor/get_species_lore()
	return list(
		"Little are known about Abductors. \
		While they (as a species) have been known to abduct other species of 'lesser intellect' for experimentation, \
		some have been known to - on rare occasions - work with the very species they abduct, for reasons unknown.",
	)

/datum/species/abductor/create_pref_traits_perks()
	var/list/perks = list()
	perks += list(list(
		SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
		SPECIES_PERK_ICON = FA_ICON_WIND,
		SPECIES_PERK_NAME = LANG("datum.24c42856", null),
		SPECIES_PERK_DESC = LANG("datum.aa1a9072", null),
	))
	perks += list(list(
		SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
		SPECIES_PERK_ICON = FA_ICON_SHIELD,
		SPECIES_PERK_NAME = LANG("datum.1953a9bf", null),
		SPECIES_PERK_DESC = LANG("datum.81731725", null),
	))
	return perks

/datum/species/abductor/create_pref_unique_perks()
	var/list/perks = list()
	perks += list(list(
		SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
		SPECIES_PERK_ICON = FA_ICON_SYRINGE,
		SPECIES_PERK_NAME = LANG("datum.7ecf78de", null),
		SPECIES_PERK_DESC = LANG("datum.89c7d694", null),
	))
	perks += list(list(
		SPECIES_PERK_TYPE = SPECIES_NEUTRAL_PERK, // It may be a stretch to call nohunger a neutral perk but the Abductor's tongue describes it as much, so.
		SPECIES_PERK_ICON = FA_ICON_UTENSILS,
		SPECIES_PERK_NAME = LANG("datum.d3fc8b6e", null),
		SPECIES_PERK_DESC = LANG("datum.05c4d82c", null),
	))
	perks += list(list(
		SPECIES_PERK_TYPE = SPECIES_NEUTRAL_PERK,
		SPECIES_PERK_ICON = FA_ICON_VOLUME_XMARK,
		SPECIES_PERK_NAME = LANG("datum.f5c46b2b", null),
		SPECIES_PERK_DESC = LANG("datum.27c90331", null),
	))
	perks += list(list(
		SPECIES_PERK_TYPE = SPECIES_NEGATIVE_PERK,
		SPECIES_PERK_ICON = FA_ICON_HANDSHAKE_SLASH,
		SPECIES_PERK_NAME = LANG("datum.ff4e849e", null),
		SPECIES_PERK_DESC = LANG("datum.b83b8b34", null),
	))
	return perks
