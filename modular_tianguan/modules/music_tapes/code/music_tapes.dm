// THIS IS A TIANGUAN MODULE FILE
// 模块：music_tapes —— 纳米传讯音响（Nanomusic boombox）的歌曲磁带（货舱商品）
//
// 机制：boombox 本身不带歌，歌在「磁带」里 —— 每盘磁带引用一个 looping_sound，
//       而 looping_sound 的 mid_sounds 用**编译期字面量**引用音频文件（这是关键：
//       BYOND 只把「编译期出现过字面量」的资源打进 .rsc，运行期拼出来的路径不会进包，
//       客户端就会拿不到音频而静默失败）。
//       mid_length 用的单位是**分秒（deciseconds）**，由逐帧解析 mp3 头实测得出，
//       必须与文件真实时长一致，否则会提前切歌或拖尾。
//
// 歌名：游戏内只显示歌名本身（磁带 name / song_name 都是歌名，不含作者/专辑/年份等其他文字）。
//
// 货舱：**一盘磁带一个商品**（各自独立订购，不做大礼包），音响本体也单独一个商品。
//       商品包挂在 /datum/supply_pack/service/ 下 —— 与游戏原有的音响商品
//       （/datum/supply_pack/service/boombox「MC Starter Kit & Boombox」）同一分类；
//       定义在本模块里 ⇒ 不碰 code/ 下的任何文件。音响本体不另设商品（游戏原本就在卖）。
//
// 音频：本模块自带 10 首 mp3（BYOND 原生支持 mp3，故原样收录、不做转码）。
//       新增歌曲四步：① 文件放进 sound/music/boombox/ ② 加一个 looping_sound 子类型
//       （mid_sounds 字面量 + mid_length） ③ 加一盘对应磁带 ④ 加一个货舱商品包。

// ───────────────────────── 歌曲（looping_sound） ─────────────────────────
// 音量/声道等沿用父类 /datum/looping_sound/boombox 的设置，这里只给文件与时长。

/datum/looping_sound/boombox/tianguan_loonboon
	mid_sounds = list('modular_tianguan/modules/music_tapes/sound/music/boombox/loonboon.mp3' = 1)
	mid_length = 999

/datum/looping_sound/boombox/tianguan_in_the_house
	mid_sounds = list('modular_tianguan/modules/music_tapes/sound/music/boombox/in_the_house_in_a_heartbeat.mp3' = 1)
	mid_length = 2613

/datum/looping_sound/boombox/tianguan_theme
	mid_sounds = list('modular_tianguan/modules/music_tapes/sound/music/boombox/papers_please_theme.mp3' = 1)
	mid_length = 955

/datum/looping_sound/boombox/tianguan_resident_evil
	mid_sounds = list('modular_tianguan/modules/music_tapes/sound/music/boombox/resident_evil_main_title.mp3' = 1)
	mid_length = 1158

/datum/looping_sound/boombox/tianguan_midnightride
	mid_sounds = list('modular_tianguan/modules/music_tapes/sound/music/boombox/midnightride.mp3' = 1)
	mid_length = 1940

/datum/looping_sound/boombox/tianguan_one_bad_man
	mid_sounds = list('modular_tianguan/modules/music_tapes/sound/music/boombox/onebadman.mp3' = 1)
	mid_length = 1837

/datum/looping_sound/boombox/tianguan_kuanti
	mid_sounds = list('modular_tianguan/modules/music_tapes/sound/music/boombox/kuanti.mp3' = 1)
	mid_length = 1316

/datum/looping_sound/boombox/tianguan_ultimate_battle
	mid_sounds = list('modular_tianguan/modules/music_tapes/sound/music/boombox/ultimate_battle.mp3' = 1)
	mid_length = 959

/datum/looping_sound/boombox/tianguan_pompeii
	mid_sounds = list('modular_tianguan/modules/music_tapes/sound/music/boombox/pompeii.mp3' = 1)
	mid_length = 2194

/datum/looping_sound/boombox/tianguan_athletes_march
	mid_sounds = list('modular_tianguan/modules/music_tapes/sound/music/boombox/athletes_march.mp3' = 1)
	mid_length = 1349

// ───────────────────────── 磁带（每首歌一盘） ─────────────────────────
// name 与 song_name 都只写歌名（需求：游戏内不要出现别的文字）；
// 贴图沿用上游磁带的四色（白/蓝/红/黄）轮换，不新增美术资源。

/obj/item/music_tape/tianguan_loonboon
	name = "Loonboon"
	song_name = "Loonboon"
	song_inside = /datum/looping_sound/boombox/tianguan_loonboon
	icon_state = "tape_white"

/obj/item/music_tape/tianguan_in_the_house
	name = "In the House - In a Heartbeat"
	song_name = "In the House - In a Heartbeat"
	song_inside = /datum/looping_sound/boombox/tianguan_in_the_house
	icon_state = "tape_blue"

/obj/item/music_tape/tianguan_theme
	name = "Theme"
	song_name = "Theme"
	song_inside = /datum/looping_sound/boombox/tianguan_theme
	icon_state = "tape_red"

/obj/item/music_tape/tianguan_resident_evil
	name = "Resident Evil Main Title Theme"
	song_name = "Resident Evil Main Title Theme"
	song_inside = /datum/looping_sound/boombox/tianguan_resident_evil
	icon_state = "tape_yellow"

/obj/item/music_tape/tianguan_midnightride
	name = "Midnightride"
	song_name = "Midnightride"
	song_inside = /datum/looping_sound/boombox/tianguan_midnightride
	icon_state = "tape_white"

/obj/item/music_tape/tianguan_one_bad_man
	name = "One Bad Man"
	song_name = "One Bad Man"
	song_inside = /datum/looping_sound/boombox/tianguan_one_bad_man
	icon_state = "tape_blue"

/obj/item/music_tape/tianguan_kuanti
	name = "宽体"
	song_name = "宽体"
	song_inside = /datum/looping_sound/boombox/tianguan_kuanti
	icon_state = "tape_red"

/obj/item/music_tape/tianguan_ultimate_battle
	name = "Ultimate Battle"
	song_name = "Ultimate Battle"
	song_inside = /datum/looping_sound/boombox/tianguan_ultimate_battle
	icon_state = "tape_yellow"

/obj/item/music_tape/tianguan_pompeii
	name = "Pompeii"
	song_name = "Pompeii"
	song_inside = /datum/looping_sound/boombox/tianguan_pompeii
	icon_state = "tape_white"

/obj/item/music_tape/tianguan_athletes_march
	name = "运动员进行曲"
	song_name = "运动员进行曲"
	song_inside = /datum/looping_sound/boombox/tianguan_athletes_march
	icon_state = "tape_blue"

// 供自检脚本与商品包复用的一份清单（也是「有哪些歌」的单一来源）
GLOBAL_LIST_INIT(tianguan_music_tape_paths, list(
	/obj/item/music_tape/tianguan_loonboon,
	/obj/item/music_tape/tianguan_in_the_house,
	/obj/item/music_tape/tianguan_theme,
	/obj/item/music_tape/tianguan_resident_evil,
	/obj/item/music_tape/tianguan_midnightride,
	/obj/item/music_tape/tianguan_one_bad_man,
	/obj/item/music_tape/tianguan_kuanti,
	/obj/item/music_tape/tianguan_ultimate_battle,
	/obj/item/music_tape/tianguan_pompeii,
	/obj/item/music_tape/tianguan_athletes_march,
))

// ───────────────────────── 货舱商品（一盘磁带一个商品） ─────────────────────────
// 需求：不做大礼包，每首歌各自独立订购。价格按「一个标准板条箱价」为基准，
// 音响本体单独一档（略高）。要调价直接改 cost 倍数即可。


/datum/supply_pack/service/nanomusic_tape_loonboon
	name = "Loonboon"
	desc = "一盘歌曲磁带。"
	cost = CARGO_CRATE_VALUE
	contains = list(/obj/item/music_tape/tianguan_loonboon)
	crate_name = "Loonboon"

/datum/supply_pack/service/nanomusic_tape_in_the_house
	name = "In the House - In a Heartbeat"
	desc = "一盘歌曲磁带。"
	cost = CARGO_CRATE_VALUE
	contains = list(/obj/item/music_tape/tianguan_in_the_house)
	crate_name = "In the House - In a Heartbeat"

/datum/supply_pack/service/nanomusic_tape_theme
	name = "Theme"
	desc = "一盘歌曲磁带。"
	cost = CARGO_CRATE_VALUE
	contains = list(/obj/item/music_tape/tianguan_theme)
	crate_name = "Theme"

/datum/supply_pack/service/nanomusic_tape_resident_evil
	name = "Resident Evil Main Title Theme"
	desc = "一盘歌曲磁带。"
	cost = CARGO_CRATE_VALUE
	contains = list(/obj/item/music_tape/tianguan_resident_evil)
	crate_name = "Resident Evil Main Title Theme"

/datum/supply_pack/service/nanomusic_tape_midnightride
	name = "Midnightride"
	desc = "一盘歌曲磁带。"
	cost = CARGO_CRATE_VALUE
	contains = list(/obj/item/music_tape/tianguan_midnightride)
	crate_name = "Midnightride"

/datum/supply_pack/service/nanomusic_tape_one_bad_man
	name = "One Bad Man"
	desc = "一盘歌曲磁带。"
	cost = CARGO_CRATE_VALUE
	contains = list(/obj/item/music_tape/tianguan_one_bad_man)
	crate_name = "One Bad Man"

/datum/supply_pack/service/nanomusic_tape_kuanti
	name = "宽体"
	desc = "一盘歌曲磁带。"
	cost = CARGO_CRATE_VALUE
	contains = list(/obj/item/music_tape/tianguan_kuanti)
	crate_name = "宽体"

/datum/supply_pack/service/nanomusic_tape_ultimate_battle
	name = "Ultimate Battle"
	desc = "一盘歌曲磁带。"
	cost = CARGO_CRATE_VALUE
	contains = list(/obj/item/music_tape/tianguan_ultimate_battle)
	crate_name = "Ultimate Battle"

/datum/supply_pack/service/nanomusic_tape_pompeii
	name = "Pompeii"
	desc = "一盘歌曲磁带。"
	cost = CARGO_CRATE_VALUE
	contains = list(/obj/item/music_tape/tianguan_pompeii)
	crate_name = "Pompeii"

/datum/supply_pack/service/nanomusic_tape_athletes_march
	name = "运动员进行曲"
	desc = "一盘歌曲磁带。"
	cost = CARGO_CRATE_VALUE
	contains = list(/obj/item/music_tape/tianguan_athletes_march)
	crate_name = "运动员进行曲"
