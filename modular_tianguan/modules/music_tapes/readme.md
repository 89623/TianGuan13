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

## 货舱订购的四条机制（上游行为，不是本模块的 bug）

> **用户实测记录**（同一局 `cargo.html`，一次订 10 盘）：
> `2 orders in this shipment, worth 400 credits. 100 credits left.` →
> 13 分钟后 `7 orders in this shipment, worth 1400 credits. 100 credits left.`
> ⇒ 第一趟只到 2 盘、其余在下一趟到齐。**与歌名/语言无关。**

**1. 一趟能发几单，由「货舱账户余额」决定（最关键）**

`code/modules/shuttle/mobile_port/variants/supply.dm` 的 `buy()` 逐单发货并**从货舱账户扣钱**
（每箱 = `pack.cost`，磁带 = `CARGO_CRATE_VALUE` = 200）：

```dm
if(!paying_for_this.adjust_money(-price, "Cargo: [spawning_order.pack.name]"))
	if(!spawning_order.can_be_cancelled)   // 普通订单可取消 ⇒ 不删，留在购物车
		SSshuttle.shopping_list -= spawning_order
		continue
```

- **余额不足的订单留在购物车，等下一趟（账户攒够钱后）继续发** ⇒ 「一次订 10 盘、只到 2 盘、
  其余随后才到」就是这么来的；
- 排在**购物车前面**的先轮到钱 ⇒ 表现为「有的先到有的后到」，**与商品/歌名/语言无关**；
- ⇒ **想一趟全收到，先保证货舱账户余额 ≥ 商品总价**（10 盘磁带 = 2000）。

**2. 需要两次点击（去 + 回）**

装货只发生在「**从采购点出发**」那一刻（同文件的 `initiate_docking`）：

```dm
if(getDockedId() == "cargo_away")   // 只有从采购点出发时
	buy()                             // 才逐单扣款发货、装箱上穿梭机
```

控制台那一个按钮两种状态（`code/modules/cargo/orderconsole.dm:418`）：
在站 ⇒ 派它去采购（空车去）；在采购点 ⇒ 召回。⇒ 点「送出」+ 再点一次。

**3. ⚠️ 派车离开站时，穿梭机上没搬走的箱子会被当出口物资自动卖掉**

`buy()`/`sell()` 在到达采购点时会结算穿梭机上的货物（实测日志：
`contents sold for 400 credits. Contents: 运动员进行曲 - #4724,宽体 - #4723`）
⇒ **货到了要第一时间从穿梭机上搬下来**，否则连箱带货一起被回收。

**4. 装货还需要「空格地板」**

箱子落在穿梭机地板空格上，`if(!empty_turfs.len) break`。梭机地板实测 55 格（`cargo_delta.dmm`），
正常一趟装十几箱不成问题；但旧箱子堆着不搬走会逐渐减少可用格数，仍建议每趟清空。

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
