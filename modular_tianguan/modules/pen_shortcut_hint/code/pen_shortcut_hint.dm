// PEN_SHORTCUT_HINT - 笔的文书快捷输入提示
// 天关模块：检视**普通书写笔**时，在原有介绍下追加一行快捷输入格式提示。
// 快捷格式实现在 code/modules/paperwork/paper.dm（%s -> 签名, %d -> 日期, %t -> 时间）。
// 伪装/武器类笔（笔刀、催眠笔、爆破笔、uplink 笔等）不提示——它们并非用于写文书。

/// 不提示文书快捷格式的特殊笔：伪装成笔的武器/工具
GLOBAL_LIST_INIT(pen_shortcut_hint_exempt, list(
	/obj/item/pen/destroyer, // "Fine Tipped Pen"，无限锋利，用于拆结构与伤人
	/obj/item/pen/edagger, // 笔刀，点击变形为武器
	/obj/item/pen/sleepy, // 催眠笔，戳人注入试剂
	/obj/item/pen/penbang, // 伪装成笔的闪光弹
	/obj/item/pen/uplink, // 伪装成笔的 uplink 终端
))

/// 检视普通书写笔时提示文书快捷输入格式
/obj/item/pen/examine(mob/user)
	. = ..()
	if(is_type_in_list(src, GLOB.pen_shortcut_hint_exempt))
		return
	. += span_notice("%s输入角色签名 %d输入日期 %t输入时间")
