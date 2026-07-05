// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
/*Narcolepsy
 * Slight reduction to stealth
 * Reduces resistance
 * Greatly reduces stage speed
 * No change to transmissibility
 * Fatal level
 * Bonus: Causes drowsiness and sleep.
*/
/datum/symptom/narcolepsy
	name = "Narcolepsy"
	desc = "The virus causes a hormone imbalance, making the host sleepy and narcoleptic."
	illness = "Aurora Snorealis"
	stealth = -1
	resistance = -2
	stage_speed = -2
	transmittable = 0
	level = 6
	symptom_delay_min = 30
	symptom_delay_max = 85
	severity = 4
	symptom_cure = /datum/reagent/medicine/ondansetron
	cure_color = "yellow"
	var/yawning = FALSE
	threshold_descs = list(
		"Transmission 4" = "Causes the host to periodically emit a yawn that tries to infect bystanders within 6 meters of the host.",
		"Stage Speed 10" = "Causes narcolepsy more often, increasing the chance of the host falling asleep.",
	)

/datum/symptom/narcolepsy/Start(datum/disease/advance/A)
	. = ..()
	if(!.)
		return
	if(A.totalTransmittable() >= 4) //yawning (mostly just some copy+pasted code from sneezing, with a few tweaks)
		yawning = TRUE
	if(A.totalStageSpeed() >= 10) //act more often
		symptom_delay_min = 20
		symptom_delay_max = 45

/datum/symptom/narcolepsy/Activate(datum/disease/advance/A)
	. = ..()
	if(!.)
		return

	var/mob/living/M = A.affected_mob
	switch(A.stage)
		if(1)
			if(prob(50))
				to_chat(M, span_warning(LANG("datum.3c3a63b3", null)))
		if(2)
			if(prob(50))
				to_chat(M, span_warning(LANG("datum.3fe833b4", null)))
		if(3)
			if(prob(50))
				to_chat(M, span_warning(LANG("datum.b0b16b42", null)))

			M.adjust_drowsiness_up_to(10 SECONDS, 140 SECONDS)

		if(4)
			if(prob(50))
				if(yawning)
					to_chat(M, span_warning(LANG("datum.92009a1c", null)))
				else
					to_chat(M, span_warning(LANG("datum.c4783223", null))) //you can't really yawn while nodding off, can you?

			M.adjust_drowsiness_up_to(20 SECONDS, 140 SECONDS)

			if(yawning)
				M.emote("yawn")
				A.airborne_spread(6)

		if(5)
			if(prob(50))
				to_chat(M, span_warning("[pick("So tired...","You feel very sleepy.","You have a hard time keeping your eyes open.","You try to stay awake.")]"))

			M.adjust_drowsiness_up_to(80 SECONDS, 140 SECONDS)

			if(yawning)
				M.emote("yawn")
				A.airborne_spread(6)
