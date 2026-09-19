// SPONSOR_LOADOUT_ITEMS - 天关赞助者配装物品
// 天关模块：给「赞助者」开放配装（loadout）物品。
//
// 名单不写进代码：走 Nova 自带的捐赠者机制（donator_only = TRUE），
// 可领取的 ckey 由 config/nova/donators.txt 决定 —— 该文件由
// config/nova/config_nova.txt 的 DONATOR_LEGACY_SYSTEM 开关启用，
// 读取实现见 modular_nova/modules/player_ranks/code/player_rank_controller/
// donator_controller.dm 与 _player_rank_controller.dm 的 load_legacy()
// （逐行读、跳过空行与 # 开头的注释、每项过 ckey()）。
// 判定点：modular_nova/modules/loadouts/loadout_items/_loadout_datum.dm 的 can_be_applied_to()。
// 名单变动 = 改 config/nova/donators.txt 一处，不需要改代码、不需要重编。
// 注意：is_donator() 默认 admin_bypass = TRUE，管理员等同于捐赠者 —— Nova 既有行为。

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

/// 官方猫印章 —— 模块化覆盖 Nova 上游的既有条目（见 readme 的「模块化覆盖」段落）。
/// 上游定义：modular_nova/modules/loadouts/loadout_items/donator/personal/donator_personal.dm:748
///   /datum/loadout_item/inhand/officialcat
///       item_path = /obj/item/stamp/cat
///       ckeywhitelist = list("kathrinbailey")
/// 上游那条只放行 kathrinbailey（Nova 外服的捐赠者，天关不会出现），这里改成捐赠者可见。
/// can_be_applied_to() 与前端 FilterItemList 都是「ckey_whitelist 非空且不含你 → 隐藏/拒绝」，
/// 所以必须把上游那串 ckeywhitelist 清掉，否则赞助者看不到、也拿不到猫印章。
/// ⚠️ 清空只能在运行期做：DM 里跨文件把继承变量赋成 null **静默不生效**（null 等于默认值，
/// 编译器不记录这次变更），实测「赋非默认值生效、赋 null 不生效」——所以 ckeywhitelist = null
/// 写在类型体里没用，必须放进 New()。
/// GLOB.all_loadout_datums 以 item_path 为键、同一 item_path 只能存在一个 datum（再建一条会互相覆盖），
/// 因此不新建 datum，只在既有条目上覆盖。
/// 本文件在 tgstation.dme 中排在 modular_nova 之后，同类型同变量的跨文件重复赋值后 include 者生效。
/datum/loadout_item/inhand/officialcat
	donator_only = TRUE // 非默认值，跨文件覆盖有效

/datum/loadout_item/inhand/officialcat/New(category)
	. = ..()
	ckeywhitelist = null // 运行期清空上游的 kathrinbailey 白名单（编译期赋 null 不生效，见上）
