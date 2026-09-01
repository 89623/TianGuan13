// PEN_SHORTCUT_HINT - 笔的文书快捷输入提示
// 天关模块：检视任意笔时，在原有介绍下追加一行快捷输入格式提示。
// 快捷格式实现在 code/modules/paperwork/paper.dm（%s -> 签名, %d -> 日期, %t -> 时间）。

/// 检视笔时提示文书快捷输入格式
/obj/item/pen/examine(mob/user)
	. = ..()
	. += span_notice("%s输入角色签名 %d输入日期 %t输入时间")
