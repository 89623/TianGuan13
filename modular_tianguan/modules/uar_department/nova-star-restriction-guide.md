# 「新星（Nova Star）」限定配置教程

> 面向对象：服务器管理员 / 运维
> 目的：让**团结联盟审查官（UAR Inspector）**这类职业**只有「新星」玩家能选**
> 前提：本服务器**不是**白名单服（所以不能用"服务器级白名单"绕过去）—— 本教程用的是**职业级**限制，只影响指定职业
> 所有结论均取自本仓库源码并标注了文件与行号，可复核

---

## 一、一句话结论

本 fork 自带「新星（Nova Star）」体系：**每个职业/物品有一个 `nova_stars_only` 开关**，
配合**服务器总开关**和**一份 ckey 名单**，就能做到"仅名单内玩家可用"。

三件事，缺一不可：

| # | 位置 | 内容 | 现状 |
|---|---|---|---|
| 1 | **代码**：职业定义 | `/datum/job/uar_inspector` 设 `nova_stars_only = TRUE` | ✅ **已为你配好**（`modular_tianguan/modules/uar_department/code/uar_department.dm`，零核心改动） |
| 2 | **配置**：`config/nova/config_nova.txt` | `ENABLE_NOVA_STAR_RESTRICTIONS 1` | ❗**需要你开**（源码默认 `FALSE`，见 `config_entries.dm:177-178`） |
| 3 | **名单** | 游戏内管理面板加人（推荐），或 `config/nova/nova_star_players.txt` | ❗**需要你加人** |

判定链（源码）：

```dm
// 全局开关
code/controllers/configuration/configuration.dm:125
    GLOB.nova_star_restrictions = CONFIG_GET(flag/enable_nova_star_restrictions)

// 谁算「新星」
modular_nova/modules/player_ranks/code/subsystem/player_ranks.dm:91
    /datum/controller/subsystem/player_ranks/proc/is_nova_star(client/user, admin_bypass = TRUE)
        if(GLOB.nova_star_list[user.ckey])  return TRUE    // 名单命中
        if(admin_bypass && is_admin(user))  return TRUE    // 管理员自动放行
        return FALSE

// 拦截点（两处，和物种限制同一套位置）
code/controllers/subsystem/job.dm:994
    if(GLOB.nova_star_restrictions && possible_job.nova_stars_only && !SSplayer_ranks.is_nova_star(player.client))
        return JOB_NOT_NOVA_STAR
code/modules/mob/dead/new_player/new_player.dm:185
    if(GLOB.nova_star_restrictions && job.nova_stars_only && !SSplayer_ranks.is_nova_star(client))
        return JOB_NOT_NOVA_STAR
```

玩家侧提示（本 fork 已汉化，见 `strings/i18n/zh-Hans/_root.json:403`）：

> **您必须是诺瓦星才能加入为 团结联盟审查官。**

---

## 二、第一步：打开服务器总开关

编辑 `config/nova/config_nova.txt`，找到这一行（约 233 行，默认被注释）：

```ini
## Uncomment to disable the Star rank restrictions
#ENABLE_NOVA_STAR_RESTRICTIONS 0
```

改成：

```ini
ENABLE_NOVA_STAR_RESTRICTIONS 1
```

> ⚠️ **注意：仓库里这句注释是过时写反的**（写着"取消注释以**禁用**"）。
> 事实：该配置项源码默认值就是 `FALSE`（`config_entries.dm:178`），
> **必须显式写成 `1` 才生效**；写 `0` 或保持注释 = 限制关闭。

**改完必须重启服务器。**

### 打开它的连带影响（务必知情）

这个开关是**全局**的，不只管职业。仓库里所有带 `nova_stars_only` 的**内容**都会一起受限：

| 受影响内容 | 源码位置 |
|---|---|
| 职业（含本 UAR 审查官） | `code/controllers/subsystem/job.dm:994`、`new_player.dm:185` |
| 老玩家专属特质（quirks） | `code/modules/client/preferences/middleware/quirks.dm:120,165` |
| 老玩家专属种族（species） | `code/modules/client/preferences/species.dm:63` |
| 装备栏物品（loadout） | `code/modules/loadout/loadout_items.dm:375` |
| 职业管理控制台里也显示该限制 | `code/modules/modular_computers/file_system/programs/jobmanagement.dm:39` |

⇒ 如果你的服**不希望**这些老玩家内容也变成"新星限定"，可选的替代做法见 **§五**。

---

## 三、第二步：把玩家加进「新星」名单

### 方式 A（推荐）：游戏内管理面板

**管理面板 →「管理玩家等级」**（`ADMIN_VERB manage_player_ranks`，需要 `R_PERMISSIONS` 权限，源码
`modular_nova/modules/admin/code/player_ranks.dm:4`）→ 选分组（`nova_star` / `donator` / `mentor`）→ 输入玩家 ckey。

- 添加后**立即生效**（写入内存名单）；
- 走 SQL 的服会同时落库；旧版（txt）会同时写进名单文件（`text2file`，`_player_rank_controller.dm:59`）。

### 方式 B：旧版名单文件（无数据库 / 未开 SQL 时）

文件路径（由控制器写死，`nova_star_controller.dm:12`）：

```
config/nova/nova_star_players.txt
```

**格式：一行一个 ckey**（例如 `mh516`），保存后**重启**服务器。
> 本服务器若未开 `SQL_ENABLED`，系统会自动使用这套旧版名单
> （`config_nova.txt:165` 原话："These flags are automatically enabled if SQL_ENABLED isn't"）。

### 方式 C：SQL 版

服务器启用 SQL 玩家等级系统后，名单存库里（可用「管理玩家等级」动词增删，或参考
`ADMIN_VERB migrate_player_ranks`（`player_ranks.dm:81`）把旧名单迁移过去）。

### ★ 管理员永远豁免

`is_nova_star()` 里对管理员有 `admin_bypass`（默认 TRUE）⇒ **管理员自己始终能选该职业**。
⇒ **测试时务必用非管理员的普通账号**，否则会以为"没生效"。

---

## 四、第三步：验证

1. 重启服务器，确认 `ENABLE_NOVA_STAR_RESTRICTIONS 1` 已生效；
2. 用**普通账号（不在名单）**连接 ⇒ 在职业偏好页选「团结联盟审查官」时，
   应看到「**您必须是诺瓦星才能加入为 团结联盟审查官。**」，且无法入服该职业；
3. 用管理面板把自己/测试小号加进 `nova_star` 组 ⇒ **重新进服**后再选 ⇒ 应可正常选择并入职；
4. 观察是否**误伤**：让普通玩家看看老玩家特质/种族/装备栏是否也出现了"新星"限制（若不该受限，见 §五）。

---

## 五、如果你只想限制 UAR，不想动其他老玩家内容

`ENABLE_NOVA_STAR_RESTRICTIONS` 是全局的 ⇒ 三个替代方案：

1. **接受全局**（最简单）：如果本服本来就打算做"新星优先"，直接开。**推荐**。
2. **改用游玩门槛**：UAR 审查官已配好 `exp_requirements = 600` + `minimal_player_age = 14`（见
   `uar_department/readme.md` 的「游玩门槛」一节）——不是名单制，但同样能挡住新玩家；**不影响其他系统**。
3. **自建职业级 ckey 名单**（不影响全局）：照抄本仓库现有先例（义体的 `ckey_whitelist`，
   `.../limbs_and_markings.dm:270`），在模块里加一份名单 + 在 `has_banned_species()` 同一位置判定。
   **需要我实现的话说一声**（按模块规范做，不动核心共享文件）。

---

## 六、常见坑速查

| # | 现象 | 原因 |
|---|---|---|
| 1 | 开了 `ENABLE_NOVA_STAR_RESTRICTIONS` 也没限制 | 职业那行 `nova_stars_only = TRUE` 没写（本模块**已写**，若你回退过要补回） |
| 2 | 忘了开总开关 | 源码默认是 `FALSE`（`config_entries.dm:178`）；仓库那句"取消注释以禁用"的注释是**写反的** |
| 3 | 管理员测试"没生效" | 管理员被 `admin_bypass` 豁免（`player_ranks.dm:98`）⇒ 用普通账号测 |
| 4 | 加完人还是不能选 | 名单是**进服时**读取的 ⇒ 让玩家**重新连接**；txt 名单改动则需**重启** |
| 5 | 老玩家特质/种族/装备也受限了 | 全局开关的连带影响（§二表格），确认是否可接受 |
| 6 | 数据库连不上 | 会自动回落到旧版 txt 名单（日志有 `Reverting to legacy system` 提示） |
| 7 | 玩家看不到中文提示 | 提示走 i18n（`_root.c986f9daa90532a6`），客户端语言为中文时显示「您必须是诺瓦星才能加入为 …」 |
