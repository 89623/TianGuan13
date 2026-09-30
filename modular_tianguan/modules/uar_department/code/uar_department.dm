/**
 * 团结联盟（UAR）部门 + 团结联盟审查官（UAR_DEPARTMENT）
 *
 * 这是「新增一个部门 + 部门内一个职业」的最小可用实现。
 * 机制说明（哪一层负责什么、换名字/换美术要动哪些地方）见本模块 readme.md。
 *
 * 分三层，各自独立：
 *   1. code/__DEFINES/jobs.dm —— 职业名 / 显示序号 / 部门位标志 / 部门显示名（TIANGUAN EDIT 标记）
 *   2. 本文件 —— /datum/job_department（部门本身，含 TGUI 用的 ui_color）+ /datum/job + outfit + id_trim
 *   3. tgui/.../JobsPage.tsx —— 角色偏好菜单里的部门分栏（该文件是硬编码部门清单，必须手工加一栏）
 */

/// 部门/职业在 TGUI 里用的颜色：JobSelection（加入菜单）列头底色、角色偏好菜单整行底色、ID 卡部门色块。
/// 取值沿用团结联盟深红（与传真机模块的 `uar_darkred` 按钮档、`themes/uar.scss` 同一色系）。
#define UAR_DEPARTMENT_COLOR "#8b0000"

/// 部门。注册方式：只要某个 joinable 职业在 departments_list 里写了这个类型，
/// SSjob.setup_occupations() 就会自己 `new` 出来（见 code/controllers/subsystem/job.dm:188-193）——
/// 没有别的注册表要登记。
/datum/job_department/uar
	department_name = DEPARTMENT_UAR
	department_bitflags = DEPARTMENT_BITFLAG_UAR
	// department_head 故意不设：本部门暂时没有主管。不设 = 职业名在偏好菜单里不加粗、
	// 部门位标志里也不带 JOB_HEAD_OF_STAFF；上游同样做法的先例是 /datum/job_department/assistant。
	display_order = 9
	ui_color = UAR_DEPARTMENT_COLOR
	// 分离主义者（separatist）建国时会给部门随机起名，前缀池留一份免得 pick(空表) 运行时报错。
	nation_prefixes = list("Allian", "Republi", "Union", "Inspectora", "Consul")

/// 职业本体。注意 3 件事：
///   * title 是数据库键（job ban / 时长统计 / 偏好都按这个字符串存），改名等于换一个职业；
///   * department_for_prefs 决定它在**角色偏好菜单**里归到哪一栏（留空则取 departments_list[1]）；
///   * departments_list 决定它在**加入菜单**（JobSelection）里归到哪个部门。
/datum/job/uar_inspector
	title = JOB_UAR_INSPECTOR
	description = "代表团结联盟常驻本站，审查站内事务、传达联盟的意见。"
	faction = FACTION_STATION
	total_positions = 1
	spawn_positions = 1
	supervisors = "团结联盟"
	exp_granted_type = EXP_TYPE_CREW

	// ── 游玩门槛：与纳米传讯顾问（NTC）完全一致 ──────────────────────────────
	// 值只是**声明**，是否真的拦人由 config/config.txt 的开关决定：
	//   USE_EXP_TRACKING（需数据库）+ USE_EXP_RESTRICTIONS_HEADS（本职业走"部门桶"这条分支）。
	// 服务器若要改这个数字，可以不改仓库：config/jobconfig.toml 里按 [UAR_INSPECTOR] 覆盖。
	// 详见 modular_tianguan/modules/uar_department/readme.md 的「游玩门槛」一节。
	minimal_player_age = 14
	exp_requirements = 600
	exp_required_type = EXP_TYPE_CREW
	exp_required_type_department = EXP_TYPE_COMMAND

	paycheck = PAYCHECK_CREW
	paycheck_department = ACCOUNT_CIV

	outfit = /datum/outfit/job/uar_inspector

	display_order = JOB_DISPLAY_ORDER_UAR_INSPECTOR
	department_for_prefs = /datum/job_department/uar
	departments_list = list(
		/datum/job_department/uar,
	)

	job_flags = STATION_JOB_FLAGS
	config_tag = "UAR_INSPECTOR"
	rpg_title = "Inspector"
	// job_icons 单测要求：带 JOB_CREW_MANIFEST 的职业必须有 tgui_icon（fontawesome 常量，清单见 code/__DEFINES/font_awesome_icons.dm）
	tgui_icon = FA_ICON_USER_TIE

/datum/outfit/job/uar_inspector
	name = JOB_UAR_INSPECTOR
	jobtype = /datum/job/uar_inspector

	// 卡必须是 trim 支持的 advanced 卡，outfit 的 id_trim 才会被套上去（见 code/datums/outfit.dm:206-216）
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/job/uar_inspector
	uniform = /obj/item/clothing/under/suit/black
	shoes = /obj/item/clothing/shoes/laceup
	belt = /obj/item/modular_computer/pda/crew
	ears = /obj/item/radio/headset

/// ID 卡上的部门信息。测试阶段全部复用现有美术：
///   * trim_state 用 assistant 的卡面徽记（换新徽记要自带 dmi，见 readme「换美术」一节）；
///   * sechud_icon_state 复用 assistant 的安保 HUD 图标；
///   * department_color 用本部门深红，subdepartment_color 用团结联盟蓝星。
/datum/id_trim/job/uar_inspector
	assignment = JOB_UAR_INSPECTOR
	trim_state = "trim_assistant"
	department_color = UAR_DEPARTMENT_COLOR
	subdepartment_color = "#1f3a8a"
	sechud_icon_state = SECHUD_ASSISTANT
	minimal_access = list()
	extra_access = list(
		ACCESS_MAINT_TUNNELS,
	)
	template_access = list(
		ACCESS_CAPTAIN,
		ACCESS_CHANGE_IDS,
		ACCESS_HOP,
	)
	job = /datum/job/uar_inspector
