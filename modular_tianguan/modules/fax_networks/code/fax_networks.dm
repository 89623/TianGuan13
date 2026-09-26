// FAX_NETWORKS —— 天关新增的传真（Fax Machine）网络目的地。
// 模块说明见 modular_tianguan/modules/fax_networks/readme.md。
//
// 为什么挂在 New() 而不是 Initialize()：
// 上游 Nova 的 modular_nova/master_files/code/modules/paperwork/fax.dm 已经定义过
// /obj/machinery/fax/Initialize()（往 special_networks 追加它自己的 Tarkon/Interdyne/… 网络），
// 而 DM 不允许同一类型上重复定义同一个 proc —— 在这里再写一份 Initialize 会直接编译报错
// （`duplicate definition`，tgstation.dme 里 TG_LOBBY 那两处 TIANGUAN EDIT REMOVAL 同因）。
// 因此本模块改挂该类型上另一个**尚无任何文件定义**的 per-instance 入口 New()：
//   · special_networks 是实例变量（每个实例一份副本），实例化时已带好初值，写入一定生效；
//   · 地图加载期 New() 先于 Initialize()，运行期 new 则后于它 —— 两种顺序都只是
//     「往一个 assoc list 写固定键」，与 Nova 在 Initialize 里的追加互不干扰。
// 若上游将来给 /obj/machinery/fax 加了自己的 New()，这里会变成编译错误（响亮的失败，不会静默失效），
// 届时按 readme「维护备注」改成接管 Nova 那份 Initialize 即可。

/obj/machinery/fax/New(loc, ...)
	. = ..()
	// 键（同时也是 act 回传标识）不可翻译；显示名由 strings/i18n/<locale>/_fax_networks.json 反查。
	special_networks["uar_admin"] = list(
		fax_name = "Union of Allied Republics Local Administrative Committee",
		fax_id = "uar_admin",
		color = "uar_darkred", // TGUI 按钮色档：tgui-core 没有深红，由 main.scss 的 .Button--color--uar_darkred 提供
		emag_needed = FALSE,
	)
