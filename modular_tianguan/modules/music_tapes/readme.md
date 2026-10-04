# 纳米传讯音响歌曲磁带（music_tapes）

<!--PR 编号-->

## 简介

给游戏里已有的**纳米传讯音响**（`Nanomusic boombox`）扩充歌曲：新增 **10 首歌曲磁带**，
并在货舱上架成 **10 个独立商品**（一盘磁带一个商品，不打包）。

- 音响本体是上游既有物品，本模块**不改它的任何代码**，只新增歌曲数据与货舱商品。
- 游戏内磁带上**只显示歌名**，不显示作者/专辑/年份等其他文字。
- 音响本体**不另设商品**：游戏原本就有 `/datum/supply_pack/service/boombox`
  「MC Starter Kit & Boombox」（含一台音响 + 一盘演示磁带），货舱里买那一个即可。

## 主要功能

| 功能 | 说明 |
| --- | --- |
| 10 首歌曲 | 每首 = 一个 `/datum/looping_sound/boombox/tianguan_*`（文件 + 实测时长） |
| 10 盘磁带 | 每盘 `/obj/item/music_tape/tianguan_*`，`name` 与 `song_name` 都只写歌名 |
| 10 个货舱商品 | `/datum/supply_pack/service/nanomusic_tape_*`，分类继承 **Service**（与原有音响商品同分类） |
| 音频原样收录 | 10 首 mp3 共 49.8 MB，**不做转码**（BYOND 原生支持 mp3） |

歌名清单（游戏内只显示这些）：`Loonboon`、`In the House - In a Heartbeat`、`Theme`、
`Resident Evil Main Title Theme`、`Midnightride`、`One Bad Man`、`宽体`、`Ultimate Battle`、
`Pompeii`、`运动员进行曲`。

## ⚠️ 已知问题（尚未解决，用户实测上报）

> **货舱订购这些磁带后，部分商品送不到（用户反馈：英文歌名的磁带到不了）。**

已排查并确认的机制（供后续接手用）：

1. **箱子只能落在穿梭机的空格地板上**：`code/modules/shuttle/mobile_port/variants/supply.dm` 的
   `buy()` 里 `if(!empty_turfs.len) break` —— 穿梭机地板被占满（通常是上几趟没搬走的旧箱子）时，
   **静默跳过、箱子根本不生成，订单仍挂在购物车**。⇒ 看穿梭机地板上有没有堆箱子即可判断。
2. **商品分类必须挂在「存在的父类型」下**：目录由 `subtypesof(/datum/supply_pack)` 构建
   （`code/controllers/subsystem/shuttle.dm:162`），分类来自父类型的 `group`
   （`/datum/supply_pack/service` → `group = "Service"`）。**此前误挂在 `/datum/supply_pack/general`
   之下（仓库里没有这个父类型）⇒ `group = ""` ⇒ 界面里这几个商品没有分类**。本模块已改为 `service/`。
3. **商品 id**：`/datum/supply_pack` 的 `id = type`（`code/modules/cargo/packs/_packs.dm:37`），
   前端加购发的是 `pack.id`（`tgui/.../Cargo/CargoCatalog.tsx`），服务端按 id 回查
   `SSshuttle.supply_packs[id]` ⇒ id 必须是类型路径、唯一。
4. 已排除：地图不缺货舱穿梭机模板（模板按名字在 `_maps/shuttles/` 下递归加载，三张图绑的模板均存在）；
   控制台的 `cargo_shuttle`/`docking_home`/`docking_away` 三个 id 与地图一致；
   服务器启动日志无 asset/icon 报错。

**仍未定位的部分**：为何**英文歌名**的那几盘在实测中到不了、而中文歌名的能到（见 3 的 id 链条与
i18n 的形状差异），需要在**有客户端的真实跑局**里逐单核对（无头探针只能验数值/状态，
验不了穿梭机的实际往返与卸货）。

## 新增与修改的文件

| 文件 | 说明 |
| --- | --- |
| `modular_tianguan/modules/music_tapes/code/music_tapes.dm` | 歌曲 + 磁带 + 货舱商品（新增） |
| `modular_tianguan/modules/music_tapes/sound/music/boombox/*.mp3` | 10 首歌曲音频（新增，49.8 MB） |
| `modular_tianguan/modules/music_tapes/readme.md` | 本文档（新增） |
| `tgstation.dme` | +1 行 include（**唯一的核心文件改动**） |

## 是否改核心

**否。** 只改了 `tgstation.dme` 一行 include；商品包定义在本模块内，不改 `code/` 下任何文件。

## 测试方式

1. **编译**：`dm.exe tgstation.dme -DCBT` ⇒ 0 errors（本机 BYOND 516，2026-10-04 实测）。
   - ⚠️ 编译前**必须**：① 杀净 `dreamdaemon.exe`（运行中的世界锁着图标文件 ⇒ `cannot find file`）；
     ② 若 `icons/obj/fluff/map_previews.dmi` 被跑局覆盖过则 `git checkout --` 取回
     （否则电脑/控制台图标会显示成 ERROR 占位图）。详见「维护备注」。
2. **资源进包**：`grep -c "<音频文件名>" tgstation.rsc` 每首应为 1（10/10 实测通过）。
3. **结构自检**（脚本）：10 个 `looping_sound` ⇄ 10 个音频文件一一对应；`mid_length` = 逐帧解析
   mp3 头实测的分秒值；10 盘磁带 `name == song_name` 且块内无 desc/lore；
   10 个商品各只含 1 件、每盘磁带都有对应商品、分类父类型为 `service`。
4. **引擎探针**（无头，验运行期事实）：10 盘磁带全部实例化成功、`song_inside` 无一条 CRASH ⇒
   每首歌的音频路径在运行期是通的（磁带初始化时找不到 `looping_sound` 会直接 CRASH）。
5. **游戏内**：连服 → 货舱控制台 → Service 分类 → 应列出 10 盘磁带（各自独立订购）→
   买一盘 → 点「送出穿梭机」→ 等它回来取出磁带放入音响播放。

## 维护备注

- **加一首歌四步**：① 音频放 `sound/music/boombox/`（文件名用 ASCII，避免空格/中文/引号）；
  ② 加一个 `/datum/looping_sound/boombox/tianguan_<名>`（`mid_sounds` 用**编译期字面量**引用文件 ——
  只有字面量才会被打进 `.rsc`，运行期拼路径不会进包、客户端会静默拿不到音频；`mid_length` 用实测分秒）；
  ③ 加一盘 `/obj/item/music_tape/tianguan_<名>`（`name`/`song_name`/`song_inside`）；
  ④ 加一个 `/datum/supply_pack/service/nanomusic_tape_<名>`，并加进 `GLOB.tianguan_music_tape_paths`。
- **商品包必须挂在存在的父类型下**（本项目用 `/datum/supply_pack/service` ⇒ 继承 `group = "Service"`），
  否则 `group` 为空 ⇒ 货舱界面里没有分类。
- **价格**：磁带 = `CARGO_CRATE_VALUE`，直接改 `cost` 即可。
- **音频体积**：10 首 49.8 MB，`tgstation.rsc` 随之增大；嫌大可在落地前转 ogg（会改变编码）。
- **图标/编译两个反复踩过的坑**（与跑局有关，不是本模块引入）：
  1. `icons/obj/fluff/map_previews.dmi` 会被跑局重新生成，若编译时它正被改写/被进程占用，
     编译会报一堆 `'.../map_previews.dmi': cannot find file`；**带 `CBT` 编译**（官方 `BUILD.cmd` 就是这么传的）
     可让电脑图标改走 `computer.dmi`，从结构上不受影响。
  2. **编译前先杀净 `dreamdaemon.exe`**，否则运行中的世界锁着图标文件，同样导致上面的报错。
