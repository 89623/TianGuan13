/datum/uplink_item/badass/syndicate_battle_cruiser
	name = "辛迪加独立旅传呼密信"
	desc = "团结联盟共和国的死敌叛军独立旅的呼叫工具，如果这里需要被彻底摧毁的话。那么我们只需在通讯控制台使用这个，然后静候毁灭到来。注意：我们的战列巡洋舰无法登陆冰月"
	item = /obj/item/storage/box/syndie_kit/syndicate_battle_cruiser
	cost = 210
	cant_discount = TRUE
	purchasable_from = UPLINK_TRAITORS

/obj/item/storage/box/syndie_kit/syndicate_battle_cruiser
	name = "辛迪加战列巡洋舰呼叫套件"
	desc = "一个精致的盒子，被用来存放联络辛迪加正规军的通信工具。"

/obj/item/storage/box/syndie_kit/syndicate_battle_cruiser/PopulateContents()
	new /obj/item/card/emag/battlecruiser(src)
	new /obj/item/encryptionkey/syndicate(src)
	new /obj/item/encryptionkey/syndicate(src)
	new /obj/item/encryptionkey/syndicate(src)
	new /obj/item/encryptionkey/syndicate(src)
	new /obj/item/paper/fluff/operative/syndicate_battle_cruiser(src)

/obj/item/paper/fluff/operative/syndicate_battle_cruiser
	name = "呼叫辛迪加战列巡洋舰指南"
	default_raw_text = {"向特工同志致敬。
<br>当你看到这张纸的时候，想必您(们)已经获取了辛迪加战列巡洋舰呼叫套件。请仔细阅读以下指南，以确保您能够正确使用它。
<br>1. 你需要在通讯控制台上使用战列巡洋舰坐标上传卡。在您呼叫后，CentCom将会发送一则广播提醒全站船员，战列巡洋舰即将到达。请确保您已经做好了准备。
<br>2. 当战列巡洋舰到达时，CentCom将会发送关于未知武装舰船出现在空间站附近的广播。请<B><i>确保</i></B>使用套件附带的辛迪加耳机密钥与辛迪加战列巡洋舰船员取得联系，以便他们能够识别您(们)为辛迪加特工并且不会在登船时枪杀您(们)。
<br>3. 找到一个安全的地方或在船员的帮助下登上战列巡洋舰，静静观看空间站陷入火海，并最终被彻底摧毁。
<br>祝您成功特工同志，SBC星之怒号，前进四!"}
