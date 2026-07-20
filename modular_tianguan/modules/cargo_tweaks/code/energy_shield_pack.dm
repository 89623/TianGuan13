// 单兵能量盾（民用版）货物订单调整
// 售价 400cr -> 10000cr
// order_flags 去掉 ORDER_DEPARTMENTAL_GOODY（只留 ORDER_GOODY），
// 使其无法用货运/部门预算下单，必须由个人账户私人订购
/datum/supply_pack/companies/armor/bolt/energy_shield
	cost = 10000
	order_flags = ORDER_GOODY
