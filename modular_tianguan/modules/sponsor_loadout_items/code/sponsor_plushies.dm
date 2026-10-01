// SPONSOR_LOADOUT_ITEMS - 天关赞助者玩偶（本模块自建物品）
//
// 三只赞助者专属玩偶：在配装（loadout）界面里开放给「赞助者」，判定与其它赞助者物品同源
// （donator_only ⇒ 走 Nova 捐赠者机制，名单在 config/nova/donators.txt，见 sponsor_loadout_items.dm 顶部说明）。
//
// 为什么单开一个文件：sponsor_loadout_items.dm 只管「解锁上游既有的配装条目」（清单 + 运行期 New() 覆盖），
// 本文件是「天关自建的新物品」——物品类型与配装条目都在这里，清单那边一行都不用动
// （未解的 item_path 不在 TIANGUAN_SPONSOR_ITEM_PATHS 里，也不需要：那套机制只用于改上游条目的字段）。
//
// 素材：需求方提供的三张玩偶稿，装配成 32×32 后落在本模块的 icons/plushies.dmi（三帧一态，dirs=1）。

/// 天关自建玩偶的公共父类：只负责把图标指到本模块的图集。
/// 不加这行会继承基类的 'icons/obj/toys/plushes.dmi'，按下面的 icon_state 去找而「查无此图」。
/obj/item/toy/plush/tianguan
	icon = 'modular_tianguan/modules/sponsor_loadout_items/icons/plushies.dmi'
	inhand_icon_state = null // 与仓库其它玩偶同款写法（手持态不做专属贴图）

/obj/item/toy/plush/tianguan/xindiliya
	name = "辛迪莉亚娃娃"
	desc = "一个猩红玩偶，有一种阴谋与邪恶。"
	icon_state = "plushie_xindiliya"

/obj/item/toy/plush/tianguan/huitu
	name = "绘兔娃娃"
	desc = "某一天绘兔在图书馆里拿起了针线与织布。。。于是绘兔娃娃诞生了。"
	icon_state = "plushie_huitu"

/obj/item/toy/plush/tianguan/luna
	name = "Luna娃娃"
	desc = "心血来潮的绘兔在那天看着Luna，以她的样貌做出来绘兔的第二个娃娃。"
	icon_state = "plushie_luna"

// ——— 配装条目 ———
// 挂 /datum/loadout_item/toys/plush ⇒ 落在配装界面的 Toys（玩具）页签、Plushies 分组
// （继承来的 group = "Plushies"，并且继承 LOADOUT_FLAG_ALLOW_NAMING ⇒ 玩家可给玩偶改名/改描述，
//  与上游玩偶一致；改名后的描述走 /obj/item/toy/plush/on_loadout_custom_described() 回写）。
// Toys 页签每角色最多 3 件（/datum/loadout_category/toys 的 max_allowed），与既有玩具共用这个额度。
//
// donator_only 是非默认值 ⇒ 写在类型体里编译期就生效，不需要像解锁清单那样在运行期改
// （只有「赋成 null」这种写法才会被编译器当成没写）。条目 item_path 全是新的，
// 不会与上游撞 GLOB.all_loadout_datums 的键（那个键是 item_path）。

/datum/loadout_item/toys/plush/xindiliya
	name = "辛迪莉亚娃娃"
	item_path = /obj/item/toy/plush/tianguan/xindiliya
	donator_only = TRUE

/datum/loadout_item/toys/plush/huitu
	name = "绘兔娃娃"
	item_path = /obj/item/toy/plush/tianguan/huitu
	donator_only = TRUE

/datum/loadout_item/toys/plush/luna
	name = "Luna娃娃"
	item_path = /obj/item/toy/plush/tianguan/luna
	donator_only = TRUE
