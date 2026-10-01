https://github.com/89623/TianGuan13/pull/<!--PR 编号-->

# 团结联盟（UAR）部门 + 团结联盟审查官 (UAR_DEPARTMENT)

模块 ID：`UAR_DEPARTMENT`

### 说明：

新增一个**玩家可选部门**「团结联盟」（英文简称 `uar`），部门内新增**一个职业**「团结联盟审查官」
（英文职业名 `Alliance Inspector`），部门主题色为团结联盟深红 `#8b0000`。

部门与职业会同时出现在两处玩家界面：

| 界面 | 入口 | 本模块要做的事 |
| --- | --- | --- |
| 加入菜单（`JobSelection`） | 大厅「加入游戏」/ 观察者点加入 → `GLOB.latejoin_menu` | **不用改**：菜单遍历 `SSjob.joinable_departments` 自动长出新部门，颜色取部门 datun 的 `ui_color` |
| 角色职业偏好（`PreferencesMenu` → Jobs 页） | 角色设置 → 职业 | **必须改**：该页的部门分栏是**硬编码**的，每个部门写一行 `<Department department="…" />` |

### 核心文件 / Proc 改动：

只有两个上游文件被动过，共 **+28 行 / -0 行**，全部带 `TIANGUAN EDIT` 标记：

1. **`code/__DEFINES/jobs.dm`（+15 行）** —— 4 处编辑块：
   - 职业名 `#define JOB_UAR_INSPECTOR "Alliance Inspector"`；
   - 排序序号 `#define JOB_DISPLAY_ORDER_UAR_INSPECTOR 1`；
   - 部门位标志 `#define DEPARTMENT_BITFLAG_UAR (1<<11)` 与部门显示名 `#define DEPARTMENT_UAR "Union of Allied Republics"`；
   - `DEFINE_BITFIELD(departments_bitflags, …)` 里补一行 `"UAR"`（只影响管理员 VV 的可读性）。

   **为什么不能模块化**：`/datum/job` 的 `title` 用的是 `JOB_*` 常量而非字面量，仓库所有职业/部门名都定义在这个文件里；
   更重要的是 **TGUI 的中文目录只从这个文件抽名字**——`tools/i18n/tgui-catalog.mjs` 的 `DM_LABEL_SOURCES`
   把 `code/__DEFINES/jobs.dm` 里所有 `#define X "…"` 收进 TGUI 目录（第 783 行），
   TS 运行时的渲染层再按英文原文反查 `strings/i18n/zh-Hans/tgui.json` 把显示翻成中文。
   定义放到模块文件里 = 名字进不了目录 = 两个菜单里永远显示英文。

2. **`tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/JobsPage.tsx`（+12 行）** —— 在第三列
   （安保 / 医疗 之后）加一栏 `<Department department="Union of Allied Republics" />`。

   **为什么不能模块化**：这一页不接受「部门清单」数据，栏位是写死的 JSX。字符串必须与
   `DEPARTMENT_UAR` **逐字相同**（它是查 `data.jobs.departments[name]` 的键）。
   留空不写不会报错 —— `Department` 组件查不到就 `return null`，**该职业在偏好菜单里整条消失**（静默失败）。

> ⚠️ 改名要同时改两处：`code/__DEFINES/jobs.dm` 的 `DEPARTMENT_UAR` 与 `JobsPage.tsx` 的那一行字符串。

### 模块化覆盖：

- 无（没有走 dme 换文件，也没有遮蔽任何上游 proc）。

### Defines：

- `UAR_DEPARTMENT_COLOR`（`#8b0000`）—— 模块内定义，只在本模块的文件里用；部门 datun 的 `ui_color` 与
  ID 卡 trim 的 `department_color` 都取它。颜色沿用传真机模块的 `uar_darkred` 按钮档与 `themes/uar.scss` 的同一色系。

### 本模块目录外的依赖文件：

- `strings/i18n/zh-Hans/tgui.json`（+2 行）：`"Union of Allied Republics": "团结联盟"`、
  `"Alliance Inspector": "团结联盟审查官"`。这是 i18n 的正常流程（抽取器会把新 `#define` 收进目录，
  用户已有译文最优先、只合并不裁剪），不是绕过机制。
- `tgstation.dme`（+1 行 include）。

### 部门/职业的所有可选项（新增部门时照这个表对照）

**只允许人类角色可选**：job datum 上写 `species_whitelist = list(SPECIES_HUMAN = 1)`（`SPECIES_HUMAN` = `"human"`）。
判定在 `modular_nova/modules/customization/modules/jobs/_job.dm:34` 的 `has_banned_species()`：
白名单里查不到该物种 id 即判为不可选；消费点是 `SSjob`（`subsystem/job.dm:1006`）与 `new_player.dm:187`
—— **职业偏好菜单与真正入服两条路都会拦**。注意必须写成**关联表** `list(SPECIES_HUMAN = 1)`：
`has_banned_species()` 是按物种 id 查键，写成 plain `list(SPECIES_HUMAN)` 会把所有物种（含人类）一起拦掉。

| 字段 | 本模块取值 | 不写会怎样 |
| --- | --- | --- |
| `department_name` | `DEPARTMENT_UAR` | 显示为 `No Department` |
| `department_bitflags` | `(1<<11)`（`1<<0..10` 已被上游/Nova 占用） | 管理员 VV、部分按部门判定的逻辑失效 |
| `display_order` | `9`（1..8、10 已占用） | **`department_display_order` 单测失败**（要求非 0 且唯一） |
| `ui_color` | `#8b0000` | 取基类默认紫色 `#9689db` |
| `department_head` | 不设 | 不设 = 职业名在偏好菜单不加粗（上游 `assistant` 部门同样不设）；设了要指向一个真实 `/datum/job` |
| `department_experience_type` | 不设 | 不设 = 本部门职业按各自 `exp_granted_type` 累计时长 |
| `primary_work_area` / `department_access` / `associated_cargo_groups` / `department_delivery_areas` | 不设 | 只影响「部门订单」PDA 程序、心情、RTD 等周边功能，全部有 null 保护 |
| `nation_prefixes` | 给了 5 个前缀 | 分离主义者给部门随机起名时 `pick(空表)` 会 runtime |

职业侧关键字段：`faction = FACTION_STATION`（否则偏好菜单拒绝写入）、`description`（不写会被
`get_constant_data()` 判为无效并跳过）、`tgui_icon`（`job_icons` 单测要求带 `JOB_CREW_MANIFEST` 的职业必须有）。

### 换美术（现在是零新美术的测试态）

- ID 卡徽记：现在复用 `trim_assistant`（`icons/obj/card.dmi`）与 `SECHUD_ASSISTANT` 的 HUD 图标。
  换成专属徽记 = 模块自带一份 dmi，同时提供 `trim_<x>` / `department` / `departmenthead` / `subdepartment`
  四个状态（`update_overlays()` 从 `trim_icon` 那一份文件取全部图层，缺任一状态整张卡无叠层），
  再把 trim 的 `trim_state` / `trim_icon` / `sechud_icon` / `sechud_icon_state` 指过去。
- 衣服：现在用现成的黑色西装 + 皮鞋 + 通用 PDA + 普通耳机。换专属服装不需要碰本模块以外的东西。

### 游玩门槛（服务器侧怎么调，以及为什么改仓库的 config 常常不生效）

审查官的门槛**与纳米传讯顾问（NTC）逐字段一致**，写在 job datum 里：

```dm
minimal_player_age = 14                  // 账号年龄（天）
exp_requirements = 600                   // 游玩时长门槛（**分钟** = 10 小时）
exp_required_type = EXP_TYPE_CREW        // 时长桶（总 CREW 时长）
exp_required_type_department = EXP_TYPE_COMMAND
```

**这三个值只是"声明"，是否真的拦人由服务器自己的 config 决定** —— 所以「改了仓库里的 config 却没用」是正常的：
仓库里的 `config/` 只是模板，跑起来的服务器用的是它自己那份。

| 开关（服务器 `config/config.txt`） | 作用 |
|---|---|
| `USE_EXP_TRACKING` | **总闸**：在数据库里统计游玩时长。不开 ⇒ 所有时长门槛失效 |
| `USE_EXP_RESTRICTIONS_HEADS` | 本职业走的是"部门桶"分支（因为有 `exp_required_type_department`）⇒ **要开这个** |
| `USE_EXP_RESTRICTIONS_OTHER` | 只影响走 `exp_required_type`（普通桶）的职业 |
| `USE_EXP_RESTRICTIONS_HEADS_HOURS 3` | 一旦设置，会**覆盖所有**带部门桶职业的要求（小时 ×60），datum 里的数字就不起作用了 |
| `USE_EXP_RESTRICTIONS_HEADS_DEPARTMENT` | 把统计桶换成"本职部门时长"，而不是 CREW 总时长 |
| `USE_EXP_RESTRICTIONS_ADMIN_BYPASS` | 管理员无视门槛（配合 `DB_FLAG_EXEMPT` 也可豁免单人） |

**不改仓库也能改数字**：服务器的 `config/jobconfig.toml` 里按 `config_tag` 建一段（我们的是 `UAR_INSPECTOR`）：

```toml
[UAR_INSPECTOR]
"Playtime Requirements" = 600   # 分钟
"Required Account Age" = 14     # 天
```

（同一文件里的 `[CAPTAIN]` 段就是这个写法的现成例子。）

**想完全不卡人**：服务器侧不开上面那两个开关即可；或把 job datum 里那三行 exp_ 字段删掉（`minimal_player_age` 同理）。
`minimal_player_age` 的消费点在 `code/modules/jobs/job_types/_job.dm:42`（需 `use_age_restriction_for_jobs` + 数据库）；
时长门槛的判定链在 `code/modules/jobs/job_exp.dm`（`IS_XP_LOCKED` / `required_playtime_remaining`）。

**⚠️ "改了却不生效"的 6 个已知坑**（全部读自源码，不是猜的）：

| # | 坑 | 依据 / 怎么判断 |
|---|---|---|
| 1 | 服务器没开 `USE_EXP_TRACKING`，或**数据库连不上** | `job_exp.dm:required_playtime_remaining()` 里两处 early-return ⇒ 门槛恒为 0，数字改多少都没用 |
| 2 | 服务器没开 `USE_EXP_RESTRICTIONS_HEADS` | `IS_XP_LOCKED` 对"部门桶"职业要求这个开关（我们就是这个桶）；不开 = 压根不拦人 |
| 3 | 服务器设了 `USE_EXP_RESTRICTIONS_HEADS_HOURS` | `get_exp_req_amount()` 直接 `return 小时×60` ⇒ **覆盖所有**部门桶职业的数字，datum 与 jobconfig.toml 都白改 |
| 4 | 服务器**没有** `jobconfig.toml` | `validate_job_config()` 会置 `SSjob.legacy_mode = TRUE` ⇒ 改 TOML 完全无效，改走 `jobs.txt`；而 `legacy_load()` **只读人数**，不读时长 |
| 5 | TOML 里**没有** `[UAR_INSPECTOR]` 段 | 加载器 `if(!job_config[job_key]) continue`，并在管理端弹「…(with config key UAR_INSPECTOR) is missing from jobconfig.toml! Using codebase defaults.」⇒ **看到这条就是没生效** |
| 6 | 键是注释掉的（`# "Playtime Requirements" = 600`） | 上游生成 TOML 时默认全部注释；源码注释原话：*"Having comments mean that we allow server operators to defer to codebase standards … They must uncomment to override the codebase default."* ⇒ **必须去掉 `#` 才算覆盖** |

**改完必须重启**：`jobconfig.toml` 只在启动时读（调用点：`configuration.dm:117` 与 `subsystem/job.dm:99`）。
管理端 Server 页的 **`生成职位配置`** 动词只是把"当前生效值"导出一份给你下载，**不重载运行时值**。

**怎么确认生效（由弱到强）**：
1. 启动日志的 config 校验段出现 `jobconfig.toml not found, falling back to legacy mode (using jobs.txt)` ⇒ 命中坑 4；
2. 管理端是否弹 `… is missing from jobconfig.toml! Using codebase defaults.` ⇒ 弹了就是坑 5；
3. 拿一个时长不够的小号去选这个职业：加入菜单会显示"还差多少分钟" ⇒ 说明门槛真的在拦人。

### 测试方式：

1. **编译**：`dm.exe tgstation.dme`（正在跑服时 `tgstation.rsc` 被锁，改用 `tgstation.dme` 的副本编译）。
2. **无头探针**（不进游戏就能验数据）：复制一份 `tgstation.dme` → 追加探针 → 编译 → `dreamdaemon <产物>.dmb -trusted -port 1339 -log data/x.log` → 读日志里的 `RESULT k=v`。
   现成脚本：`byond-ss13-server` 技能的 `scripts/dm_headless_probe.py`。**要断言的两组不变量**：
   - **注册面**：`SSjob.joinable_departments_by_type[/datum/job_department/uar]` 存在且 `ui_color == "#8b0000"`、
     `display_order` 非 0；`/datum/job/uar_inspector` 在 `SSjob.joinable_occupations` 里且
     `departments_bitflags & DEPARTMENT_BITFLAG_UAR` 为真、`display_order_with_department() == 9001`。
   - **两个单测的断言**（本地开服也会自动跑，但探针能提前抓）：遍历 `joinable_occupations` 求
     `display_order_with_department()` 不得重复；遍历 `joinable_departments` 求 `display_order` 非 0 且不得重复。
   - **界面 payload**：`new /datum/preference_middleware/jobs().get_constant_data()` 里
     `departments["Union of Allied Republics"]["color"] == "#8b0000"`、
     `jobs["Alliance Inspector"]["department"] == "Union of Allied Republics"` —— 这是角色偏好菜单真正收到的东西。
3. **游戏内**：
   - 开局大厅 →「加入游戏」→ 加入菜单底部应出现**团结联盟**一栏（深红列头），栏内一条「团结联盟审查官」；
   - 角色设置 → 职业 → 第三列安保/医疗之后应出现**团结联盟**一栏，点该职业可设 Off/Low/Med/High；
   - 选上后加入 → 拿到 ID 卡（卡面 assignment = 团结联盟审查官、部门色块 = 深红）与 PDA。
4. **改了名字/颜色后要重跑的三件事**：`tgui` 的 i18n 抽取 + 打包（`tools/build/build.sh tgui` 或
   `node tools/i18n/tgui-catalog.mjs extract && cd tgui && ./node_modules/.bin/rspack build`）→ 重编 DM → 重启服务。
   **顺序不能反**：TGUI 是资源，先进 `.rsc` 再起服才能在游戏里看到。

### 已知取舍（供维护者判断是否接受）：

- 深红 `#8b0000` 在**加入菜单**的岗位按钮上是「深红底 + 近黑字」：`JobSelection.tsx` 用
  `Color.fromHex(color).darken(10)` 做底、`.darken(90)` 做字，实测对比度约 **1.84:1**（上游最深的部门
  安保 `#d92626` 是 3.39:1，也已经偏低）。想要更易读就把 `UAR_DEPARTMENT_COLOR` 改亮一档
  （`#a00000` = 2.14:1、`#b00c28` = 2.45:1）。
- 本职业在**角色偏好菜单**的行底色走 `colors.fg()`（亮度 +5），深红行 ≈ `#a40000`，黑字对比约 2.58:1。
- 地图上没有 `/obj/effect/landmark/start/Alliance Inspector`，所以落点会走晚到落点（到达大厅），
  并在 `log_mapping` 里留一条「couldn't find a round start spawn point」——想定死落点就在地图上加该 landmark。

### 致谢：


lanhongqiu
deepseek
