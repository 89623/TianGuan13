/obj/item/book/manual/wiki/sop
	name = "标准作业程序手册"
	desc = "一本供船员快速查阅标准作业程序（SOP）的手册。"
	icon = 'modular_tianguan/modules/sop_book/icons/sop_books.dmi'
	icon_state = "sop_general"
	starting_author = "Tianguan SOP Committee"
	starting_title = "Standard Operating Procedure"
	var/direct_wiki_url = ""

/obj/item/book/manual/wiki/sop/display_content(mob/living/user)
	if(!user?.client)
		return
	if(!direct_wiki_url)
		user.balloon_alert(user, "这本书是空的！")
		return
	credit_book_to_reader(user)
	if(user.client.byond_version < 516)
		if(tgui_alert(user, "这本书的页面将在你的浏览器中打开。你确定吗？", "打开SOP", list("Yes", "No")) != "Yes")
			return
	DIRECT_OUTPUT(user, link(direct_wiki_url))

/obj/item/book/manual/wiki/sop/general
	name = "通用SOP手册"
	icon_state = "sop_general"
	starting_title = "General SOP"
	direct_wiki_url = "https://tianguanstation.miraheze.org/wiki/%E9%80%9A%E7%94%A8%E6%A0%87%E5%87%86%E6%93%8D%E4%BD%9C%E7%A8%8B%E5%BA%8F"

/obj/item/book/manual/wiki/sop/command
	name = "指挥SOP手册"
	icon_state = "sop_command"
	starting_title = "Command SOP"
	direct_wiki_url = "https://tianguanstation.miraheze.org/wiki/%E6%8C%87%E6%8C%A5%E6%A0%87%E5%87%86%E6%93%8D%E4%BD%9C%E7%A8%8B%E5%BA%8F#%E4%BA%BA%E4%BA%8B%E9%83%A8%E9%95%BF"
/obj/item/book/manual/wiki/sop/security
	name = "安全SOP手册"
	icon_state = "sop_security"
	starting_title = "Security SOP"
	direct_wiki_url = "https://tianguanstation.miraheze.org/wiki/%E5%AE%89%E5%85%A8%E6%A0%87%E5%87%86%E6%93%8D%E4%BD%9C%E7%A8%8B%E5%BA%8F"
/obj/item/book/manual/wiki/sop/medical
	name = "医疗SOP手册"
	icon_state = "sop_medical"
	starting_title = "Medical SOP"
	direct_wiki_url = "https://tianguanstation.miraheze.org/wiki/%E5%8C%BB%E7%96%97%E6%A0%87%E5%87%86%E6%93%8D%E4%BD%9C%E7%A8%8B%E5%BA%8F"
/obj/item/book/manual/wiki/sop/cargo
	name = "供应SOP手册"
	icon_state = "sop_cargo"
	starting_title = "Cargo SOP"
	direct_wiki_url = "https://tianguanstation.miraheze.org/wiki/%E4%BE%9B%E5%BA%94%E6%A0%87%E5%87%86%E6%93%8D%E4%BD%9C%E7%A8%8B%E5%BA%8F"
/obj/item/book/manual/wiki/sop/service
	name = "服务SOP手册"
	icon_state = "sop_service"
	starting_title = "Service SOP"
	direct_wiki_url = "https://tianguanstation.miraheze.org/wiki/%E6%9C%8D%E5%8A%A1%E6%A0%87%E5%87%86%E6%93%8D%E4%BD%9C%E7%A8%8B%E5%BA%8F"
/obj/item/book/manual/wiki/sop/science
	name = "科研SOP手册"
	icon_state = "sop_science"
	starting_title = "Science SOP"
	direct_wiki_url = "https://tianguanstation.miraheze.org/wiki/%E7%A7%91%E7%A0%94%E6%A0%87%E5%87%86%E6%93%8D%E4%BD%9C%E7%A8%8B%E5%BA%8F"
/obj/item/book/manual/wiki/sop/engineering
	name = "工程SOP手册"
	icon_state = "sop_engineering"
	starting_title = "Engineering SOP"
	direct_wiki_url = "https://tianguanstation.miraheze.org/wiki/%E5%B7%A5%E7%A8%8B%E6%A0%87%E5%87%86%E6%93%8D%E4%BD%9C%E7%A8%8B%E5%BA%8F"
/obj/item/book/manual/wiki/sop/central_command
	name = "中央指挥部SOP手册"
	icon_state = "sop_centcom"
	starting_title = "Central Command SOP"
	direct_wiki_url = "https://tianguanstation.miraheze.org/wiki/%E4%B8%AD%E5%A4%AE%E6%8C%87%E6%8C%A5%E9%83%A8%E6%A0%87%E5%87%86%E6%93%8D%E4%BD%9C%E7%A8%8B%E5%BA%8F"

// 天关模块化改动：让 PTech cart 售货机出售除中央指挥部外的 SOP 手册。
/obj/machinery/vending/cart
	products = list(
		/obj/item/disk/computer/medical = 10,
		/obj/item/disk/computer/engineering = 10,
		/obj/item/disk/computer/security = 10,
		/obj/item/disk/computer/ordnance = 10,
		/obj/item/disk/computer/quartermaster = 10,
		/obj/item/disk/computer/command/captain = 3,
		/obj/item/modular_computer/pda = 10,
		/obj/item/book/manual/wiki/sop/general = 5,
		/obj/item/book/manual/wiki/sop/command = 5,
		/obj/item/book/manual/wiki/sop/security = 5,
		/obj/item/book/manual/wiki/sop/medical = 5,
		/obj/item/book/manual/wiki/sop/cargo = 5,
		/obj/item/book/manual/wiki/sop/service = 5,
		/obj/item/book/manual/wiki/sop/science = 5,
		/obj/item/book/manual/wiki/sop/engineering = 5,
	)

/datum/outfit/job/proc/tianguan_get_sop_book_type(datum/job/equipped_job)
	if(istype(equipped_job, /datum/job/nanotrasen_consultant) || istype(equipped_job, /datum/job/blueshield))
		return /obj/item/book/manual/wiki/sop/central_command

	var/department_type = equipped_job.department_for_prefs || equipped_job.departments_list?[1]
	switch(department_type)
		if(/datum/job_department/captain, /datum/job_department/command)
			return /obj/item/book/manual/wiki/sop/command
		if(/datum/job_department/security)
			return /obj/item/book/manual/wiki/sop/security
		if(/datum/job_department/engineering)
			return /obj/item/book/manual/wiki/sop/engineering
		if(/datum/job_department/medical)
			return /obj/item/book/manual/wiki/sop/medical
		if(/datum/job_department/science)
			return /obj/item/book/manual/wiki/sop/science
		if(/datum/job_department/cargo)
			return /obj/item/book/manual/wiki/sop/cargo
		if(/datum/job_department/service)
			return /obj/item/book/manual/wiki/sop/service
		if(/datum/job_department/assistant)
			return /obj/item/book/manual/wiki/sop/general
		if(/datum/job_department/silicon)
			return null
		if(/datum/job_department/undefined)
			return /obj/item/book/manual/wiki/sop/general
	return /obj/item/book/manual/wiki/sop/general

/datum/outfit/job/post_equip(mob/living/carbon/human/equipped, visuals_only = FALSE)
	. = ..()
	if(visuals_only)
		return

	var/datum/job/equipped_job = SSjob.get_job_type(jobtype)
	if(!equipped_job)
		equipped_job = SSjob.get_job(equipped.job)
	if(!equipped_job)
		return
	if(!(equipped_job.job_flags & JOB_CREW_MEMBER))
		return

	var/sop_book_type = tianguan_get_sop_book_type(equipped_job)
	if(!sop_book_type)
		return
	if(locate(sop_book_type) in equipped)
		return

	equipped.equip_to_storage(new sop_book_type(equipped), ITEM_SLOT_BACK, indirect_action = TRUE, del_on_fail = TRUE)
