## 传真机网络目的地：团结联盟地方行政委员会

模块 ID：`FAX_NETWORKS`

### 说明：

在**游戏内传真机**（`/obj/machinery/fax`）界面的「Send」列表里增加一个目的地按钮 —— **团结联盟地方行政委员会**
（英文 canonical 名 `Union of Allied Republics Local Administrative Committee`，键/回传 ID `uar_admin`）。

它和上游的 `Sol Federation Local Command Team` / `Free Trade Union Local Office` / `Heliostatic Coalition` 一样，
属于**假网络（special network）**：没有对应的真实传真机，按下按钮走 `send_special`，
把纸变成一条 **管理员请求**（`GLOB.requests.fax_request`）+ 管理员聊天提示，不会真的"寄"到某台机器上
（`RequestManager` 的 `print` 动作找不到 `fax_id` 匹配的 `/obj/machinery/fax/admin` 时会静默无事，
这是所有假网络的既有行为，NT 人力资源部那些也一样）。

本模块只登记这一条网络；以后再加班要往同一张表里加一行即可（见「维护备注」）。

### 核心文件 / Proc 改动：

- **无。** `code/`、`modular_nova/` 一个字都没改。

### 模块化覆盖：

- 无 `master_files/` 覆盖。本模块用**新增 proc**（`/obj/machinery/fax/New()`）代替覆盖
  —— 这个 proc 此前在**全仓任何文件里都没被定义过**（`code/modules/paperwork/fax.dm` 与
  `modular_nova/master_files/code/modules/paperwork/fax.dm` 都只定义 `Initialize()`），
  所以不构成「同类型同 proc 重复定义」。

### 为什么挂 `New()` 而不是 `Initialize()`：

Nova 的 `modular_nova/master_files/code/modules/paperwork/fax.dm` 已经定义了
`/obj/machinery/fax/Initialize(mapload)`（在里面给 `special_networks` 追加 Tarkon / Interdyne /
Sol Fed / Clowns / Mimes / Trade Union / Void / Helio 八条）。**DM 不允许同一类型重复定义同一个 proc**，
第二份会直接编译报错（实测 `dm.exe` 516.1685：`b.dm:1:error: bar: duplicate definition`；
本仓库 `tgstation.dme` 里 TG_LOBBY 的两次 `TIANGUAN EDIT REMOVAL` 也是同一个原因）。

于是本模块挂在该类型上另一个**无人定义**的 per-instance 入口 `New()`：

| 时机 | 谁先跑 | 为什么安全 |
| --- | --- | --- |
| 地图加载期（地图上的传真机） | `New()` → 之后才 `Initialize()` | 只往 assoc list 写一个固定键，Nova 稍后是**追加**别的键，互不干扰 |
| 运行期 `new /obj/machinery/fax()`（如 `send_fax_to_area()` 的空投传真机） | `..()` 里先跑 `Initialize()`，回来后再写 | 同上，Nova 已经追加完，这里再补一条 |

`special_networks` 是**实例变量**（每个实例一份副本，不是 static），实例化时初值已就位，
所以两种顺序下 `New()` 里写入都生效。用 `special_networks["uar_admin"] = list(...)` 这种**下标赋值**
（而不是 `+=`）保证幂等 —— 即使将来有人在别处二次触发也不会添出重复条目。

上游「假网络」的字段含义（照抄 Nova 的写法）：

```dm
special_networks["uar_admin"] = list(
	fax_name = "Union of Allied Republics Local Administrative Committee", // 英文 canonical 名，显示时反查译文
	fax_id = "uar_admin",  // 键 + act 回传标识，**不可翻译**
	color = "uar_darkred", // 天关自加的深红档（tgui-core 没有，见下「按钮色怎么来的」）
	emag_needed = FALSE,   // TRUE = 只有被 emag 过的传真机才看得到
)
```

- `color` 取 TGUI 按钮色：常态档是 tgui-core 内置的
  `red / orange / yellow / olive / green / teal / blue / violet / purple / pink / brown / gold / white / grey`；
  **`uar_darkred` 是 tgui-core 没有、由天关自己补的一档**（`#8b0000`，见下「按钮色怎么来的」）。
  本条目取它 —— 用户明确要"深红而不是那个亮红"。想再调就改这一个词 + scss 里那一行颜色值。
  **档名刻意不叫 `darkred`**（那是 CSS 标准色名）：上游哪天把 `darkred` 加进 color-map，
  本文件同权重、靠后加载就会把上游那档静默盖掉；带 `uar_` 前缀的档名与上游零重名，
  也顺便让"谁在用这一档"在 bundle 里一眼可查。
- `emag_needed` 决定可见性：`FALSE` = 所有传真机都看得到（NT 人力资源部 / 太阳联邦 / 自由贸易联盟 / 小丑星球那一类）；
  `TRUE` = 只有 `syndicate_network` 或被 emag 的传真机看得到（破坏部 / 塔孔 / 因特达因）。**本条目按"公开目的地"取 `FALSE`**，
  想改成辛迪加侧就把它写成 `TRUE`。

### 显示名（i18n）：

显示名走仓库既有机制，不改 TSX：`/obj/machinery/fax/ui_data()` 对每条 special network 调
`lang_localize_display_name(net["fax_name"])`（`NOVA EDIT - I18N` 块），从 `strings/i18n/<locale>/_fax_networks.json`
（`catalog-domains.json` 里的 `global_reverse` 域）整串精确反查。所以：

- `strings/i18n/zh-Hans/_fax_networks.json` → `"Union of Allied Republics Local Administrative Committee": "团结联盟地方行政委员会"`
- `strings/i18n/en/_fax_networks.json` → 恒等条目（与既有 18 条一样两份都写）

**key 必须是英文 canonical 名、与 DM 里 `fax_name` 逐字节一致**，否则反查落空、界面显示英文原文。
`fax_id`（`uar_admin`）走 `act()` 回传，永远不进任何译文表。

### 本模块目录外的依赖文件：

- `tgstation.dme` —— 一行 `#include "modular_tianguan\modules\fax_networks\code\fax_networks.dm"`
- `strings/i18n/en/_fax_networks.json`、`strings/i18n/zh-Hans/_fax_networks.json`
- `tgui/packages/tgui/styles/tianguan/shared.scss` —— **天关自有文件**（`// THIS IS A TIANGUAN UI FILE`），深红按钮档写在这里
- `tgui/packages/tgui/styles/main.scss` —— 只有 **1 行** `@include meta.load-css('./tianguan/shared.scss');`（带 `TIANGUAN_SHARED` 标记）
- **`Fax.tsx` 不用改**：Send 列表是从 `special_faxes` 负载渲染的（`data.special_faxes.map(...)`），
  新条目自动出现、无新增静态串，所以**不需要**跑 `tgui:i18n:extract`；
  但改了 scss 就必须重跑 `tgui:build` —— 否则客户端拿到的 bundle 里没有 `.Button--color--uar_darkred`，
  按钮只会落回默认底色（不报错、静默变灰）。

### 按钮色怎么来的：

TGUI 的 `<Button color="x">` 只拼一个 class（`Button--color--x`），底色由 `.Button--color--x { --color: … }` 给；
这些档位来自 tgui-core 里那张固定的 `$color-map`（`node_modules/tgui-core/styles/colors.scss`），
**没有"深红"这一档，而 node_modules 不能改**。所以天关自己补一档，写在**自有文件**里：

```scss
// tgui/packages/tgui/styles/tianguan/shared.scss（TIANGUAN UI FILE）
.Button--color--uar_darkred {
  --color: #8b0000; // 更深 → #5c0e12（团结联盟徽记深红）；更亮 → #a00000
}
```

上游 `main.scss` 里只留 1 行 include（这是整条链路在上游文件里的**全部**足迹）：

```scss
// TIANGUAN EDIT ADDITION START - TIANGUAN_SHARED
@include meta.load-css('./tianguan/shared.scss');
// TIANGUAN EDIT ADDITION END
```

四个要点：

- **档名必须带前缀**（`uar_darkred`，不要写成 CSS 标准色名 `darkred`）：上游 tgui-core 的 color-map 是按名字生成的，
  同权重规则靠后加载者胜 —— 上游将来真加了同名档，就会被本文件静默盖掉。
- **必须写在全局作用域**（`shared.scss` 顶层），别塞进 `.theme-uar` —— 传真界面通常跑在默认主题下。
- 屏幕上的实际底色会被 tgui 的 `button-color()` mixin 按 `--adjust-color`（`base.scss` = 5）再压暗一档：
  `#8b0000` 的 l≈27.3% → 22.3% → 实物约 `#720000`。所有按钮共用这套算法，不是写错了。
- **为什么用"档位类"而不是像 Pandemic 那样直接给个 raw 颜色名**：那是 **ProgressBar** 自己的兜底分支
  （非合法档 → `style.backgroundColor = x`，见 `dist/components/ProgressBar.js`）；**Button 没有这条分支**
  （`dist/components/Button.js` 只有 `Button--color--${color}` 一条路），而且按钮的 hover/active/disabled
  全部由 `--color` 派生（`Button.scss` 的 `button-color()`），内联背景色会把这些状态样式压掉。

**影响面（2026-09-26 全仓核查结论）**：这条规则只命中带 `Button--color--uar_darkred` 的元素，
全仓只有本条目会发出这个档名（`grep -rn darkred tgui/packages` 里另外两处：
`Pandemic/Beaker.tsx` 的 `color="darkred"` 是 **ProgressBar**，发的是 `ProgressBar--color--*`；
`PersonalityPage.tsx` 的是内联 `borderColor`）→ 对既有界面**零影响**。

### Defines：

- 无（模块内不定义宏；`fax_id` 与列表键同字面量，与 Nova 的既有条目写法保持一致）

### 构建 / 测试方式：

- DM 侧：`dm.exe tgstation.dme`（本机 516.1685 实测 0 error）。
- TGUI 侧（**只在本模块动了 scss 时需要**）：`cd tgui && ./node_modules/.bin/rspack.exe build`，
  产物是 `tgui/public/tgui.bundle.{js,css}`，改完必须重启服务器（asset 缓存是**启动时读文件**的，见
  `code/modules/asset_cache/assets/tgui.dm` 里 `file("tgui/public/tgui.bundle.css")`）。
  **不必重编 DM**：bundle 不在 .dmb 里，DM 侧只是把它当静态资源登记/下发；DM 源码没动时 dm.exe 那步可省。
- 自检（应各命中 1 处）：
  ```sh
  grep -c "Button--color--uar_darkred" tgui/packages/tgui/styles/tianguan/shared.scss   # 1（规则在本天关文件里）
  grep -c "Button--color--uar_darkred" tgui/public/tgui.bundle.css        # 1（深红档真的进了 bundle）
  grep -c "uar_darkred" modular_tianguan/modules/fax_networks/code/fax_networks.dm   # 1（DM 侧引用了它）
  grep -n "团结联盟地方行政委员会" strings/i18n/zh-Hans/_fax_networks.json            # 1（反查译文在）
  ```

  ⚠️ 别拿 `grep tgstation.dmb` 当自检 —— .dmb 里的字符串是编译后的形态，
  连 `grep "NT HR Department" tgstation.dmb` 都是 0 命中，拿它验证只会假红。
- 游戏内复验（需 zh-Hans locale，`config/game_options.txt` 已有 `I18N_SERVER_LOCALE zh-Hans`）：
  1. 站上随便找一台传真机（各部长办公室、桥区、图书馆等）。
  2. 往托盘里放一张纸 → 点「Send」区里的 **团结联盟地方行政委员会** 按钮（**深红**色，与旁近的亮红"破坏部"明显不同）。
  3. 纸应播放发送动画并消失；`History` 区多一条 `Send — Union of Allied Republics Local Administrative Committee`。
  4. 管理员侧（PGLOB.requests）出现一条传真请求 `sent a fax message from <机器名>/<fax_id> to <参数里的显示名>`。
  5. 回归：其它网络按钮（NT 人力资源部 / 破坏部 / 太阳联邦…）照旧能点；没有纸时所有按钮保持禁用。
  6. 被 emag 过的传真机与辛迪加传真机同样能看到这一条（因为 `emag_needed = FALSE`）。

### 维护备注：

- **上游若给 `/obj/machinery/fax` 加了自己的 `New()`**，本文件会变成 `duplicate definition` 编译错误
  （响亮的失败，不会静默失效）。届时按 TG_LOBBY 的做法处理：在 `tgstation.dme` 里
  `TIANGUAN EDIT REMOVAL` 掉上游那份、改由本模块提供合并后的 `New()`，或把这条网络并进接管过来的 `Initialize()`。
- **Nova 改动 `special_networks` 的字段结构时**（例如新增 `visible_to_network` 之类的第 5 个字段），
  本条目要跟着补 —— 这里只有 4 个字段，缺字段不会报错，只会让按钮表现异常。
- 加**第二条**天关网络：在同一个 `New()` 里按同样形状再写一行 `special_networks["<新键>"] = list(...)`，
  并同步两份 `_fax_networks.json`。不要在别的模块里重复定义 `/obj/machinery/fax/New()`（又是同 proc 冲突）。
- 本模块不在 `tools/i18n` 的抽取范围内：`New()` 里的字符串**不是** sink 调用（`to_chat`/`balloon_alert`/`visible_message` 等）
  也不是 `SINK_VARS`（name/desc/message…），所以 `nova-i18n extract/rewrite` 不会把它改写为 `LANG()`
  —— 这正是我们要的（显示名必须保持英文 canonical 才能被反查命中）。**不要**手工把它包进 `LANG()`。

### 致谢：

- 网络表结构与显示名反查机制来自 Nova Sector 上游与仓库既有 i18n 基础设施；
  本条目为天关新增（团结联盟 / `uar` 阵营，见 `config/tianguan/employers.json` 与
  `modular_tianguan/modules/traitor_background/readme.md`）。
