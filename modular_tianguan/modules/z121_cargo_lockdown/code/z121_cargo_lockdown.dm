/**
 * z121 武器 / 弹药退出货舱（cargo 订购）
 *
 * 背景：`modular_z121/code/modules/Company_imports/interns_project_emporium.dm` 把这批东西挂进了
 * 货舱的公司订购目录（★ Ballistic Weapons / ★ Energy Weapons / ★ Magazines and Ammo）：
 * 10 个武器包 + 11 个弹药/弹匣包。天关不要它们能被货舱买到，但**也不想动 z121 的原始定义**
 * （上游同步会冲突、以后想恢复还得翻 git）。
 *
 * 做法：在**供货包注册阶段**拦掉。`/datum/controller/subsystem/shuttle/Initialize()` 的流程是：
 *
 *     for(pack in subtypesof(/datum/supply_pack))
 *         pack = new pack
 *         ...
 *         if(!pack.contains) continue         ← 就靠这一句
 *         supply_packs[pack.id] = pack
 *
 * 本模块覆写 `/datum/supply_pack/New()`：命中黑名单的类型建实例时把 `contains` 置空，
 * 于是它压根进不了 `SSshuttle.supply_packs` ⇒ 订购台、快递台、流散货箱事件都看不到它。
 * `contains` 是**运行期**赋 null（DM 的类型定义里赋 null 等于没写，所以不能用重声明的方式）。
 *
 * 可逆：删掉本模块 + 它那行 include 就恢复上架，z121 一行代码都没被改过。
 */

/// 要下架的 z121 供货包（路径见 modular_z121/code/modules/Company_imports/interns_project_emporium.dm）
GLOBAL_LIST_INIT(tianguan_z121_blocked_supply_packs, typecacheof(list(
	// ——— 武器（10）———
	/datum/supply_pack/companies/ballistics/intern_project/sidearm/sofap,     // SOFAP 自动手枪
	/datum/supply_pack/companies/ballistics/intern_project/sidearm/tac9,      // TAC-9 战斗手枪
	/datum/supply_pack/companies/ballistics/intern_project/sidearm/bfr500,    // BFR-500 单动式左轮
	/datum/supply_pack/companies/ballistics/intern_project/primary/crossbow,  // 十字弩
	/datum/supply_pack/companies/ballistics/intern_project/primary/aa12,      // AA12 全自动霰弹枪
	/datum/supply_pack/companies/ballistics/intern_project/primary/evo,       // EVO-13 冲锋枪
	/datum/supply_pack/companies/ballistics/intern_project/primary/europa,    // europa 通用机枪
	/datum/supply_pack/companies/ballistics/intern_project/primary/dex4,      // DEX-4 智能霰弹枪
	/datum/supply_pack/companies/ballistics/intern_project/primary/solstice,  // Solstice 重型狙击枪
	/datum/supply_pack/companies/energy/intern_project/photon_sniper,         // 光子狙击步枪
	// ——— 弹药 / 弹匣（11）———
	/datum/supply_pack/companies/mags_and_ammo/intern_project/c20nuoli,          // .20 Nuoli 致命弹 ×200
	/datum/supply_pack/companies/mags_and_ammo/intern_project/c20nuoli_smart,    // .20 Nuoli 智能弹 ×200
	/datum/supply_pack/companies/mags_and_ammo/intern_project/c20nuoli_breacher, // .20 Nuoli 反器材弹 ×200
	/datum/supply_pack/companies/mags_and_ammo/intern_project/bolt,              // 钢制弩箭
	/datum/supply_pack/companies/mags_and_ammo/intern_project/tac9,              // TAC-9 空弹匣
	/datum/supply_pack/companies/mags_and_ammo/intern_project/bfr500,            // BFR-500 快速装弹器
	/datum/supply_pack/companies/mags_and_ammo/intern_project/aa12_mag,          // AA12 空弹匣
	/datum/supply_pack/companies/mags_and_ammo/intern_project/aa12_drum,         // AA12 空弹鼓
	/datum/supply_pack/companies/mags_and_ammo/intern_project/evo_mag,           // EVO-13 空弹匣
	/datum/supply_pack/companies/mags_and_ammo/intern_project/europa_mag,        // europa 空弹盒
	/datum/supply_pack/companies/mags_and_ammo/intern_project/dex4_mag,          // DEX-4 空弹匣
)))

/datum/supply_pack/New()
	. = ..() // 先让上游（core 的 id = type、Nova 的 auto_name）跑完，再决定要不要下架
	if(is_type_in_typecache(src, GLOB.tianguan_z121_blocked_supply_packs))
		contains = null // SSshuttle 注册时的 `if(!pack.contains) continue` 会把我们跳过
