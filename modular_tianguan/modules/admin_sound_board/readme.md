# admin_sound_board —— 管理员「全局音效面板」

## 模块简介

把原本的「播放全局音效」从**一次性动作**改造成**面板式的两阶段流程**（上传 → 预传输 → 播放）：
管理员先上传音频并等所有在线玩家就位，再点播放；音频在本局内一直保留，之后可反复播放，
中途新加入的玩家由服务端自动补传。

## 要解决的问题

原版 `code/modules/admin/verbs/playsound.dm` 里的 `play_sound` 是在**播放那一刻**给每个在线玩家
各发一份音频文件：

- 几十人同时来拉同一个文件 ⇒ 瞬时占满带宽 ⇒ 卡顿（尤其大文件）；
- 管理员点完播放就得**赌**客户端拉得动，没有任何进度反馈；
- 一局之内想再放一次，还得从头再发一遍；
- 中途加入的玩家只能等下一次播放时跟着一起拉。

## 主要功能

- **上传**：面板里的「上传音频」走现成的「点唱机上传音乐」（`fcopy` 落到
  `config/jukebox_music/sounds/`），因此与点唱机、与 `admin_countdown` 共用同一份曲库数据。
  **`.ogg` 与 `.mp3` 两种格式都收**（见「是否改核心」）。
- **按需传输（重要语义）**：**打开面板不会传输任何音频** —— 曲库里已有的那些显示「未传输」，
  只有两种方式会让某一首开始传：
  1. **本次上传的**（目录里新出现的文件）⇒ 自动开始传；
  2. **手动点名**：每行的「传输」按钮。
  否则一开面板就会把整个曲库推给所有人（带宽白烧，实测被指出语义不对）。
- **预传输**：把该音频**逐份**错开推进客户端缓存（一份 = 一个在线玩家的一份），
  面板上实时显示就绪人数；间隔可在面板上调（默认 1 秒/份）。
- **就绪门槛**：**只有某首音频的全部在线玩家都传完，它的播放按钮才亮**
  （前端置灰只是提示；服务端在 `play` 动作里**再核一次**）。
- **可重复播放**：音频在本局内一直保留，播放按钮可以反复点（播放不重置任何传输状态）。
  **播完会按曲目时长自动复位**「正在播放」（见下），也可以随时手动点「停止播放」。
- **中途新玩家**：服务端每秒 `register_clients()`，把新加入的玩家纳入队列，
  **只补传已激活过的那些**；面板上还有「立即补传新玩家」按钮可手动触发。
- **移除**：每行「播放」旁边的「移除」= **从服务器上删掉该音频**
  （属于 `config/` 的上传目录，点唱机曲库同步消失）。删文件不可恢复 ⇒ 先弹确认；
  文件名先过曲库校验，不接受任意字符串。
- **独立进度窗**：玩家数多时主面板铺不开 ⇒ 「查看传输详情」开**单独一个 TGUI 窗口**，
  可换行网格、每人一条进度条。

## 新增与修改的文件

| 文件 | 说明 |
| --- | --- |
| `modular_tianguan/modules/admin_sound_board/code/admin_sound_board.dm` | 新增。控制器 datum + 两个 TGUI datum（主面板 / 传输详情）+ 传输与播放逻辑 |
| `tgui/packages/tgui/interfaces/TianGuanSoundBoard.tsx` | 新增。主面板（上传 / 音量 / 间隔 / 音频列表 / 播放 / 停止） |
| `tgui/packages/tgui/interfaces/TianGuanSoundBoardTransfer.tsx` | 新增。传输详情窗口（网格 + 每人进度条） |
| `code/modules/admin/verbs/playsound.dm` | **改核心**：verb 入口改为打开面板（见下） |
| `code/modules/admin/verbs/jukebox_moderation.dm` | **改核心**：上传的格式检查由「只收 ogg」改为「ogg + mp3」（见下） |
| `strings/i18n/zh-Hans/datum.json` | 上传对话框的中文提示改为「.ogg 或 .mp3」（只改译文，键不动） |
| `tgstation.dme` | 加一行 include |

## 是否改核心

**是，只改一处，且只有一个分支：**

```dm
ADMIN_VERB(play_sound, R_SOUND, "播放全局音效", "Play a sound to all connected players.", ADMIN_CATEGORY_FUN)
	// TIANGUAN EDIT ADDITION START - ADMIN_SOUND_BOARD
	// 改为打开天关的「全局音效面板」：上传 → 预传输 → 就绪后播放
	tianguan_sound_board_open(user)
	return
	// TIANGUAN EDIT ADDITION END
	<原逻辑保留在下面，不再执行>
```

原因：管理员的使用入口就是这条 verb（「管理员」面板里点「播放全局音效」），
要把它变成面板入口就必须在这里转发。原逻辑**不删除**，便于对照与回退。

同步上游时注意：这段标记很显眼（原 proc 开头），冲突时保留天关分支即可。

**另有第二处（上传格式）**：`code/modules/admin/verbs/jukebox_moderation.dm` 的
`upload_jukebox_music` 原本只放行 ogg（`if(!IS_OGG_FILE(file))`），上传 mp3 会被弹窗拦下。
**倒计时放歌与全局音效面板的上传按钮走的都是这条 verb** ⇒ 一处放行、两处生效，所以只能改核心。

```dm
/* // TIANGUAN EDIT REMOVAL START - ADMIN_SOUND_BOARD   ← 原检查（保留原文，便于回退）
// we could theorticly support other sound types but ... I am 100% sure its length is properly fetched.
if(!IS_OGG_FILE(file))
	tgui_alert(user, LANG("datum.f9fede34ab022030", null), LANG("datum.e990db784bda09f4", null), list("Ok"))
	return
*/ // TIANGUAN EDIT REMOVAL END
// TIANGUAN EDIT ADDITION START - ADMIN_SOUND_BOARD
if(!IS_SOUND_FILE_SAFE(file))   // ← 按 SSsounds.safe_formats 判定：ogg + mp3
	tgui_alert(user, "文件类型无效。请选择 .ogg 或 .mp3 音频文件。", "无效的文件类型", list("Ok"))
	return
// TIANGUAN EDIT ADDITION END
```

**为什么放行 mp3 是安全的**：`SSsounds.safe_formats`（`code/controllers/subsystem/sounds.dm:58`）
的注释就是「rust-g **能取到时长**的格式」，清单里 ogg 与 mp3 两项都在。
而倒计时的连播推进 / 到点播放都依赖曲目时长 ⇒ 若 mp3 取不到时长就会有后果 —— 事实上取得到。
（`countdown_music.dm` 里还留了个「时长取不到就用 30 秒」的兜底，属第二道保险。）

另：该 verb 的描述文案同步改为 `.ogg or .mp3`，用单行 `TIANGUAN EDIT CHANGE … ORIGINAL:` 标记。

## 关键实现备注（都是实测踩过的坑）

- **`VERB_ARG` 会抢在 proc 之前弹文件框**：`ADMIN_VERB` 宏展开后是
  `dynamic_invoke_verb(usr, …)`（不带参数），参数由框架在调用 `__avd_do_verb` **之前**收集
  ⇒ 原 `VERB_ARG(sound, …, SOURCE_INPUT)` 会让管理员点进来只看到原始文件框、进不到面板。
  故连**整段原逻辑**一起用 `TIANGUAN EDIT REMOVAL` 停用。
  ⚠️ 只注释那一行不行：**它同时是 `sound` 变量的声明处**，会编译报 4 个 `sound: undefined var`。
- **入口参数是 `/client`，不是 mob**：`/client` 自己没有 `.client` 成员，
  写 `user.client` 会运行时报 `undefined variable /client/var/client` 并**静默打不开面板**。
  缓存读 `user.tianguan_sound_board_ui`，而 `ui_interact()` 必须收到 **mob** ⇒ 传 `user.mob`
  （与 `admin_countdown` 面板同一写法）。
- **⚠️ 定时器回调里必须清掉自己的句柄（本轮真 bug）**：`push_now()` 是 `addtimer` 的回调。
  它原来在「队列排空 ⇒ 不再续期」这条路径上**不清 `push_timer`** ⇒ 句柄变量留着那个**已烧掉的旧 id**，
  而唯一的启动闸门是 `length(queue) && !push_timer` ⇒ **队列排空过一次之后，新入队的份永远推不动**。
  实测症状：管理员「每次放完会把音乐移除掉」，于是队列排空过 ⇒ 之后再选多少首都只停在「待推」，
  点「传输」也不动。修法：**进入 `push_now()` 先 `push_timer = null`**（本回调就是它触发的，此刻已作废），
  队列非空再续期。
  ⇒ 教训：**别用「定时器句柄非 null」当"循环在跑"的判据** —— 句柄不会自己变 null。
- **移除了音频要把队列里它的份也剔除**：只清 `enabled_files` / `known_files` / 玩家逐文件表不够，
  `queue` 里的份会留下**永远消化不掉的幽灵**（实测：选 3 首 × 51 人 = 153，面板却显示 154）。
  见 `prune_queue_for()`（倒序遍历 + `Cut`，正序边遍历边改会漏项）。
- **自愈**：`register_clients()` 每秒会清掉「已不在曲库里」的音频 —— 包括 `enabled_files` 里的和
  `queue` 里的份。否则谁直接删了音频文件，`enabled_files` 会一直把「就绪」的分母撑住，
  所有玩家都到不了就绪、播放按钮永远不亮。
- **播完自动复位「正在播放」**：BYOND **收不到**「客户端播完了」这种通知（没有任何回调），
  所以只能在 `play()` 里按曲目时长自己掐一个 `addtimer` ⇒ 到点调 `clear_playing()` 清掉
  `playing_file`（`admin_countdown` 推进连播用的是同一套办法）。实现要点：
  - **重新播放会先 `deltimer` 掉旧定时器** ⇒ `clear_playing()` 只可能是"当前这一首"到点，不会误清新歌。
  - **`stop()` 与 `Destroy()` 都要取消它**，否则关面板/停播后还会被一个残留定时器清一次。
  - **+1 秒余量**：客户端起播有网络延迟，掐太死会在尾声就复位。
  - ⚠️ **调 `SSsounds.get_sound_length()` 在这里是安全的**：点唱机加载曲库时已经对**同一批文件**
    调过它（`code/datums/components/jukebox.dm:108`），长度早进了 `sound_lengths` 缓存 ⇒
    这里是**纯缓存命中**、不会再触发 rust-g 调用。
    （`get_sound_length()` 单个调用在 rust-g 报错时会 `CRASH` 整个服，所以这条"已经有人调过"很重要。）
  - **时长取不到（返回 0）就不排定时器**：宁可让管理员手动点「停止播放」，也不让按钮停在一个凭猜的状态上。
- **就绪判定必须逐文件记账**：推送是全局轮流（一次一份），只数"推了几份"会让就绪提前成立
  ⇒ 播放按钮在还没传到那首时就亮。因此每个玩家记 `files[文件名] = TRUE`。
- **首次登记要播种**：`register_clients()` 第一次调用时把**当时已有**的曲库记进 `known_files`，
  之后只有"新出现"的文件才自动激活 —— 否则一打开面板就把整个曲库排队传一遍。
- **进度分母用"已激活数"**，不是曲库总数（否则曲库里有 3 首、只激活 1 首时会显示 1/3）。
- **删文件后要清 `known_files`**：不清的话下一秒 tick 会把它当成"新出现"又加回来。
- **构建顺序**：**先 `rspack build` ⇒ 删 `tgstation.rsc` ⇒ 再编 DM**。
  反过来（先编 DM 后打包）会让 `.rsc` 里嵌着旧前端 ⇒ 面板上看不到新按钮（代码对也没用）。
- **播放构造**：必须照抄「能响的那条路」——`sound(路径)` 直接构造 + `channel = CHANNEL_JUKEBOX`。
  ⚠️ **不要**用「新建 sound + `.file = file(路径)` + `CHANNEL_ADMIN` + `status = SOUND_STREAM`」：
  实测该形状客户端**完全无声**，而服务端日志一切正常。
- **asset 缓存按文件内容寻址**（`md5asfile`）⇒ 传输与游戏内 `sound()` 天然共享同一份缓存。
  ⚠️ **不要**给上传的文件设 `keep_local_name`：那样传输存的键名与播放时按内容算出的键名不一致，
  反而会导致重新下载。
- **`input(user, ...) as sound|null` 是阻塞式对话框** ⇒ 在 `ui_act` 里必须用 `INVOKE_ASYNC` 调起
  （与 `tgui_alert` 同一套路）。上传本身复用 `SSadmin_verbs.dynamic_invoke_verb()`，
  **不要**直调 `__avd_*`（会被 `CanProcCall` 拦下并通报管理员）。
- 上传成功后**不需要回调**：目录里出现新文件，每秒 tick 的 `register_clients()` 会自动纳入传输。

## 测试方式

1. `dm.exe tgstation.dme -DCBT` ⇒ 0 errors
2. `cd tgui && ./node_modules/.bin/rspack.exe build` ⇒ compiled successfully；然后删 `tgstation.rsc` 再编 DM
3. `cd tgui && npm run tgui:tsc` ⇒ 0 errors
4. 实机：管理员面板 →「播放全局音效」⇒ 打开面板 ⇒「上传音频」选一个 `.ogg`
   （文件名需含且仅含一个 `+`，如 `测试曲目+120.ogg`）⇒ 观察就绪人数从 0/N 涨到 N/N
   ⇒ 播放按钮由灰变亮 ⇒ 点播放应有声 ⇒ **再点一次仍应立刻有声**（已缓存，无新增下载）
   ⇒ 另开一个客户端加入 ⇒ 面板里新玩家自动补传 ⇒ 看他那行进度条走满。
5. **回归（本轮修的 bug）**：放完一首 ⇒ 点「移除」把它删掉 ⇒ **再上传/点名 3 首** ⇒
   这三首应该照常开始传输（修复前会一直停在「待推」，怎么点都不动）。
   另：移除后「待推 N 份」的数字应当立刻下降，不留幽灵份。
6. **mp3 回归**：上传一个 `.mp3`（文件名同样要 `标题+节拍.mp3`）⇒ 应能入列、能传、能播。

## 维护备注

- 目录读取在本模块内自持一份精简实现（与 `admin_countdown` 同源但不跨模块调用），
  避免以后单独删改任一个模块时互相牵连。解析规则与点唱机
  （`code/datums/components/jukebox.dm`）保持一致：文件名用 `+` 分隔，第一段是显示名。
- 曲库目录是 `config/jukebox_music/sounds/`（`CONFIG_JUKEBOX_SOUNDS`）—— 属于 `config/`，
  **不进仓库**，管理员上传的音频不会出现在提交里。
- **上传体积上限是配置项，不在本模块里**：`config/config.txt` 的 `UPLOAD_LIMIT_ADMIN`
  （默认 `5242880` B = 5120 KiB = 5 MiB）。管理员传大音频被 `AllowUpload()` 拦下时改这里，
  **不要**去动 `code/modules/client/client_procs.dm`。
  改法与数值对照见交付物《上传大小限制-怎么改.md》。
