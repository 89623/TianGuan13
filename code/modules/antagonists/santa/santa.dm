// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
/datum/antagonist/santa
	name = "\improper Santa"
	show_in_antagpanel = FALSE
	show_name_in_check_antagonists = TRUE
	show_to_ghosts = TRUE
	suicide_cry = "FOR CHRISTMAS!!"

/datum/antagonist/santa/on_gain()
	. = ..()
	give_equipment()
	give_objective()

	owner.add_traits(list(TRAIT_CANNOT_OPEN_PRESENTS, TRAIT_PRESENT_VISION), TRAIT_SANTA)

/datum/antagonist/santa/greet()
	. = ..()
	to_chat(owner, span_bolddanger(LANG("datum.27b4149c", null)))

/datum/antagonist/santa/proc/give_equipment()
	var/mob/living/carbon/human/H = owner.current
	if(istype(H))
		H.equipOutfit(/datum/outfit/santa)
		H.dna.update_dna_identity()

	var/datum/action/cooldown/spell/teleport/area_teleport/wizard/santa/teleport = new(owner)
	teleport.Grant(H)

/datum/antagonist/santa/proc/give_objective()
	var/datum/objective/santa_objective = new()
	santa_objective.explanation_text = "Bring joy and presents to the station!"
	santa_objective.completed = TRUE //lets cut our santas some slack.
	santa_objective.owner = owner
	objectives |= santa_objective
