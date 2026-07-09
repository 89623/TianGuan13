/mob/living/silicon/ai/verb/ai_cryo()
	set name = "AI Cryogenic Stasis"
	set desc = "Puts the current AI personality into cryogenic stasis, freeing the space for another."
	set category = "AI Commands"

	if(incapacitated)
		return
	switch(alert(LANG("mob.8efa8a6a", null),, "Yes.", "No."))
		if("Yes.")
			src.ghostize(FALSE)
			minor_announce("Station AI has disconnected from system networks and moved to remote storage. Preparing for new AI personality upload.", "Station AI")
			new /obj/structure/ai_core/latejoin_inactive(loc)
			if(src.mind)
				//Handle job slot/tater cleanup.
				if(src.mind.assigned_role.title == JOB_AI)
					SSjob.FreeRole(JOB_AI)
			src.mind.special_roles = null
			qdel(src)
		else
			return
