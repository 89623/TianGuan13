/mob/living/basic/drone
	examine_thats = "This is"

/obj/item/examine_title(mob/user, thats = FALSE)
	. = ..()
	if(thats || !HAS_TRAIT_FROM(src, TRAIT_WAS_RENAMED, "Loadout"))
		return
	return "<a href='byond://?src=[REF(user)];loadout_examine=[REF(src)]'>[.]</a>"

// Species examine
/mob/living/carbon/human/examine_title(mob/user, thats = FALSE)
	. = ..()
	var/skipface = (wear_mask && (wear_mask.flags_inv & HIDEFACE)) || (head && (head.flags_inv & HIDEFACE))

	var/species_visible
	var/species_name_string
	if(skipface || get_visible_name() == "Unknown")
		species_visible = FALSE
	else
		species_visible = TRUE

	var/species_display
	if(!species_visible)
		species_name_string = ""
	else
		species_display = (!dna.species.lore_protected && dna.features["custom_species"]) ? dna.features["custom_species"] : dna.species.name
		// i18n: 中文无冠词——反查物种名、去掉 a/an 冠词、逗号用中文逗号（"…, a Human" → "…，人类"）。en locale 走原分支不变。
		if(GLOB.i18n_server_locale != DEFAULT_UI_LOCALE)
			species_name_string = "，<EM>[lang_reverse_text(species_display)]</EM>"
		else
			species_name_string = ", [prefix_a_or_an(species_display)] <EM>[species_display]</EM>"

	. += species_name_string
