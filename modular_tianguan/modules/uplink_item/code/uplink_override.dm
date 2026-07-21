// modular_nova/modules/traitor-uplinks/overwrites/ 把这两件禁售了（purchasable_from = NONE），
// 这里恢复上游 tgstation 的默认值 ALL。本文件的 include 必须排在 modular_nova 之后才生效。
// blastcannon 仍保留核心的 restricted_roles（科研主管/科学家）与 progression_minimum（30 分钟）。
/datum/uplink_item/role_restricted/blastcannon
	purchasable_from = ALL

/datum/uplink_item/device_tools/briefcase_launchpad
	purchasable_from = ALL
