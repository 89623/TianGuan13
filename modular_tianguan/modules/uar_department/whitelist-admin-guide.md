# 白名单配置教程（管理员用）

> 面向对象：服务器管理员 / 运维
> 场景：让「团结联盟审查官（UAR Inspector）」这类职业**只有被白名单认可的人**才能玩
> 所有结论均来自本仓库源码，已逐处标注文件与行号，可复核

---

## 一、先弄清一件事（决定后面怎么做）

**本 fork（tg + Nova Sector）的白名单是「服务器级」的：它拦的是「能不能进服」，而不是「能不能选某个职业」。**

- 机制实现：`modular_nova/modules/whitelist/code/whitelist.dm`
- 拦截位置：`code/modules/admin/IsBanned.dm:58-68`（玩家连进来时判定）
- 触发加载：`code/controllers/configuration/configuration.dm:119`

⇒ 所以：
- **如果你的服务器本来就开白名单**（Nova 白名单服），那么白名单之外的人**根本进不来**，
  UAR 审查官等职业**自然就是"仅白名单玩家可玩"** —— 不需要为职业做任何额外配置。
- **如果你想在同一台服务器上，只把 UAR 这一个职业限给指定名单的玩家** ⇒ **本 fork 有现成机制，不需要新写功能**：
  **「新星（Nova Star）」体系** —— 见同目录的 **`nova-star-restriction-guide.md`**。
  （职业开关 `/datum/job/var/nova_stars_only`（`modular_nova/modules/customization/modules/jobs/_job.dm:20`）；
   判定 `SSplayer_ranks.is_nova_star()`（`player_ranks.dm:91`）；拦截点 `subsystem/job.dm:994`、`new_player.dm:185`。）
  ⚠️ 它和本文档的**服务器级白名单是两套独立系统**：前者管「能不能进服」，后者管「能不能用某个职业/物品」。

---

## 二、三个开关（分散在**三个**配置文件里，缺一不生效）

| 开关 | 写在哪 | 作用 | 源码 |
|---|---|---|---|
| `USEWHITELIST` | `config/config.txt` | **总开关**：开启后，非白名单玩家无法进服 | `code/controllers/configuration/entries/general.dm:292` |
| `SQL_ENABLED` | `config/dbconfig.txt` | 数据库总开关（用 SQL 白名单时必须开） | `code/controllers/configuration/entries/dbconfig.dm:1` |
| `SQL_WHITELIST` | `config/nova/config_nova.txt` | 名单**从数据库读**；不开则读旧版 `config/whitelist.txt` | `modular_nova/master_files/code/controllers/configuration/entries/config_entries.dm:144` |

仓库里这三行的原始形态（默认都是注释掉的）：

```ini
# config/config.txt:196
#USEWHITELIST

# config/dbconfig.txt:6
#SQL_ENABLED

# config/nova/config_nova.txt:202
#SQL_WHITELIST
```

**两种用法（二选一）：**

| 用法 | 需要打开的 | 名单存放处 |
|---|---|---|
| 旧版（简单，无需数据库） | `USEWHITELIST` | `config/whitelist.txt`，一行一个 ckey，`#` 开头为注释 |
| SQL 版（推荐，可在游戏内/机器人里改） | `USEWHITELIST` **+** `SQL_ENABLED` **+** `SQL_WHITELIST` | 数据库 `whitelist` 表 |

> ⚠️ `SQL_WHITELIST` 的官方注释原话（`config/nova/config_nova.txt:201`）：
> *"This does not replace USEWHITELIST in config.txt. Both flags must be enabled."*
> 三个开关是**且**关系；只有 `SQL_WHITELIST` 而没开 `USEWHITELIST` 时，白名单**完全不生效**。

**生效时机**：名单在**开服时**加载一次（`configuration.dm:119` 调用 `load_whitelist()`）⇒ **改完配置/直接改数据库后必须重启服务器**。
（例外见 §3：用游戏内动词或 TGS 命令加人时，是**内存+数据库同时写入，立即生效**。）

---

## 三、SQL 版：建表与加人

### 3.1 建表

建表语句已随仓库提供，直接导入即可（`SQL/nova_schema.sql:157`）：

```sql
CREATE TABLE `whitelist` (
  `ckey` VARCHAR(32) NOT NULL,
  `date_added` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_modified` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `revoked` BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (`ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
```

> 注意：`revoked = 1` 的行**不会被加载**（`whitelist.dm` 的 `load_whitelist()` 里会跳过）。

### 3.2 加人（三种方式，任选）

1. **游戏内管理动词**：管理面板 →「添加白名单」（`ADMIN_VERB add_whitelist`，源码 `whitelist.dm:66`）
   —— 输入 ckey，**立即生效**。
2. **TGS / Discord 机器人**：`whitelist <ckey>` 命令（源码 `whitelist.dm:134`，本 fork 已汉化提示）
   —— 需要 TGS 接入，**立即生效**。
3. **直接 SQL**：
   ```sql
   INSERT INTO whitelist (ckey) VALUES ('玩家的ckey')
     ON DUPLICATE KEY UPDATE revoked = 0;   -- 重新加回来会顺便解封
   ```
   方式 1、2 用的就是这条语句（`whitelist.dm:87`），**直连数据库改完需要重启**服务器。

> **管理员不会被自己关在门外**：拦截处在 `IsBanned.dm:60-66` 里对 admin 有专门分支，
> 会在日志写 `The admin [ckey] has been allowed to bypass the whitelist`。
> 也就是说 `config/admins.txt`（或 SQL 管理员表）里的人**始终能进服**，可用来自救。

---

## 四、移人（撤销白名单）

**目前没有可用的撤销动词** —— 上游把 `revoke_whitelist` 整段注释掉了
（`modular_nova/modules/whitelist/code/whitelist.dm` 末尾的 `/* TODO: Discuss this ... */`）。

所以撤销只能走 SQL：

```sql
UPDATE whitelist SET revoked = 1 WHERE ckey = '要撤销的ckey';
```

> ⚠️ **别照抄那段被注释的代码**：它写的是 `SET \`revoked\` = 0`（应为 `1`，否则等于"撤销后又把人加回来"）。
> 撤销后需要**重启服务器**（内存里的 `GLOB.whitelist` 是开服时加载的）。
>
> 旧版（txt 名单）撤销更直接：编辑 `config/whitelist.txt` 删掉那一行 → 重启。

---

## 五、玩家看到什么（务必改掉默认文案）

非白名单玩家只看到一行提示，内容取自：

```ini
# config/nova/config_nova.txt:207
MISSING_WHITELIST_MESSAGE "<默认文案：提示本服需要白名单，并指向官方服务器的 Discord 申请渠道>"
```

**默认文案是 Nova 官方服务器的申请指引（含其 Discord 邀请链接）** —— 自建服一定要改成自己的申请渠道，例如：

```ini
MISSING_WHITELIST_MESSAGE "<默认文案：提示本服需要白名单，并指向官方服务器的 Discord 申请渠道>"
```

> 开头的 `\n` 是约定写法（让提示在 BYOND 窗口里另起一行），保留它更好看。
> 改完**需要重启**才生效。

---

## 六、如果你要的是「只限制 UAR 这一个职业」

三条路线，按代价从低到高：

### A. 开服务器级白名单（唯一现成机制，推荐）
只要服务器本身就是白名单服（§二），所有职业（含 UAR 审查官）就都只对白名单玩家开放 —— **零额外开发**。
适合：你的社区本来就是"新星（Nova）白名单"模式。

### B. 用现有的「游玩门槛」代替（已是老手限定）
UAR 审查官**已经配置**了与「纳米传讯顾问」逐字段一致的门槛（见 `uar_department/readme.md` 的「游玩门槛」一节）：

- `exp_requirements = 600`（600 分钟本部门/相关岗位时长）
- `minimal_player_age = 14`（账号年龄 14 天）
- `config_tag = "UAR_INSPECTOR"`（可在 `config/jobconfig.toml` 里单独调）

这不是白名单，但能起"只有熟手能选"的作用；**门槛是服务器侧配置**，改法与 6 个「改了不生效」的坑都写在那个 readme 里。

### C. 用「新星（Nova Star）」体系（**推荐，已有现成机制**）
**不需要新写功能** —— 本 fork 自带职业级名单限制，详见同目录 **`nova-star-restriction-guide.md`**：
职业侧开关 `nova_stars_only`（本模块**已设为 TRUE**），服务器侧总开关 `ENABLE_NOVA_STAR_RESTRICTIONS`，
名单由管理面板「管理玩家等级」维护（或 `config/nova/nova_star_players.txt`）。

> 备注：若确实需要**只针对本职业**、且**不启用全局新星开关**（避免连带限制老玩家特质/种族/装备），
> 可另做一份模块级 ckey 名单；本仓库的现成先例是义体的 `ckey_whitelist`
> （`modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm:78,270`）。
> 需要的话告诉我，我按模块规范实现。

---

## 七、常见坑速查

| # | 现象 | 原因 |
|---|---|---|
| 1 | 开了 `SQL_WHITELIST` 却毫无效果 | 忘了开 `USEWHITELIST`（总开关在 `config.txt`，不是同一个文件） |
| 2 | 游戏内找不到「添加白名单」动词 | 三个开关没齐 —— 动词的存在性检查要求三个全开（`whitelist.dm:94`） |
| 3 | **所有人都进不来** | 名单**为空**时 `check_whitelist()` 对任何人返回 FALSE（`whitelist.dm:56-60`）⇒ 先把自己加进 `config/admins.txt` 或名单再开服 |
| 4 | 数据库连不上 | 启动时会**自动回落到旧版 `config/whitelist.txt`**，并在日志里写一行提示（`whitelist.dm:22-26`） |
| 5 | 改了数据库却没变化 | 名单只在开服时加载一次；用动词/TGS 命令才是立即生效 |
| 6 | 撤销找不到入口 | 撤销动词被上游注释掉了（§四），只能 SQL |
| 7 | 以为只限制了某个职业 | 白名单只影响**进服**，不影响选职业（§一） |
| 8 | 玩家看到的是 Nova 官方的 Discord 指引 | 没改 `MISSING_WHITELIST_MESSAGE`（§五） |

---

## 八、管理员自检清单

1. `config/config.txt` 的 `USEWHITELIST` 已启用（+ 用 SQL 时 `dbconfig.txt` 的 `SQL_ENABLED`、`config_nova.txt` 的 `SQL_WHITELIST`）；
2. 自己的 ckey 在 `config/admins.txt`（或已在名单里）—— **不会被锁在外面**；
3. 名单里至少有一个测试账号；
4. `MISSING_WHITELIST_MESSAGE` 已换成自己的申请渠道；
5. 重启服务器；
6. 用**未加白名单**的账号连接 ⇒ 应被拒绝，并显示你设置的文案（`IsBanned.dm:68`）；
7. 用**已加白名单**的账号连接 ⇒ 正常进入，且能在职业偏好页看到并选择「团结联盟审查官」；
8. 日志核对：被拒时 `log_access` 会写 `Failed Login: [ckey] - Not on whitelist`；管理员绕过会写 `allowed to bypass the whitelist`。
