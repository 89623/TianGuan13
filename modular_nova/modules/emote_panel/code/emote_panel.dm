/mob/proc/manipulate_emotes()
	if(!mind)
		return
	var/list/available_emotes = list()
	var/list/all_emotes = list()

	// code\modules\mob\emote.dm
	var/static/list/mob_emotes = list(
		/mob/proc/emote_flip,
		/mob/proc/emote_spin,
		/mob/proc/emote_rolld20,
	)
	all_emotes += mob_emotes

	// code\modules\mob\living\emote.dm
	var/static/list/living_emotes = list(
		/mob/living/proc/emote_blush,
		/mob/living/proc/emote_bow,
		/mob/living/proc/emote_burp,
		/mob/living/proc/emote_choke,
		/mob/living/proc/emote_cross,
		/mob/living/proc/emote_chuckle,
		/mob/living/proc/emote_collapse,
		/mob/living/proc/emote_cough,
		/mob/living/proc/emote_dance,
		/mob/living/proc/emote_drool,
		/mob/living/proc/emote_faint,
		/mob/living/proc/emote_flap,
		/mob/living/proc/emote_aflap,
		/mob/living/proc/emote_frown,
		/mob/living/proc/emote_gag,
		/mob/living/proc/emote_giggle,
		/mob/living/proc/emote_glare,
		/mob/living/proc/emote_grin,
		/mob/living/proc/emote_groan,
		/mob/living/proc/emote_grimace,
		/mob/living/proc/emote_jump,
		/mob/living/proc/emote_kiss,
		/mob/living/proc/emote_laugh,
		/mob/living/proc/emote_look,
		/mob/living/proc/emote_nod,
		/mob/living/proc/emote_nodnod,
		/mob/living/proc/emote_point,
		/mob/living/proc/emote_pout,
		/mob/living/proc/emote_scream,
		/mob/living/proc/emote_scowl,
		/mob/living/proc/emote_shake,
		/mob/living/proc/emote_shiver,
		/mob/living/proc/emote_sigh,
		/mob/living/proc/emote_sit,
		/mob/living/proc/emote_smile,
		/mob/living/proc/emote_sneeze,
		/mob/living/proc/emote_smug,
		/mob/living/proc/emote_sniff,
		/mob/living/proc/emote_stare,
		/mob/living/proc/emote_strech,
		/mob/living/proc/emote_sulk,
		/mob/living/proc/emote_sway,
		/mob/living/proc/emote_tilt,
		/mob/living/proc/emote_tremble,
		/mob/living/proc/emote_twitch,
		/mob/living/proc/emote_twitch_s,
		/mob/living/proc/emote_wave,
		/mob/living/proc/emote_whimper,
		/mob/living/proc/emote_wsmile,
		/mob/living/proc/emote_yawn,
		/mob/living/proc/emote_gurgle,
		/mob/living/proc/emote_inhale,
		/mob/living/proc/emote_exhale,
		/mob/living/proc/emote_swear
	)
	all_emotes += living_emotes

	// code\modules\mob\living\carbon\emote.dm
	var/static/list/carbon_emotes = list(
		/mob/living/carbon/proc/emote_airguitar,
		/mob/living/carbon/proc/emote_blink,
		/mob/living/carbon/proc/emote_blink_r,
		/mob/living/carbon/proc/emote_crack,
		/mob/living/carbon/proc/emote_circle,
		/mob/living/carbon/proc/emote_moan,
		/mob/living/carbon/proc/emote_slap,
		/mob/living/carbon/proc/emote_wink
	)
	all_emotes += carbon_emotes

	// code\modules\mob\living\carbon\human\emote.dm
	var/static/list/human_emotes = list(
		/mob/living/carbon/human/proc/emote_cry,
		/mob/living/carbon/human/proc/emote_eyebrow,
		/mob/living/carbon/human/proc/emote_grumble,
		/mob/living/carbon/human/proc/emote_mumble,
		/mob/living/carbon/human/proc/emote_pale,
		/mob/living/carbon/human/proc/emote_raise,
		/mob/living/carbon/human/proc/emote_salute,
		/mob/living/carbon/human/proc/emote_shrug,
		/mob/living/carbon/human/proc/emote_wag,
		/mob/living/carbon/human/proc/emote_wing
	)
	all_emotes += human_emotes

	// modular_nova\modules\emotes\code\emote.dm
	var/static/list/nova_living_emotes = list(
		/mob/living/proc/emote_peep,
		/mob/living/proc/emote_peep2,
		/mob/living/proc/emote_snap,
		/mob/living/proc/emote_snap2,
		/mob/living/proc/emote_snap3,
		/mob/living/proc/emote_awoo,
		/mob/living/proc/emote_nya,
		/mob/living/proc/emote_weh,
		/mob/living/proc/emote_mothsqueak,
		/mob/living/proc/emote_mousesqueak,
		/mob/living/proc/emote_merp,
		/mob/living/proc/emote_bark,
		/mob/living/proc/emote_squish,
		/mob/living/proc/emote_bubble,
		/mob/living/proc/emote_pop,
		/mob/living/proc/emote_meow,
		/mob/living/proc/emote_hiss1,
		/mob/living/proc/emote_chitter,
		/mob/living/proc/emote_snore,
		/mob/living/proc/emote_clap,
		/mob/living/proc/emote_clap1,
		/mob/living/proc/emote_headtilt,
		/mob/living/proc/emote_blink2,
		/mob/living/proc/emote_rblink,
		/mob/living/proc/emote_squint,
		/mob/living/proc/emote_smirk,
		/mob/living/proc/emote_eyeroll,
		/mob/living/proc/emote_huff,
		/mob/living/proc/emote_etwitch,
		/mob/living/proc/emote_clear,
		/mob/living/proc/emote_bawk,
		/mob/living/proc/emote_caw,
		/mob/living/proc/emote_caw2,
		/mob/living/proc/emote_whistle,
		/mob/living/proc/emote_blep,
		/mob/living/proc/emote_bork,
		/mob/living/proc/emote_hoot,
		/mob/living/proc/emote_growl,
		/mob/living/proc/emote_woof,
		/mob/living/proc/emote_baa,
		/mob/living/proc/emote_baa2,
		/mob/living/proc/emote_wurble,
		/mob/living/proc/emote_rattle,
		/mob/living/proc/emote_cackle,
		/mob/living/proc/emote_warble,
		/mob/living/proc/emote_trills,
		/mob/living/proc/emote_rpurr,
		/mob/living/proc/emote_purr,
		/mob/living/proc/emote_moo,
		/mob/living/proc/emote_honk1,
		/mob/living/proc/emote_mggaow,
		/mob/living/proc/emote_mrrp,
		/mob/living/proc/emote_prbt,
		/mob/living/proc/emote_yip,
		/mob/living/proc/emote_fwhine,
		/mob/living/proc/emote_awuff,
		/mob/living/proc/emote_arf,
		/mob/living/proc/emote_coyhowl,
		/mob/living/proc/emote_wolfhowl,
		/mob/living/proc/emote_dwhine,
		/mob/living/proc/emote_dgrowl,
		/mob/living/proc/emote_aggrobark,
		/mob/living/proc/emote_dcomplain,
		/mob/living/proc/emote_meowdeep,
		/mob/living/proc/emote_teshchirp,
		/mob/living/proc/emote_teshsqueak,
		/mob/living/proc/emote_teshtrill,
		/mob/living/proc/emote_gecker,
	)
	all_emotes += nova_living_emotes

	// code\modules\mob\living\brain\emote.dm
	var/static/list/brain_emotes = list(
		/mob/living/brain/proc/emote_alarm,
		/mob/living/brain/proc/emote_alert,
		/mob/living/brain/proc/emote_flash,
		/mob/living/brain/proc/emote_notice,
		/mob/living/brain/proc/emote_whistle_brain
	)
	all_emotes += brain_emotes

	// code\modules\mob\living\carbon\alien\emote.dm
	var/static/list/alien_emotes = list(
		/mob/living/carbon/alien/proc/emote_gnarl,
		/mob/living/carbon/alien/proc/emote_hiss,
		/mob/living/carbon/alien/proc/emote_roar
	)
	all_emotes += alien_emotes

	// modular_nova\modules\emotes\code\synth_emotes.dm
	var/static/list/synth_emotes = list(
		/mob/living/proc/emote_dwoop,
		/mob/living/proc/emote_yes,
		/mob/living/proc/emote_no,
		/mob/living/proc/emote_boop,
		/mob/living/proc/emote_buzz,
		/mob/living/proc/emote_beep,
		/mob/living/proc/emote_beep2,
		/mob/living/proc/emote_buzz2,
		/mob/living/proc/emote_chime,
		/mob/living/proc/emote_honk,
		/mob/living/proc/emote_ping,
		/mob/living/proc/emote_sad,
		/mob/living/proc/emote_warn,
		/mob/living/proc/emote_slowclap
	)
	all_emotes += synth_emotes
	var/static/list/allowed_species_synth = list(
		/datum/species/synthetic
	)

	// modular_nova\modules\emotes\code\additionalemotes\overlay_emote.dm
	var/static/list/nova_living_emotes_overlay = list(
		/mob/living/proc/emote_sweatdrop,
		/mob/living/proc/emote_exclaim,
		/mob/living/proc/emote_question,
		/mob/living/proc/emote_realize,
		/mob/living/proc/emote_annoyed,
		/mob/living/proc/emote_glasses
	)
	all_emotes += nova_living_emotes_overlay

	// modular_nova\modules\emotes\code\additionalemotes\turf_emote.dm
	all_emotes += /mob/living/proc/emote_mark_turf

	// Clearing all emotes before applying new ones
	verbs -= all_emotes

	// Checking if preferences allow emote panel
	if(!src.client?.prefs?.read_preference(/datum/preference/toggle/emote_panel))
		return

	// Checking emote availability
	if(isbrain(src))
		// Only brains in MMI have emotes
		var/mob/living/brain/current_brain = src
		if(current_brain.container && istype(current_brain.container, /obj/item/mmi))
			available_emotes += brain_emotes
	else
		if(ismob(src))
			available_emotes += mob_emotes
		if(isliving(src))
			available_emotes += living_emotes
			available_emotes += nova_living_emotes
			available_emotes += nova_living_emotes_overlay
			available_emotes += /mob/living/proc/emote_mark_turf
			// Checking if should apply Synth emotes
			if(HAS_TRAIT(src, TRAIT_SILICON_EMOTES_ALLOWED))
				available_emotes += synth_emotes
		if(iscarbon(src))
			available_emotes += carbon_emotes
		if(ishuman(src))
			available_emotes += human_emotes
			var/mob/living/carbon/human/current_mob = src
			// Checking if can wag tail
			var/obj/item/organ/tail/tail = current_mob.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
			if(!(tail?.wag_flags & WAG_ABLE))
				available_emotes -= /mob/living/carbon/human/proc/emote_wag
			// Checking if has wings
			if(!current_mob.get_organ_slot(ORGAN_SLOT_EXTERNAL_WINGS))
				available_emotes -= /mob/living/carbon/human/proc/emote_wing
		if(isalien(src))
			available_emotes += alien_emotes

	// Applying emote panel if preferences allow
	for(var/emote in available_emotes)
		verbs |= emote

/mob/mind_initialize()
	. = ..()
	manipulate_emotes()

// code\modules\mob\emote.dm
/mob/proc/emote_flip()
	set name = "| 翻转 |"
	set category = "Emotes"
	usr.emote("flip", intentional = TRUE)

/mob/proc/emote_spin()
	set name = "| 旋转 |"
	set category = "Emotes"
	usr.emote("spin", intentional = TRUE)

/mob/proc/emote_rolld20()
	set name = "| 掷 D20 |"
	set category = "Emotes"
	usr.emote("rolld20", intentional = TRUE)
// code\modules\mob\living\emote.dm

/mob/living/proc/emote_blush()
	set name = "~ 脸红"
	set category = "Emotes"
	usr.emote("blush", intentional = TRUE)

/mob/living/proc/emote_bow()
	set name = "~ 鞠躬"
	set category = "Emotes"
	usr.emote("bow", intentional = TRUE)

/mob/living/proc/emote_burp()
	set name = "> 打嗝"
	set category = "Emotes"
	usr.emote("burp", intentional = TRUE)

/mob/living/proc/emote_choke()
	set name = "~ 噎住"
	set category = "Emotes"
	usr.emote("choke", intentional = TRUE)

/mob/living/proc/emote_cross()
	set name = "~ 抱臂"
	set category = "Emotes"
	usr.emote("cross", intentional = TRUE)

/mob/living/proc/emote_chuckle()
	set name = "~ 轻笑"
	set category = "Emotes"
	usr.emote("chuckle", intentional = TRUE)

/mob/living/proc/emote_collapse()
	set name = "~ 瘫倒"
	set category = "Emotes"
	usr.emote("collapse", intentional = TRUE)

/mob/living/proc/emote_cough()
	set name = "> 咳嗽"
	set category = "Emotes"
	usr.emote("cough", intentional = TRUE)

/mob/living/proc/emote_dance()
	set name = "~ 跳舞"
	set category = "Emotes"
	usr.emote("dance", intentional = TRUE)

/mob/living/proc/emote_drool()
	set name = "~ 流口水"
	set category = "Emotes"
	usr.emote("drool", intentional = TRUE)

/mob/living/proc/emote_faint()
	set name = "~ 昏厥"
	set category = "Emotes"
	usr.emote("faint", intentional = TRUE)

/mob/living/proc/emote_flap()
	set name = "~ 振翅"
	set category = "Emotes"
	usr.emote("flap", intentional = TRUE)

/mob/living/proc/emote_aflap()
	set name = "~ 愤怒振翅"
	set category = "Emotes"
	usr.emote("aflap", intentional = TRUE)

/mob/living/proc/emote_frown()
	set name = "~ 皱眉"
	set category = "Emotes"
	usr.emote("frown", intentional = TRUE)

/mob/living/proc/emote_gag()
	set name = "~ 干呕"
	set category = "Emotes"
	usr.emote("gag", intentional = TRUE)

/mob/living/proc/emote_giggle()
	set name = "~ 咯咯笑"
	set category = "Emotes"
	usr.emote("giggle", intentional = TRUE)


/mob/living/proc/emote_glare()
	set name = "~ 瞪视"
	set category = "Emotes"
	usr.emote("glare", intentional = TRUE)

/mob/living/proc/emote_grin()
	set name = "~ 咧嘴笑"
	set category = "Emotes"
	usr.emote("grin", intentional = TRUE)

/mob/living/proc/emote_groan()
	set name = "~ 闷哼"
	set category = "Emotes"
	usr.emote("groan", intentional = TRUE)

/mob/living/proc/emote_grimace()
	set name = "~ 扮鬼脸"
	set category = "Emotes"
	usr.emote("grimace", intentional = TRUE)

/mob/living/proc/emote_jump()
	set name = "~ 跳跃"
	set category = "Emotes"
	usr.emote("jump", intentional = TRUE)

/mob/living/proc/emote_kiss()
	set name = "| 亲吻 |"
	set category = "Emotes"
	usr.emote("kiss", intentional = TRUE)

/mob/living/proc/emote_laugh()
	set name = "> 大笑"
	set category = "Emotes"
	usr.emote("laugh", intentional = TRUE)

/mob/living/proc/emote_look()
	set name = "~ 张望"
	set category = "Emotes"
	usr.emote("look", intentional = TRUE)

/mob/living/proc/emote_nod()
	set name = "~ 点头"
	set category = "Emotes"
	usr.emote("nod", intentional = TRUE)

/mob/living/proc/emote_nodnod()
	set name = "~ 连连点头"
	set category = "Emotes"
	usr.emote("nod2", intentional = TRUE)

/mob/living/proc/emote_point()
	set name = "~ 指向"
	set category = "Emotes"
	usr.emote("point", intentional = TRUE)

/mob/living/proc/emote_pout()
	set name = "~ 撅嘴"
	set category = "Emotes"
	usr.emote("pout", intentional = TRUE)

/mob/living/proc/emote_scream()
	set name = "> 尖叫"
	set category = "Emotes"
	usr.emote("scream", intentional = TRUE)

/mob/living/proc/emote_scowl()
	set name = "~ 怒视"
	set category = "Emotes"
	usr.emote("scowl", intentional = TRUE)

/mob/living/proc/emote_shake()
	set name = "~ 摇头"
	set category = "Emotes"
	usr.emote("shake", intentional = TRUE)

/mob/living/proc/emote_shiver()
	set name = "~ 发抖"
	set category = "Emotes"
	usr.emote("shiver", intentional = TRUE)

/mob/living/proc/emote_sigh()
	set name = "> 叹气"
	set category = "Emotes"
	usr.emote("sigh", intentional = TRUE)

/mob/living/proc/emote_sit()
	set name = "~ 坐下"
	set category = "Emotes"
	usr.emote("sit", intentional = TRUE)

/mob/living/proc/emote_smile()
	set name = "~ 微笑"
	set category = "Emotes"
	usr.emote("smile", intentional = TRUE)

/mob/living/proc/emote_sneeze()
	set name = "> 打喷嚏"
	set category = "Emotes"
	usr.emote("sneeze", intentional = TRUE)

/mob/living/proc/emote_smug()
	set name = "~ 得意笑"
	set category = "Emotes"
	usr.emote("smug", intentional = TRUE)

/mob/living/proc/emote_sniff()
	set name = "> 吸鼻子"
	set category = "Emotes"
	usr.emote("sniff", intentional = TRUE)

/mob/living/proc/emote_stare()
	set name = "~ 凝视"
	set category = "Emotes"
	usr.emote("stare", intentional = TRUE)

/mob/living/proc/emote_strech()
	set name = "~ 伸懒腰"
	set category = "Emotes"
	usr.emote("stretch", intentional = TRUE)

/mob/living/proc/emote_sulk()
	set name = "~ 闷闷不乐"
	set category = "Emotes"
	usr.emote("sulk", intentional = TRUE)

/mob/living/proc/emote_sway()
	set name = "~ 晕乎摇晃"
	set category = "Emotes"
	usr.emote("sway", intentional = TRUE)

/mob/living/proc/emote_tilt()
	set name = "~ 歪头"
	set category = "Emotes"
	usr.emote("tilt", intentional = TRUE)

/mob/living/proc/emote_tremble()
	set name = "~ 颤抖"
	set category = "Emotes"
	usr.emote("tremble", intentional = TRUE)

/mob/living/proc/emote_twitch()
	set name = "~ 剧烈抽搐"
	set category = "Emotes"
	usr.emote("twitch", intentional = TRUE)

/mob/living/proc/emote_twitch_s()
	set name = "~ 轻微抽搐"
	set category = "Emotes"
	usr.emote("twitch_s", intentional = TRUE)

/mob/living/proc/emote_wave()
	set name = "~ 挥手"
	set category = "Emotes"
	usr.emote("wave", intentional = TRUE)

/mob/living/proc/emote_whimper()
	set name = "~ 呜咽"
	set category = "Emotes"
	usr.emote("whimper", intentional = TRUE)

/mob/living/proc/emote_wsmile()
	set name = "~ 勉强微笑"
	set category = "Emotes"
	usr.emote("wsmile", intentional = TRUE)

/mob/living/proc/emote_yawn()
	set name = "~ 打哈欠"
	set category = "Emotes"
	usr.emote("yawn", intentional = TRUE)

/mob/living/proc/emote_gurgle()
	set name = "~ 难受地咕噜"
	set category = "Emotes"
	usr.emote("gurgle", intentional = TRUE)

/mob/living/proc/emote_inhale()
	set name = "~ 吸气"
	set category = "Emotes"
	usr.emote("inhale", intentional = TRUE)

/mob/living/proc/emote_exhale()
	set name = "~ 呼气"
	set category = "Emotes"
	usr.emote("exhale", intentional = TRUE)

/mob/living/proc/emote_swear()
	set name = "~ 骂脏话"
	set category = "Emotes"
	usr.emote("swear", intentional = TRUE)

// code\modules\mob\living\carbon\emote.dm

/mob/living/carbon/proc/emote_airguitar()
	set name = "~ 空气吉他"
	set category = "Emotes"
	usr.emote("airguitar", intentional = TRUE)

/mob/living/carbon/proc/emote_blink()
	set name = "~ 眨眼"
	set category = "Emotes"
	usr.emote("blink", intentional = TRUE)

/mob/living/carbon/proc/emote_blink_r()
	set name = "~ 快速眨眼"
	set category = "Emotes"
	usr.emote("blink_r", intentional = TRUE)

/mob/living/carbon/proc/emote_crack()
	set name = "> 掰响指节"
	set category = "Emotes"
	usr.emote("crack", intentional = TRUE)

/mob/living/carbon/proc/emote_circle()
	set name = "| 画圈 |"
	set category = "Emotes"
	usr.emote("circle", intentional = TRUE)

/mob/living/carbon/proc/emote_moan()
	set name = "~ 呻吟"
	set category = "Emotes"
	usr.emote("moan", intentional = TRUE)

/mob/living/carbon/proc/emote_slap()
	set name = "| 掌掴 |"
	set category = "Emotes"
	usr.emote("slap", intentional = TRUE)

/mob/living/carbon/proc/emote_wink()
	set name = "~ 眨眼示意"
	set category = "Emotes"
	usr.emote("wink", intentional = TRUE)

// code\modules\mob\living\carbon\human\emote.dm

/mob/living/carbon/human/proc/emote_cry()
	set name = "~ 哭泣"
	set category = "Emotes"
	usr.emote("cry", intentional = TRUE)

/mob/living/carbon/human/proc/emote_eyebrow()
	set name = "~ 挑眉"
	set category = "Emotes"
	usr.emote("eyebrow", intentional = TRUE)

/mob/living/carbon/human/proc/emote_grumble()
	set name = "~ 嘟囔"
	set category = "Emotes"
	usr.emote("grumble", intentional = TRUE)

/mob/living/carbon/human/proc/emote_mumble()
	set name = "~ 咕哝"
	set category = "Emotes"
	usr.emote("mumble", intentional = TRUE)

/mob/living/carbon/human/proc/emote_pale()
	set name = "~ 脸色发白"
	set category = "Emotes"
	usr.emote("pale", intentional = TRUE)

/mob/living/carbon/human/proc/emote_raise()
	set name = "~ 举手"
	set category = "Emotes"
	usr.emote("raise", intentional = TRUE)

/mob/living/carbon/human/proc/emote_salute()
	set name = "~ 敬礼"
	set category = "Emotes"
	usr.emote("salute", intentional = TRUE)

/mob/living/carbon/human/proc/emote_shrug()
	set name = "~ 耸肩"
	set category = "Emotes"
	usr.emote("shrug", intentional = TRUE)

/mob/living/carbon/human/proc/emote_wag()
	set name = "| 摇尾 |"
	set category = "Emotes"
	usr.emote("wag", intentional = TRUE)

/mob/living/carbon/human/proc/emote_wing()
	set name = "| 摆翅 |"
	set category = "Emotes"
	usr.emote("wing", intentional = TRUE)

// modular_nova\modules\emotes\code\emote.dm

/mob/living/proc/emote_peep()
	set name = "> 啾"
	set category = "Emotes+"
	usr.emote("peep", intentional = TRUE)

/mob/living/proc/emote_peep2()
	set name = "> 啾啾两声"
	set category = "Emotes+"
	usr.emote("peep2", intentional = TRUE)

/mob/living/proc/emote_snap()
	set name = "> 打响指"
	set category = "Emotes+"
	usr.emote("snap", intentional = TRUE)

/mob/living/proc/emote_snap2()
	set name = "> 两声响指"
	set category = "Emotes+"
	usr.emote("snap2", intentional = TRUE)

/mob/living/proc/emote_snap3()
	set name = "> 三声响指"
	set category = "Emotes+"
	usr.emote("snap3", intentional = TRUE)

/mob/living/proc/emote_awoo()
	set name = "> 嗷呜"
	set category = "Emotes+"
	usr.emote("awoo", intentional = TRUE)

/mob/living/proc/emote_yip()
	set name = "> 尖吠"
	set category = "Emotes+"
	usr.emote("yip", intentional = TRUE)

/mob/living/proc/emote_gecker()
	set name = "> 咯咯叫"
	set category = "Emotes+"
	usr.emote("gecker", intentional = TRUE)

/mob/living/proc/emote_fwhine()
	set name = "> 狐狸哀鸣"
	set category = "Emotes+"
	usr.emote("fwhine", intentional = TRUE)

/mob/living/proc/emote_nya()
	set name = "> 喵呜"
	set category = "Emotes+"
	usr.emote("nya", intentional = TRUE)

/mob/living/proc/emote_weh()
	set name = "> 唔诶"
	set category = "Emotes+"
	usr.emote("weh", intentional = TRUE)

/mob/living/proc/emote_mothsqueak()
	set name = "> 蛾类吱鸣"
	set category = "Emotes+"
	usr.emote("msqueak", intentional = TRUE)

/mob/living/proc/emote_mousesqueak()
	set name = "> 鼠吱"
	set category = "Emotes+"
	usr.emote("squeak", intentional = TRUE)

/mob/living/proc/emote_merp()
	set name = "> 咩噗"
	set category = "Emotes+"
	usr.emote("merp", intentional = TRUE)

/mob/living/proc/emote_bark()
	set name = "> 吠叫"
	set category = "Emotes+"
	usr.emote("bark", intentional = TRUE)

/mob/living/proc/emote_squish()
	set name = "> 挤压声"
	set category = "Emotes+"
	usr.emote("squish", intentional = TRUE)

/mob/living/proc/emote_bubble()
	set name = "> 冒泡"
	set category = "Emotes+"
	usr.emote("bubble", intentional = TRUE)

/mob/living/proc/emote_pop()
	set name = "> 啵"
	set category = "Emotes+"
	usr.emote("pop", intentional = TRUE)

/mob/living/proc/emote_meow()
	set name = "> 喵"
	set category = "Emotes+"
	usr.emote("meow", intentional = TRUE)

/mob/living/proc/emote_hiss1()
	set name = "> 嘶嘶"
	set category = "Emotes+"
	usr.emote("hiss", intentional = TRUE)

/mob/living/proc/emote_chitter()
	set name = "> 愉快啾鸣"
	set category = "Emotes+"
	usr.emote("chitter", intentional = TRUE)

/mob/living/proc/emote_snore()
	set name = "> 打鼾"
	set category = "Emotes+"
	usr.emote("snore", intentional = TRUE)

/mob/living/proc/emote_clap()
	set name = "> 鼓掌"
	set category = "Emotes+"
	usr.emote("clap", intentional = TRUE)

/mob/living/proc/emote_clap1()
	set name = "> 拍一下手"
	set category = "Emotes+"
	usr.emote("clap1", intentional = TRUE)

/mob/living/proc/emote_headtilt()
	set name = "~ 侧头"
	set category = "Emotes+"
	usr.emote("tilt", intentional = TRUE)

/mob/living/proc/emote_blink2()
	set name = "~ 眨眼两次"
	set category = "Emotes+"
	usr.emote("blink2", intentional = TRUE)

/mob/living/proc/emote_rblink()
	set name = "~ 快速眨眼"
	set category = "Emotes+"
	usr.emote("rblink", intentional = TRUE)

/mob/living/proc/emote_squint()
	set name = "~ 眯眼"
	set category = "Emotes+"
	usr.emote("squint", intentional = TRUE)

/mob/living/proc/emote_smirk()
	set name = "~ 假笑"
	set category = "Emotes+"
	usr.emote("smirk", intentional = TRUE)

/mob/living/proc/emote_eyeroll()
	set name = "~ 翻白眼"
	set category = "Emotes+"
	usr.emote("eyeroll", intentional = TRUE)

/mob/living/proc/emote_huff()
	set name = "~ 哼气"
	set category = "Emotes+"
	usr.emote("huffs", intentional = TRUE)

/mob/living/proc/emote_etwitch()
	set name = "~ 抖耳"
	set category = "Emotes+"
	usr.emote("etwitch", intentional = TRUE)

/mob/living/proc/emote_clear()
	set name = "~ 清嗓"
	set category = "Emotes+"
	usr.emote("clear", intentional = TRUE)

/mob/living/proc/emote_bawk()
	set name = "> 咯咯鸡叫"
	set category = "Emotes+"
	usr.emote("bawk", intentional = TRUE)

/mob/living/proc/emote_caw()
	set name = "> 呱叫"
	set category = "Emotes+"
	usr.emote("caw", intentional = TRUE)

/mob/living/proc/emote_caw2()
	set name = "> 呱呱两声"
	set category = "Emotes+"
	usr.emote("caw2", intentional = TRUE)

/mob/living/proc/emote_whistle()
	set name = "~ 吹口哨"
	set category = "Emotes+"
	usr.emote("whistle", intentional = TRUE)

/mob/living/proc/emote_blep()
	set name = "~ 吐舌"
	set category = "Emotes+"
	usr.emote("blep", intentional = TRUE)

/mob/living/proc/emote_bork()
	set name = "> 一声汪"
	set category = "Emotes+"
	usr.emote("bork", intentional = TRUE)

/mob/living/proc/emote_hoot()
	set name = "> 枭鸣"
	set category = "Emotes+"
	usr.emote("hoot", intentional = TRUE)

/mob/living/proc/emote_growl()
	set name = "> 低吼"
	set category = "Emotes+"
	usr.emote("growl", intentional = TRUE)

/mob/living/proc/emote_woof()
	set name = "> 欢快汪叫"
	set category = "Emotes+"
	usr.emote("woof", intentional = TRUE)

/mob/living/proc/emote_baa()
	set name = "> 咩"
	set category = "Emotes+"
	usr.emote("baa", intentional = TRUE)

/mob/living/proc/emote_baa2()
	set name = "> 咩咩"
	set category = "Emotes+"
	usr.emote("baa2", intentional = TRUE)

/mob/living/proc/emote_wurble()
	set name = "> 咕噜"
	set category = "Emotes+"
	usr.emote("wurble", intentional = TRUE)
/mob/living/proc/emote_rattle()
	set name = "> 咔哒响"
	set category = "Emotes+"
	usr.emote("rattle", intentional = TRUE)

/mob/living/proc/emote_cackle()
	set name = "> 癫狂大笑"
	set category = "Emotes+"
	usr.emote("cackle", intentional = TRUE)

/mob/living/proc/emote_warble()
	set name = "> 婉转鸣叫"
	set category = "Emotes+"
	usr.emote("warble", intentional = TRUE)

/mob/living/proc/emote_trills()
	set name = "> 颤鸣"
	set category = "Emotes+"
	usr.emote("trills", intentional = TRUE)

/mob/living/proc/emote_rpurr()
	set name = "> 猛禽呼噜"
	set category = "Emotes+"
	usr.emote("rpurr", intentional = TRUE)

/mob/living/proc/emote_purr()
	set name = "> 呼噜"
	set category = "Emotes+"
	usr.emote("purr", intentional = TRUE)

/mob/living/proc/emote_moo()
	set name = "> 欢快哞叫"
	set category = "Emotes+"
	usr.emote("moo", intentional = TRUE)

/mob/living/proc/emote_honk1()
	set name = "> 大声鹅叫"
	set category = "Emotes+"
	usr.emote("honk1", intentional = TRUE)

/mob/living/proc/emote_mggaow()
	set name = "> 大声喵"
	set category = "Emotes+"
	usr.emote("mggaow", intentional = TRUE)

/mob/living/proc/emote_mrrp()
	set name = "> 咪噜"
	set category = "Emotes+"
	usr.emote("mrrp", intentional = TRUE)

/mob/living/proc/emote_prbt()
	set name = "> 噗噜"
	set category = "Emotes+"
	usr.emote("prbt", intentional = TRUE)

/mob/living/proc/emote_awuff()
	set name = "> 轻声汪"
	set category = "Emotes+"
	usr.emote("awuff", intentional = TRUE)

/mob/living/proc/emote_arf()
	set name = "> 汪汪"
	set category = "Emotes+"
	usr.emote("arf", intentional = TRUE)

/mob/living/proc/emote_coyhowl()
	set name = "> 郊狼嚎叫"
	set category = "Emotes+"
	usr.emote("coyhowl", intentional = TRUE)

/mob/living/proc/emote_wolfhowl()
	set name = "> 狼嚎"
	set category = "Emotes+"
	usr.emote("wolfhowl", intentional = TRUE)

/mob/living/proc/emote_dwhine()
	set name = "> 犬类哀鸣"
	set category = "Emotes+"
	usr.emote("dwhine", intentional = TRUE)

/mob/living/proc/emote_dgrowl()
	set name = "> 犬类低吼"
	set category = "Emotes+"
	usr.emote("dgrowl", intentional = TRUE)

/mob/living/proc/emote_aggrobark()
	set name = "> 凶狠吠叫"
	set category = "Emotes+"
	usr.emote("aggrobark", intentional = TRUE)

/mob/living/proc/emote_dcomplain()
	set name = "> 犬类抱怨"
	set category = "Emotes+"
	usr.emote("dcomplain", intentional = TRUE)

/mob/living/proc/emote_meowdeep()
	set name = "> 低沉喵"
	set category = "Emotes+"
	usr.emote("meowdeep", intentional = TRUE)

/mob/living/proc/emote_teshchirp()
	set name = "> Tesh 啾鸣"
	set category = "Emotes+"
	usr.emote("teshchirp", intentional = TRUE)

/mob/living/proc/emote_teshsqueak()
	set name = "> Tesh 吱鸣"
	set category = "Emotes+"
	usr.emote("teshsqueak", intentional = TRUE)

/mob/living/proc/emote_teshtrill()
	set name = "> Tesh 颤鸣"
	set category = "Emotes+"
	usr.emote("teshtrill", intentional = TRUE)

// code\modules\mob\living\brain\emote.dm

/mob/living/brain/proc/emote_alarm()
	set name = "< 警报 >"
	set category = "Emotes"
	usr.emote("alarm", intentional = TRUE)

/mob/living/brain/proc/emote_alert()
	set name = "< 告急 >"
	set category = "Emotes"
	usr.emote("alert", intentional = TRUE)

/mob/living/brain/proc/emote_flash()
	set name = "< 闪灯 >"
	set category = "Emotes"
	usr.emote("flash", intentional = TRUE)

/mob/living/brain/proc/emote_notice()
	set name = "< 提示音 >"
	set category = "Emotes"
	usr.emote("notice", intentional = TRUE)

/mob/living/brain/proc/emote_whistle_brain()
	set name = "< 哨音 >"
	set category = "Emotes"
	usr.emote("whistle", intentional = TRUE)

// code\modules\mob\living\carbon\alien\emote.dm

/mob/living/carbon/alien/proc/emote_gnarl()
	set name = "< 龇牙 >"
	set category = "Emotes"
	usr.emote("gnarl", intentional = TRUE)

/mob/living/carbon/alien/proc/emote_hiss()
	set name = "< 嘶鸣 >"
	set category = "Emotes"
	usr.emote("hiss", intentional = TRUE)

/mob/living/carbon/alien/proc/emote_roar()
	set name = "< 咆哮 >"
	set category = "Emotes"
	usr.emote("roar", intentional = TRUE)

//modular_nova\modules\emotes\code\synth_emotes.dm

/mob/living/proc/emote_dwoop()
	set name = "< 欢快啾鸣 >"
	set category = "Emotes"
	usr.emote("dwoop", intentional = TRUE)

/mob/living/proc/emote_yes()
	set name = "< 肯定音 >"
	set category = "Emotes"
	usr.emote("yes", intentional = TRUE)

/mob/living/proc/emote_no()
	set name = "< 否定音 >"
	set category = "Emotes"
	usr.emote("no", intentional = TRUE)

/mob/living/proc/emote_boop()
	set name = "< 嘟 >"
	set category = "Emotes"
	usr.emote("boop", intentional = TRUE)

/mob/living/proc/emote_buzz()
	set name = "< 嗡鸣 >"
	set category = "Emotes"
	usr.emote("buzz", intentional = TRUE)

/mob/living/proc/emote_beep()
	set name = "< 哔 >"
	set category = "Emotes"
	usr.emote("beep", intentional = TRUE)

/mob/living/proc/emote_beep2()
	set name = "< 尖锐哔声 >"
	set category = "Emotes"
	usr.emote("beep2", intentional = TRUE)

/mob/living/proc/emote_buzz2()
	set name = "< 两声嗡鸣 >"
	set category = "Emotes"
	usr.emote("buzz2", intentional = TRUE)

/mob/living/proc/emote_chime()
	set name = "< 铃声 >"
	set category = "Emotes"
	usr.emote("chime", intentional = TRUE)

/mob/living/proc/emote_honk()
	set name = "< 欢快鸣笛 >"
	set category = "Emotes"
	usr.emote("honk", intentional = TRUE)

/mob/living/proc/emote_ping()
	set name = "< 叮 >"
	set category = "Emotes"
	usr.emote("ping", intentional = TRUE)

/mob/living/proc/emote_sad()
	set name = "< 悲伤长号 >"
	set category = "Emotes"
	usr.emote("sad", intentional = TRUE)

/mob/living/proc/emote_warn()
	set name = "< 警告鸣响 >"
	set category = "Emotes"
	usr.emote("warn", intentional = TRUE)

/mob/living/proc/emote_slowclap()
	set name = "< 慢速鼓掌 >"
	set category = "Emotes"
	usr.emote("slowclap", intentional = TRUE)

// modular_nova\modules\emotes\code\additionalemotes\overlay_emote.dm
/mob/living/proc/emote_sweatdrop()
	set name = "| 汗滴 |"
	set category = "Emotes+"
	usr.emote("sweatdrop", intentional = TRUE)

/mob/living/proc/emote_exclaim()
	set name = "| 感叹号 |"
	set category = "Emotes+"
	usr.emote("exclaim", intentional = TRUE)

/mob/living/proc/emote_question()
	set name = "| 问号 |"
	set category = "Emotes+"
	usr.emote("question", intentional = TRUE)

/mob/living/proc/emote_realize()
	set name = "| 恍然大悟 |"
	set category = "Emotes+"
	usr.emote("realize", intentional = TRUE)

/mob/living/proc/emote_annoyed()
	set name = "| 恼怒 |"
	set category = "Emotes+"
	usr.emote("annoyed", intentional = TRUE)

/mob/living/proc/emote_glasses()
	set name = "| 推眼镜 |"
	set category = "Emotes+"
	usr.emote("glasses", intentional = TRUE)

//modular_nova\modules\emotes\code\additionalemotes\turf_emote.dm
/mob/living/proc/emote_mark_turf()
	set name = "| 标记地块 |"
	set category = "Emotes+"
	usr.emote("turf", intentional = TRUE)
