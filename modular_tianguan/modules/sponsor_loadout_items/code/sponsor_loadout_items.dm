// SPONSOR_LOADOUT_ITEMS - 天关赞助者配装物品
// 天关模块：为赞助者名单内的玩家开放配装（loadout）物品。
// 写法对齐 Nova 上游的捐赠者配装
// （modular_nova/modules/loadouts/loadout_items/donator/personal/donator_personal.dm）：
// 一件物品一个 datum，用 ckeywhitelist 指定可领取的 ckey，分类按物品本身的性质选。
// 新增 datum 不需要手工注册 —— /datum/loadout_item/inhand|toys|pocket_items 的子类型
// 由配装页对应分类经 typesof() 自动收录（code/modules/loadout/loadout_categories.dm）。

/// 天关赞助者 ckey（来源：赞助者名单.txt，19 人）。
/// 用 #define 而不是共享的全局 list：loadout 建表时会对 ckeywhitelist 逐项就地做 ckey() 改写
/// （code/modules/loadout/loadout_categories.dm:50-52），共享同一个 list 对象会让几个 datum 互相污染。
#define TIANGUAN_SPONSOR_CKEYS list("spoonypineapple", "lanhongqiu", "cbhqwer1234", "scavenger160", "poorvk", "kuiteman", "threesides", "whitenightwalker", "16suki", "mangonxd", "devonydevil", "gentleman2020", "feelings", "izumikonataovo", "Heyan", "A1010733586", "Realrain", "Ccnd1145", "mh516")

/// 长气球盒 —— Toys 页签（Nova 的玩具类配装都挂这里：蜡笔/激光笔/骰子/毛绒玩具…），该页签上限 3 件
/datum/loadout_item/toys/sponsor_box_of_long_balloons
	name = "box of long balloons"
	item_path = /obj/item/storage/box/balloons
	ckeywhitelist = TIANGUAN_SPONSOR_CKEYS

/// B@L00NY 技能芯片 —— Other 页签（/datum/loadout_item/pocket_items，杂项），该页签上限 3 件
/datum/loadout_item/pocket_items/sponsor_b_l00ny_skillchip
	name = "B@L00NY skillchip"
	item_path = /obj/item/skillchip/job/clown
	ckeywhitelist = TIANGUAN_SPONSOR_CKEYS

/// 官方猫印章 —— 模块化覆盖 Nova 上游的既有条目，直接顶掉它的白名单（见 readme 的「模块化覆盖」段落）。
/// 上游定义：modular_nova/modules/loadouts/loadout_items/donator/personal/donator_personal.dm:748
///   /datum/loadout_item/inhand/officialcat
///       item_path = /obj/item/stamp/cat
///       ckeywhitelist = list("kathrinbailey")   ← 上游外服捐赠者，天关（国服）不会出现，故直接顶掉
/// GLOB.all_loadout_datums 以 item_path 为键，给同一 item_path 再建一个 datum 会撞键并覆盖前者
/// （code/modules/loadout/loadout_categories.dm:24-26），所以这里不新建 datum，只重声明白名单。
/// 本文件在 tgstation.dme 中排在 modular_nova 之后，同类型同变量的跨文件重复赋值后 include 者生效。
/datum/loadout_item/inhand/officialcat
	ckeywhitelist = TIANGUAN_SPONSOR_CKEYS

#undef TIANGUAN_SPONSOR_CKEYS
