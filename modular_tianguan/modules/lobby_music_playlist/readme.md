https://github.com/89623/TianGuan13/pull/<!--PR 编号-->

## 首页 BGM 随机轮播（大厅音乐播完自动切下一首）

模块 ID：LOBBY_MUSIC_PLAYLIST

### 说明：

原版大厅音乐只在客户端登录时播**一首就结束**（`code/game/sound/sound.dm` 的
`/client/proc/playtitlemusic()` 里那次 `SEND_SOUND` 用的是 `repeat = 0`）。
本模块让首页 BGM **一首播完自动随机切下一首**，形成轮播：

- **第一首**沿用 `SSticker` 已随机挑好、并已排除"上回合曲目"的那首（保留原行为），并计入记忆窗；
- 之后每首按**实际时长**切歌：时长取模块的 `tianguan_lobby_track_length()`（先查时长兜底表，
  再问 `SSsounds.get_sound_length()`），`sleep(时长)` 到时再取下一首；
- **选曲**＝洗牌队列 + 记忆窗（详见下方专节）：**任意连续 N 次播放互不相同**（N = 池大小，
  即"一轮内不重复"），同一首两次之间至少相隔（池大小-1）次播放、绝不回跳；
- **终止条件**：客户端断开 / 已进场（不再是大厅，以 mob 类型判定）/ 服务器关了 `disallow_title_music`
  / 玩家把大厅音量调为 0 —— 任一满足即停止；停止时才清本频道残留（若循环已被新一次调用取代则不清理，
  以免误掐新一代刚播的曲子）；
- 曲目池沿用与 `ticker.Initialize()` 相同的命名约定：目录 `config/title_music/sounds/`，
  仅收常规曲目（不含 `rare` 与地图专属），跳过 `exclude`；池为空时回退 `strings/round_start_sounds.txt`。

### 核心文件 / Proc 改动：

- `code/game/sound/sound.dm` —— `/client/proc/playtitlemusic()` 内 3 行钩子（`TIANGUAN EDIT ADDITION`）：
  先调用模块的 `tianguan_lobby_playlist_start(music_volume)`，返回 TRUE 即接管并 `return`；
  返回 FALSE（模块不在 / 曲目池为空）则**原样执行下游逻辑** —— 行为与改动前完全一致。
- **为什么不能完全模块化**：播放动作就在该 proc 里那一次 `SEND_SOUND`，且 `/client` 上
  `playtitlemusic()` 全仓仅此一处定义，DM 中同 proc 重复定义即 `duplicate definition` 编译报错，
  故只能做最小钩子。

### 模块化覆盖：

- 给 `/client` 新增 3 个模块私有 var（代际号 / 洗牌队列 / 记忆窗）与 2 个模块 proc
  （`tianguan_lobby_next_track`、`tianguan_lobby_track_length`），另有 1 个全局 proc（曲目池）
  与 3 个 `GLOBAL_*_INIT`（池缓存 / rsc 字面量清单 / 时长兜底表）—— **不改动任何既有类型的既有 var**

### Defines：

- 无（记忆窗容量按 `池大小-1` 动态取，不需要常量）

### 本模块目录外的依赖文件：

- 无（仅需 `tgstation.dme` 一行 include：`modular_tianguan\modules\lobby_music_playlist\code\lobby_music_playlist.dm`）
- 复用到的既有机制：`SSsounds.get_sound_length()`（常规编码的实际时长，单位为分秒）、`CHANNEL_LOBBYMUSIC`、
  `SSticker.login_music`、`CONFIG_GET(flag/disallow_title_music)`、
  `/datum/preference/numeric/volume/sound_lobby_volume`

### 测试方式：

1. 编译：`dm.exe tgstation.dme` ⇒ `0 errors`；
2. 游戏内：连服停在大厅，等第一首播完 ⇒ 应自动切到另一首并持续轮播；记下顺序核对：
   **队列内无重复、任意连续 5 次播放互不相同**（含首曲）；
3. 切歌边界：进场开局后应立即停止；把大厅音量调 0 或在设置里关掉大厅音乐后不再播放；
4. 回退验证：把模块 proc 临时改为 `return FALSE`（或移除 include）⇒ 恢复"只播一首"的原行为。

### 致谢：

- 需求与验收：用户

### ⚠️ 加新曲子时的坑（实测）

`login_music` 是**运行期字符串路径**，而 BYOND 只把「**编译期出现过字面量**」的资源打进 `.rsc`。
仓库自带的 `sound/music/lobby_music/` 里 `title0.ogg` 与 `title1.mod` 全仓无字面量引用，
实测 `grep tgstation.rsc` 命中为 **0** ⇒ 随机挑到这两首时 `SEND_SOUND` **静默失败**（客户端没有该文件）。

⇒ 本模块用 `GLOB.tianguan_lobby_music_rsc_keep`（字面量清单）兜住这一点，改后 5 首全部进包。
**以后往 `config/title_music/sounds/` 或本目录加曲子，请把它同样加进那份字面量清单**，
否则新曲子会随机出现"有时有声音、有时没声音"的现象（且不报任何错）。

### 选曲算法：洗牌队列 + 记忆窗（2026-10 实测定稿）

- **洗牌队列（shuffle bag）**：整池 `shuffle()` 随机排队、逐首消费 ⇒ **队列本身一轮内不重复**；
- **记忆窗（容量 = 池大小-1）**：刚从队里取出的曲子若落在窗内，就与"队内第一首不在窗内的"交换
  ⇒ **跨轮（含首曲）也不会回跳 A→X→A**；容量严格小于池大小 ⇒ 窗外必然留有可换的曲子，永远换得动；
- **实测**（算法等价移植，30 种子 × 4 千次抽取，池 2～30 首）：**同曲最小间隔 = 池大小、
  任意连续 N 次播放互不相同（N = 池大小）、违规窗口 = 0** ⇒ 5 首池即"一轮 5 首各一次、绝不回跳"。
  对照（同尺子量）：纯洗牌队列（无记忆窗）最小间隔低到 2（即 A→X→A）✗；
  记忆窗若封顶 4，则池 6 首有 71142 个、池 8 首有 95678 个"连续 N 次内有重复"的违规窗口 ✗。

### 三个实测坑（务必记住）

1. **服务器侧开关（不在本仓库动配置）**：`config/game_options.txt` 的 `DISALLOW_TITLE_MUSIC` 上游默认**打开**
   （= 禁用大厅音乐），未注释时 `playtitlemusic()` 的整体判定会被跳过 ⇒ **大厅自始至终没声音、且不报任何错**。
   ⇒ **改法：由服务器管理员把那一行注释掉**（各服用的是自己那份 config，改仓库也不会生效；
   按「能不动的不动」原则，本模块不把配置页改动带进仓库）。
2. **资源包（.rsc）**：`login_music` 是运行期字符串路径，而 BYOND 只把「编译期出现过字面量」的资源打进 `.rsc`；
   仓库自带的 `title0.ogg` 与 `title1.mod` 全仓无字面量引用 ⇒ 曾随机挑到它们就**静默无声**。
   本模块用 `GLOB.tianguan_lobby_music_rsc_keep` 兜住；**以后加曲子请把新曲子也加进那份清单**。
3. **时长兜底只能写成"取不到时长时"**：不要写 `len < 5 SECONDS` 这类"最短时长"判断 ——
   短曲子（铃声 / 音效型 BGM）会被误判成兜底值 2 分钟 ⇒ 表现为"**播一首就停了**"（实测踩过）。

### 第 4 个坑：tracker 模块（.mod 等）能播但测不出时长

- BYOND 客户端**支持** tracker 模块（见 `code/controllers/subsystem/sounds.dm:40` 的 `byond_sound_formats`：
  `mod` / `it` / `s3m` / `xm` 均为 `TRUE`）⇒ 这类曲子**可以进轮播**，不必剔除；
- 但**时长探测库读不了**：`SSsounds.get_sound_length()` 底层是 rust-g 的 `sound_len`，用的是
  **symphonia**（只认 ogg/wav/mp3/flac/aac/mp4 等常规编码）⇒ 对 `.mod` 返回**错误字符串** ⇒ DM 侧
  `text2num` 得到 `null` ⇒ 被判定为"取不到时长"，落到兜底值 ⇒ **提前切歌**。
  实测：`title1.mod` 真时长 **200.0 秒**，却按兜底 120 秒切 ⇒ 提前 80 秒 ✗。
- ⇒ 解法是**时长兜底表** `GLOB.tianguan_lobby_music_length_override`（模块内，值为分秒）：

```dm
GLOBAL_LIST_INIT(tianguan_lobby_music_length_override, list(
    "sound/music/lobby_music/title1.mod" = 2000,   // 200.0 秒
))
```

**核算方法（MOD）**：1084 字节头 + 每个 pattern 1024 字节；读偏移 950 的歌曲长度与 952 起的 order 表，
得到用到的 pattern 数；再按 **演出表逐行累计**：每行耗时 = `speed × (2.5 / tempo)` 秒（默认 speed 6 / tempo 125，
遇到 `Fxx` 效果就更新 speed/tempo），把所有 order 的 64 行加起来即为时长。`title1.mod` 算得 4480 行 = 200.0 秒。

**新增曲子时**：ogg/wav 无需管（自动测长）；若是 tracker 模块，用上面的方法核算后加进兜底表即可。
