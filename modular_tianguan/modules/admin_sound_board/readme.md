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
| `code/modules/admin/verbs/playsound.dm` | **改核心**（见下） |
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

## 维护备注

- 目录读取在本模块内自持一份精简实现（与 `admin_countdown` 同源但不跨模块调用），
  避免以后单独删改任一个模块时互相牵连。解析规则与点唱机
  （`code/datums/components/jukebox.dm`）保持一致：文件名用 `+` 分隔，第一段是显示名。
- 曲库目录是 `config/jukebox_music/sounds/`（`CONFIG_JUKEBOX_SOUNDS`）—— 属于 `config/`，
  **不进仓库**，管理员上传的音频不会出现在提交里。
