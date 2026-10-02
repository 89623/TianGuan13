// THIS IS A TIANGUAN MODULE FILE
// 模块：uar_human_lore —— 捏人面板「人类（Human）」的介绍与背景文案（团结联盟共和国设定）
//
// 做法：本文件给 /datum/species/human 追加两个**新 var**（DM 允许跨文件给既有类型加 var，
//       因此这一步零核心改动），核心文件 humans.dm 里那两个 proc 各加一处最小钩子
//       （TIANGUAN EDIT ADDITION），优先返回本 var；未设置时自动回退原文案。
//
// 为什么不能完全模块化：get_species_description() / get_species_lore() 在
//       code/modules/mob/living/carbon/human/species_types/humans.dm 里是硬编码 return，
//       DM 里同类型同 proc 重复定义 = duplicate definition 编译错误，
//       故只能走"最小钩子"路线（见 modular_tianguan/readme.md 的覆盖路线说明）。

/datum/species/human
	/// 捏人面板「人类」条目的介绍（一段摘要）。非空即覆盖核心文案。
	var/uar_species_description = "在放射尘与核冬天的黑暗严冬下，不屈的人类崛起。他们拼尽全力改造已经破败衰竭的自然环境，使其重新焕发生机。他们呼喊意志统一的口号，在群体的力量下冲出引力井。"
	/// 捏人面板「人类」条目的背景（多段，逐段显示）。非空即覆盖核心文案。
	var/list/uar_species_lore = list(
		"以传统人类的风格，他们从大地到终极边疆的近乎创纪录的步伐，是对他们如今同台竞技的其他种族的公然威胁。",
		"人类实现了政治经济的统一，并集合在一个暴力的旗帜下，宣称要对所有外星种族进行复仇，而在内部又实行严格统治，又力所能及的对每一个同胞给予照顾，确保他们能在风雨飘摇的银河中生存下去，并以此帮助其他人。",
		"人类的机会和进取精神以巅峰形式延续：超级公司。在团结联盟共和国影响力之外，字面上和比喻上，超级公司收买所需的议会选票，并在团结联盟政府触及范围之外建立领地。在超级公司领地，公司政策即法律，赋予“员工终止”新的含义。但这一切尚未终止，在扩无可扩下，超级公司还能作为这个疯狂的复仇主义政权用来消化占领地的工具吗？",
	)
