/**
 * 禁掉开局装配里的两项植入体：螳螂刀（左/右）与光学迷彩（隐身）
 *
 * 说明：这两样不是配装（loadout）菜单里的物品条目，而是 Nova 的「植入体」偏好
 * （`/datum/augment_item`，角色设置 → 肢体/植入体页），被选上后开局由
 * `/datum/preference_middleware/limbs_and_markings/apply_to_human()` 装进身体。
 *
 * 关法：给这三个条目加 **ckey 白名单**（该字段的语义就是「只有名单里的 ckey 能拿到」），
 * 填一个不存在的 ckey ⇒ 对所有人关闭：
 *   · 前端 `tgui/.../CharacterPreferences/LimbsPage.tsx` 的 `isAugAllowed()` 会把它从可选列表里
 *     **过滤掉**（`aug.ckey_whitelist && !includes(ckey)` ⇒ false）⇒ 看不到、点不到；
 *   · 服务端 `is_aug_valid_for_prefs()` 同样返回 FALSE，`set_bodypart_aug` /
 *     `set_internal_implant_aug` 都走它 ⇒ 就算伪造请求也选不上；
 *   · 开局发放 `apply_to_human()` 也走同一个判定 ⇒ 旧存档里已经选过的角色**不会再被装上去**。
 *
 * 为什么不用「从 GLOB.augment_items 里删掉」：`apply_to_human()` 会用
 * `GLOB.augment_items[存档路径]` 直接取实例再读字段，删掉后是 null ⇒ 旧存档一开局就在
 * `is_aug_valid_for_prefs()` 上抛 runtime。白名单写法两全。
 *
 * 全程零核心 / 零 Nova 改动（只重声明既有类型的变量，后 include 者生效）。
 */

/// 占位 ckey：BYOND 的 ckey 只有小写字母和数字，没有任何玩家会撞上这个名字
#define AUGMENT_LOCKED_CKEY "tianguan_augment_unavailable"

/datum/augment_item/implant/chest/optical_camo // 光学迷彩（隐身模块）
	ckey_whitelist = list(AUGMENT_LOCKED_CKEY)

/datum/augment_item/implant/l_arm/mantis_blade_left // 螳螂刀（左）
	ckey_whitelist = list(AUGMENT_LOCKED_CKEY)

/datum/augment_item/implant/r_arm/mantis_blade_right // 螳螂刀（右）
	ckey_whitelist = list(AUGMENT_LOCKED_CKEY)

#undef AUGMENT_LOCKED_CKEY
