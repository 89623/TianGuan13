// SPONSOR_LOADOUT_ITEMS - 天关赞助者配装物品
// 天关模块：给「赞助者」开放配装（loadout）物品。
//
// 赞助者身份：走 Nova 自带的捐赠者机制（donator_only = TRUE），可领取的 ckey 由
// config/nova/donators.txt 决定 —— 该文件由 config/nova/config_nova.txt 的
// DONATOR_LEGACY_SYSTEM 开关启用，读取实现见 modular_nova/modules/player_ranks/code/
// player_rank_controller/donator_controller.dm 与 _player_rank_controller.dm 的 load_legacy()
// （逐行读、跳过空行与 # 开头的注释、每项过 ckey()）。
// 判定点：modular_nova/modules/loadouts/loadout_items/_loadout_datum.dm 的 can_be_applied_to()。
// 名单变动 = 改 config/nova/donators.txt 一处，不需要改代码、不需要重编。
// 注意：is_donator() 默认 admin_bypass = TRUE，管理员等同于捐赠者 —— Nova 既有行为。
//
// 物品来源：上游 modular_nova 的捐赠者私人配装 donator_personal.dm，条目形如
//   /datum/loadout_item/<分类>/<名字>  →  name = "..."  item_path = /obj/item/...
//                                         ckeywhitelist = list("<某位 Nova 捐赠者>")
// 那些 ckey 对天关没有意义。本模块把 TIANGUAN_SPONSOR_ITEM_PATHS 里每条 item_path 的条目
// 统一改成「捐赠者可见」：ckeywhitelist 清空 + donator_only = TRUE。
// 上游条目自带的职业限定（restricted_roles：安保/矿工/舰长/NTC…）**原样保留**，
// 即需求方要的「赞助者专属」叠加上「职业限定」；本模块不碰其它任何字段。

/// 天关赞助者可领的物品清单（item_path），共 148 条：
/// belts 1、glasses 4、gloves 7、head 13、inhand 4、mask 11、neck 12、pocket_items 13、shoes 8、suit 30、toys 2、under 43。
/// 收录标准：上游条目原本带 ckeywhitelist（某位 Nova 捐赠者的私人配装）或已设 donator_only ——
/// 对这些条目做「解锁」，赞助者才拿得到。上游本来就没设限制（对所有人开放）的条目**不收录**，
/// 免得把它们变成赞助者专属（＝对其他人收回）；见文件末尾的「保持原样」清单。
/// 清单变动 = 改这里一处；上游若重命名/删除某条 item_path，对应条目会静默失去解锁
/// （下面 tianguan_unlock_sponsor_item() 之外的逻辑不受影响）。
#define TIANGUAN_SPONSOR_ITEM_PATHS list(\
	/* belts (1) */ \
	/obj/item/storage/belt/fannypack/occult, \
	/* glasses (4) */ \
	/obj/item/clothing/glasses/eyepatch/rosecolored, \
	/obj/item/clothing/glasses/gold_aviators, \
	/obj/item/clothing/glasses/hud/security/sunglasses/gars/giga/roselia, \
	/obj/item/clothing/glasses/rosecolored, \
	/* gloves (7) */ \
	/obj/item/clothing/gloves/ecologist, \
	/obj/item/clothing/gloves/fingerless/blutigen_wraps, \
	/obj/item/clothing/gloves/merctac_glove, \
	/obj/item/clothing/gloves/mikugloves, \
	/obj/item/clothing/gloves/netra, \
	/obj/item/clothing/gloves/padded, \
	/obj/item/clothing/gloves/skyy, \
	/* head (13) */ \
	/obj/item/clothing/glasses/welding/steampunk_goggles, \
	/obj/item/clothing/head/costume/owlhat, \
	/obj/item/clothing/head/costume/ushanka/avipilot, \
	/obj/item/clothing/head/costume/ushanka/frosty, \
	/obj/item/clothing/head/drake_skull, \
	/obj/item/clothing/head/gabeny, \
	/obj/item/clothing/head/helmet/donator/stachelm, \
	/obj/item/clothing/head/helmet/space/plasmaman/candlejax2, \
	/obj/item/clothing/head/mikuhair, \
	/obj/item/clothing/head/nanotrasen_consultant/hubert, \
	/obj/item/clothing/head/razurathhat, \
	/obj/item/clothing/head/recruiter_cap, \
	/obj/item/instrument/piano_synth/headphones/catear_headphone, \
	/* inhand (4) */ \
	/obj/item/mob_holder/pet/donator/centralsmith, \
	/obj/item/stamp/cat, \
	/obj/item/storage/backpack/merctac_backpack, \
	/obj/item/storage/backpack/satchel/drop_pouch, \
	/* mask (11) */ \
	/obj/item/clothing/mask/animal/wolf, \
	/obj/item/clothing/mask/breath/vox/octus, \
	/obj/item/clothing/mask/gas/CMCP_mask, \
	/obj/item/clothing/mask/gas/britches, \
	/obj/item/clothing/mask/gas/caligram_visage_mask, \
	/obj/item/clothing/mask/gas/larpswat, \
	/obj/item/clothing/mask/gas/psycho_malice, \
	/obj/item/clothing/mask/gas/signalis_gaiter, \
	/obj/item/clothing/mask/hheart, \
	/obj/item/clothing/mask/luchador/enzo, \
	/obj/item/clothing/mask/merctac_mask, \
	/* neck (12) */ \
	/obj/item/clothing/neck/cloak/fluffycloak, \
	/obj/item/clothing/neck/cloak/grunnyyy, \
	/obj/item/clothing/neck/cloak/inferno, \
	/obj/item/clothing/neck/cross, \
	/obj/item/clothing/neck/fishpendant, \
	/obj/item/clothing/neck/noble_mantle, \
	/obj/item/clothing/neck/padded, \
	/obj/item/clothing/neck/padded/alt, \
	/obj/item/clothing/neck/padded/security, \
	/obj/item/clothing/neck/tattered, \
	/obj/item/clothing/neck/trenchcoat, \
	/obj/item/clothing/suit/hooded/cloak/zuliecloak, \
	/* pocket_items (13) */ \
	/obj/item/canvas/drawingtablet, \
	/obj/item/card/fuzzy_license, \
	/obj/item/clothing/suit/armor/hos/trenchcoat/melon, \
	/obj/item/clothing/suit/armor/vest/darkcarapace, \
	/obj/item/clothing/suit/hooded/explorer/melon, \
	/obj/item/crusher_trophy/retool_kit/ahab, \
	/obj/item/hairbrush/tactical, \
	/obj/item/holocigarette/cigar, \
	/obj/item/implanter/toaster, \
	/obj/item/poster/korpstech, \
	/obj/item/seeds/starfruit, \
	/obj/item/sign/flag/pride/bon, \
	/obj/item/storage/belt/espatier, \
	/* shoes (8) */ \
	/obj/item/clothing/shoes/clown_shoes/britches, \
	/obj/item/clothing/shoes/ecologist, \
	/obj/item/clothing/shoes/fancy_heels/drag, \
	/obj/item/clothing/shoes/jackboots/netra, \
	/obj/item/clothing/shoes/jackboots/noble, \
	/obj/item/clothing/shoes/jackboots/padded, \
	/obj/item/clothing/shoes/rem_shoes, \
	/obj/item/clothing/shoes/sneakers/mikuleggings, \
	/* suit (30) */ \
	/obj/item/clothing/head/anubite, \
	/obj/item/clothing/suit/armor/donator/duke_armored_coat, \
	/obj/item/clothing/suit/armor/skyy, \
	/obj/item/clothing/suit/armor/vest/nanotrasen_consultant/hubert, \
	/obj/item/clothing/suit/armor/vest/warden/rax, \
	/obj/item/clothing/suit/blutigen_kimono, \
	/obj/item/clothing/suit/brownbattlecoat/elysiancoat, \
	/obj/item/clothing/suit/costume/butter, \
	/obj/item/clothing/suit/hooded/colorblockhoodie, \
	/obj/item/clothing/suit/hooded/ecologist, \
	/obj/item/clothing/suit/hooded/occult, \
	/obj/item/clothing/suit/hooded/sigmarcoat, \
	/obj/item/clothing/suit/hooded/techpriest, \
	/obj/item/clothing/suit/jacket/bomber_donor, \
	/obj/item/clothing/suit/jacket/brasspriest, \
	/obj/item/clothing/suit/jacket/cherno, \
	/obj/item/clothing/suit/jacket/delta, \
	/obj/item/clothing/suit/jacket/gorlex_harness, \
	/obj/item/clothing/suit/jacket/hydrogenrobes, \
	/obj/item/clothing/suit/jacket/ryddid, \
	/obj/item/clothing/suit/jacket/skyy, \
	/obj/item/clothing/suit/razurathcoat, \
	/obj/item/clothing/suit/scraparmour, \
	/obj/item/clothing/suit/toggle/desminus, \
	/obj/item/clothing/suit/toggle/desminus2, \
	/obj/item/clothing/suit/toggle/labcoat/nova/tenrai, \
	/obj/item/clothing/suit/toggle/labcoat/vic_dresscoat_donator, \
	/obj/item/clothing/suit/toggle/rainbowcoat, \
	/obj/item/clothing/suit/toggle/recruiter_jacket, \
	/obj/item/clothing/under/wetsuit_norm, \
	/* toys (2) */ \
	/obj/item/hairbrush/switchblade, \
	/obj/item/toy/plush/nova/donator/immovable_rod, \
	/* under (43) */ \
	/obj/item/clothing/under/bimpcap, \
	/obj/item/clothing/under/bodysuit_koruu, \
	/obj/item/clothing/under/bubbly_clown_skirt, \
	/obj/item/clothing/under/bwake, \
	/obj/item/clothing/under/costume/draculass, \
	/obj/item/clothing/under/costume/dragon_maid, \
	/obj/item/clothing/under/costume/nova/kimono/sigmar, \
	/obj/item/clothing/under/costume/shendyt, \
	/obj/item/clothing/under/custom/blutigen_undergarment, \
	/obj/item/clothing/under/custom/lannese, \
	/obj/item/clothing/under/custom/lannese/vambrace, \
	/obj/item/clothing/under/dress/ambassadordagmar, \
	/obj/item/clothing/under/dress/heirloomdagmar, \
	/obj/item/clothing/under/dress/neoflapperdagmar, \
	/obj/item/clothing/under/ecologist, \
	/obj/item/clothing/under/mikubikini, \
	/obj/item/clothing/under/misc/nova/mechanic, \
	/obj/item/clothing/under/nt_idol_skirt, \
	/obj/item/clothing/under/occult, \
	/obj/item/clothing/under/padded, \
	/obj/item/clothing/under/padded/alt, \
	/obj/item/clothing/under/pants/half_leotard_cosmiclaer, \
	/obj/item/clothing/under/pants/merctac_pants, \
	/obj/item/clothing/under/pants/skyy, \
	/obj/item/clothing/under/plasmaman/candlejax, \
	/obj/item/clothing/under/plasmaman/candlejax2, \
	/obj/item/clothing/under/plasmaman/jax2, \
	/obj/item/clothing/under/rank/blueshield/netra, \
	/obj/item/clothing/under/rank/captain/dress, \
	/obj/item/clothing/under/rank/cargo/qm/skirt/old, \
	/obj/item/clothing/under/rank/civilian/chaplain/divine_archer/noble, \
	/obj/item/clothing/under/rank/civilian/clown/britches, \
	/obj/item/clothing/under/rank/civilian/curator/treasure_hunter/noble_enforcer, \
	/obj/item/clothing/under/rank/civilian/viper_suit, \
	/obj/item/clothing/under/rank/nanotrasen_consultant/hubert, \
	/obj/item/clothing/under/rank/security/head_of_security/alt/roselia, \
	/obj/item/clothing/under/rank/security/rax, \
	/obj/item/clothing/under/recruiter_uniform, \
	/obj/item/clothing/under/rem, \
	/obj/item/clothing/under/sweater_dress, \
	/obj/item/clothing/under/syndicate/tacticool/skirt/long, \
	/obj/item/clothing/under/tactichill, \
	/obj/item/clothing/under/techpants \
)

/// 把一条配装条目改成「天关赞助者可见」。
/// 为什么在运行期改、而不是在类型体里写 donator_only = TRUE / ckeywhitelist = null：
///   - ckeywhitelist 必须运行期清 —— DM 里跨文件把继承变量赋成 null 会静默失效
///     （null 等于默认值，编译器不记录这次变更；实测「赋非默认值生效、赋 null 不生效」）；
///   - 本批 155 条逐条写类型体既冗余又容易漏，且上游重命名后无法察觉。
/proc/tianguan_unlock_sponsor_item(datum/loadout_item/entry)
	entry.ckeywhitelist = null
	entry.donator_only = TRUE

/// 统一解锁：覆盖 core 的 /datum/loadout_item/New(category)
/// （code/modules/loadout/loadout_items.dm:65）。配装条目由各分类的 get_items() 用
/// `new found_type(src)` 实例化后登记进 GLOB.all_loadout_datums，此处即那些单例的创建点；
/// 判定依据是实例的 item_path（初值在 New 之前就已就位）。
/// 本文件在 tgstation.dme 中排在 modular_nova 之后，同名 proc 的后定义者生效，..() 链到 core 那份。
/datum/loadout_item/New(category)
	. = ..()
	if(item_path in TIANGUAN_SPONSOR_ITEM_PATHS)
		tianguan_unlock_sponsor_item(src)

// ——— 上游没有配装条目、需本模块新建的条目 ———
// 这些物件的 item_path 不在 donator_personal.dm 里，新建 datum 声明 name/item_path 即可；
// donator_only 由上面的统一解锁逻辑设置（两条创始批物品的 item_path 已写死在各自类型体里，
// 不依赖清单匹配）。

/// 长气球盒 —— Toys 页签（Nova 的玩具类配装都挂这里：蜡笔/激光笔/骰子/毛绒玩具…），该页签上限 3 件
/datum/loadout_item/toys/sponsor_box_of_long_balloons
	name = "box of long balloons"
	item_path = /obj/item/storage/box/balloons
	donator_only = TRUE

/// B@L00NY 技能芯片 —— Other 页签（/datum/loadout_item/pocket_items，杂项），该页签上限 3 件
/datum/loadout_item/pocket_items/sponsor_b_l00ny_skillchip
	name = "B@L00NY skillchip"
	item_path = /obj/item/skillchip/job/clown
	donator_only = TRUE

/// 便携式硬光轮椅发生器（/obj/item/holosign_creator/hardlight_wheelchair 定义在
/// modular_nova/modules/customization/modules/clothing/~donator/donator_items.dm:231，
/// 但不在 donator_personal.dm 里）—— 需求方要求给所有赞助者，落在 Other 页签。
/// 它不在上面的清单里（那张表只收上游既有条目），donator_only 由本类型体直接声明。
/datum/loadout_item/pocket_items/sponsor_hardlight_wheelchair
	name = "hardlight wheelchair emitter"
	item_path = /obj/item/holosign_creator/hardlight_wheelchair

// ——— 上游有条目、但需求方额外要求加职业限定的 ———

/// 需求方特别指定：这两件上游没有职业限制，天关要求 NTC（纳米顾问）独有
/// （JOB_NT_REP = "Nanotrasen Consultant"，见 code/__DEFINES/jobs.dm:136）。
/// 非默认值，跨文件覆盖有效。
/datum/loadout_item/head/razurathhat
	restricted_roles = list(JOB_NT_REP)

/datum/loadout_item/suit/razurathcoat
	restricted_roles = list(JOB_NT_REP)

// ——— 清单内、上游自带职业限定的条目（原样继承，共 19 条，格式：item_path  restricted_roles）———
//  /obj/item/clothing/glasses/hud/security/sunglasses/gars/giga/roselia list(ALL_JOBS_DEPTGUARD, ALL_JOBS_SEC,)
//  /obj/item/clothing/head/helmet/donator/stachelm                list(JOB_CAPTAIN, JOB_BLUESHIELD)
//  /obj/item/clothing/head/nanotrasen_consultant/hubert           list(JOB_NT_REP)
//  /obj/item/clothing/suit/armor/donator/duke_armored_coat        list(JOB_CAPTAIN)
//  /obj/item/clothing/suit/armor/hos/trenchcoat/melon             list(JOB_HEAD_OF_SECURITY)
//  /obj/item/clothing/suit/armor/skyy                             list(JOB_HEAD_OF_PERSONNEL, JOB_NT_REP)
//  /obj/item/clothing/suit/armor/vest/caligram_parka_vest     （已移出清单：上游无白名单，见下方「保持原样」）
//  /obj/item/clothing/suit/armor/vest/nanotrasen_consultant/hubert list(JOB_NT_REP)
//  /obj/item/clothing/suit/armor/vest/warden/rax                  list(ALL_JOBS_SEC)
//  /obj/item/clothing/suit/hooded/explorer/melon                  list(JOB_SHAFT_MINER)
//  /obj/item/clothing/under/bimpcap                               list(JOB_CAPTAIN)
//  /obj/item/clothing/under/bubbly_clown_skirt                    list(JOB_CLOWN)
//  /obj/item/clothing/under/nt_idol_skirt                         list(JOB_NT_REP)
//  /obj/item/clothing/under/plasmaman/jax2                        list(ALL_JOBS_SCI, JOB_VIROLOGIST)
//  /obj/item/clothing/under/rank/blueshield/netra                 list(JOB_CAPTAIN, JOB_BLUESHIELD, JOB_HEAD_OF_SECURITY)
//  /obj/item/clothing/under/rank/captain/dress                    list(JOB_CAPTAIN)
//  /obj/item/clothing/under/rank/nanotrasen_consultant/hubert     list(JOB_NT_REP)
//  /obj/item/clothing/under/rank/security/head_of_security/alt/roselia list(JOB_HEAD_OF_SECURITY)
//  /obj/item/clothing/under/rank/security/rax                     list(ALL_JOBS_SEC)
//  /obj/item/crusher_trophy/retool_kit/ahab                       list(JOB_SHAFT_MINER)


// ——— 保持原样：上游本就对所有人开放（无 ckeywhitelist / donator_only）的条目 ———
// 需求清单里有这几件，但它们本来就任何人都能领（含赞助者），加入解锁清单只会把它们变成
// 赞助者专属，故按需求方要求维持原状、不做任何处理。
//  /obj/item/clothing/head/caligram_cap                             Caligram Tan Softcap
//  /obj/item/clothing/mask/gas/nightlight                           FIR-36 Rebreather
//  /obj/item/clothing/mask/gas/nightlight/fir22                     FIR-22 Full-Face Rebreather
//  /obj/item/clothing/suit/armor/vest/caligram_parka_vest           Caligram Armored Tan Parka
//  /obj/item/clothing/suit/jacket/caligram_parka                    Caligram Tan Parka
//  /obj/item/clothing/under/jumpsuit/caligram_fatigues              Caligram Tan Fatigues
//  /obj/item/holocigarette/masvedishcigar                           Holocigar

#undef TIANGUAN_SPONSOR_ITEM_PATHS
