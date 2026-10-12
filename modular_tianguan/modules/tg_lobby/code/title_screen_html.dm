/// 天关大厅标题界面 —— 左侧边栏布局 + 磨砂玻璃质感。
///
/// ⚠ 本文件派生自 modular_nova/modules/title_screen/code/title_screen_html.dm。
///
/// 为什么是整文件派生而不是 override：
///   DM 不允许同一类型上的同一 proc 重复定义（后 include 也会直接编译报错），
///   而 get_title_html() 定义在 modular_nova/ 下、又是天关要重做布局的入口，
///   所以改为在 tgstation.dme 中移除上游那一行、由本文件提供同名 proc。
///   这样 modular_nova/ 目录保持零改动（符合天关模块化规范）。
///
/// 同步注意：Nova 上游若改了 title_screen_html.dm（启动终端/进度条/汉化表等），
///   需要人工比对并同步到本文件。差异清单见模块 readme.md。
///
/// 样式契约（BYOND 的 browser 是 IE 内核，IE11 不支持 backdrop-filter / filter:blur，
/// 因此"磨砂玻璃"用半透明底 + 高光渐变 + 亮边框 + 内阴影 + 细斜纹噪点来近似）：
///   .tg_glass   玻璃板基类
///   .tg_side    左侧边栏（内含右下的两个外链框，靠嵌套一起移动）
///   .tg_art     侧边栏顶部展示图（GIF 必须用 <img>，IE 不播放动画背景图）
///   .tg_card/.tg_pname/.tg_pid/.tg_avatar
///   .tg_prefs   偏好摘要
///   .container_notice 已搬到右上角

GLOBAL_LIST_EMPTY(startup_messages)
// FOR MOR INFO ON HTML CUSTOMISATION, SEE: https://github.com/Skyrat-SS13/Skyrat-tg/pull/4783

#define MAX_STARTUP_MESSAGES 27

/// 侧边栏顶部展示图。按顺序取第一个存在的文件；把 GIF/PNG 丢进模块 icons/ 即可生效。
/// 必须用 <img> 标签引用：BYOND 的 IE 内核不播放 CSS 动画背景图（只显示第一帧）。
#define TG_LOBBY_ART_CANDIDATES list( \
	"modular_tianguan/modules/tg_lobby/icons/lobby_art.gif", \
	"modular_tianguan/modules/tg_lobby/icons/lobby_art.png", \
	"modular_nova/modules/title_screen/icons/loading_screen.gif", \
)

#define TG_LOBBY_CSS {"
<style type='text/css'>
/* ===================== 天关玻璃板（中性灰） ===================== */
.tg_glass {
	background-color: rgba(52, 52, 52, 0.62);
	background-image:
		linear-gradient(158deg, rgba(255,255,255,0.22) 0%, rgba(255,255,255,0.08) 34%, rgba(255,255,255,0.01) 62%, rgba(0,0,0,0.16) 100%),
		repeating-linear-gradient(112deg, rgba(255,255,255,0.042) 0px, rgba(255,255,255,0.042) 1px, rgba(255,255,255,0) 1px, rgba(255,255,255,0) 4px);
	border: 1px solid rgba(255,255,255,0.26);
	border-radius: 5px;
	box-shadow:
		inset 0 1px 0 rgba(255,255,255,0.34),
		inset 0 -1px 0 rgba(0,0,0,0.40),
		0 4px 18px rgba(0,0,0,0.55);
}

/* ===================== 左侧边栏 ===================== */
/* 侧边栏独占一屏高度，共用基类那条 158° 斜向渐变时会读成一片平色 ⇒ 这里换成**纵向**渐变：
   顶部受光、底部接地，并把底色比内容板再压暗一档，让侧边栏和内容板之间有前后层次。
   只用渐变 + 阴影（IE 内核不支持 blur/backdrop-filter，别在此处引入）。 */
.tg_side {
	position: absolute;
	left: 0; top: 0;
	width: 50vmin; height: 100%;
	z-index: 3;
	box-sizing: border-box;
	padding: 1.1vmin;
	text-align: left;
	overflow: hidden;
	border-radius: 0;
	border-left: none; border-top: none; border-bottom: none;
	background-color: rgba(36, 36, 36, 0.76);
	background-image:
		linear-gradient(to bottom,
			rgba(255,255,255,0.14) 0%,
			rgba(255,255,255,0.05) 12%,
			rgba(255,255,255,0.008) 36%,
			rgba(0,0,0,0.10) 60%,
			rgba(0,0,0,0.26) 84%,
			rgba(0,0,0,0.42) 100%),
		repeating-linear-gradient(112deg, rgba(255,255,255,0.042) 0px, rgba(255,255,255,0.042) 1px, rgba(255,255,255,0) 1px, rgba(255,255,255,0) 4px);
	border-right: 1px solid rgba(255,255,255,0.20);
	box-shadow:
		inset 0 1px 0 rgba(255,255,255,0.24),
		inset 0 -1px 0 rgba(0,0,0,0.60),
		3px 0 20px rgba(0,0,0,0.60);
	/* 收起/展开时比右侧那两个跳转栏**晚 60ms** ⇒ 读起来是「跳转栏先收、侧边栏后收」 */
	transition: left 0.22s ease-out 0.06s;
}

/* ===================== 侧边栏右下：两个外部跳转 ===================== */
/* 位置：贴着收起按钮的正下方、侧边栏右缘（left: 50vmin，与手柄同一列）。
   过渡比主侧边栏快（0.14s vs 0.22s + 0.06s 延迟）⇒ 形成「先收这俩」的错位动画。 */
.tg_extlinks {
	/* 展开时钉在侧边栏右缘那一列（与手柄同列）；收起由 body.tg_collapsed 规则接管。
	   ⚠️ 它必须是 .tg_dock 的**兄弟**（不能在里面）：在里面时 left 会相对 dock 叠加，
	   实测表现为"展开时跑到屏幕右外很远"。 */
	position: absolute;
	left: 50vmin;
	bottom: 3vmin; /* 贴着屏幕下方 */
	z-index: 4;
	display: block;
	transition: left 0.14s ease-out;
}

.tg_ext {
	display: block;
	box-sizing: border-box;
	width: 17vmin;
	height: 4.4vmin;
	line-height: 4.4vmin;
	margin-bottom: 0.5vmin;
	padding: 0 0.8vmin;
	text-decoration: none;
	font-family: "Fixedsys";
	font-size: 2.2vmin;
	color: #dcdcdc;
	text-align: left;
	white-space: nowrap;
	overflow: hidden;
	border: 1px solid rgba(255,255,255,0.20);
	border-left: none;
	border-radius: 0 4px 4px 0;
	background-color: rgba(24, 24, 24, 0.86);
	background-image: linear-gradient(to right, rgba(255,255,255,0.10), rgba(255,255,255,0.015));
	box-shadow: inset 0 1px 0 rgba(255,255,255,0.16), 2px 0 12px rgba(0,0,0,0.50);
}
.tg_ext:hover { color: #fff9c4; border-color: rgba(255,255,255,0.34); }
/* 图标放在文字**右侧** */
.tg_ext img {
	float: right;
	height: 3vmin;
	width: auto;
	margin-top: 0.7vmin;
	margin-left: 0.5vmin;
}
/* 像素图（游戏内钱袋子）用最近邻，别让浏览器插值糊掉 */
.tg_ext img.tg_pixel { image-rendering: pixelated; -ms-interpolation-mode: nearest-neighbor; }

/* 「支持我们」炫彩：持续变化 RGB。
   ⚠️ IE 内核支持 @keyframes 动 color，但**不支持** filter/hue-rotate（那才是常见写法）⇒
   这里用色相环上均匀取 6 个点循环，视觉上等价于「RGB 一直在变」。 */
@keyframes tg_rainbow {
	0%   { color: #ff5a5a; }
	17%  { color: #ffd75a; }
	33%  { color: #7dff7d; }
	50%  { color: #5ad7ff; }
	67%  { color: #9a8cff; }
	83%  { color: #ff7ad7; }
	100% { color: #ff5a5a; }
}
.tg_ext .tg_rainbow {
	animation: tg_rainbow 4s linear infinite;
	text-shadow: 0 0 5px rgba(255,255,255,0.26), 1px 1px 2px black;
}
.tg_ext:hover .tg_rainbow { animation-duration: 1.5s; }

/* ===================== 侧边栏收起 =====================
   状态由服务端持有（/mob/dead/new_player.tg_sidebar_collapsed）：
   点手柄走 byond:// Topic ⇒ 服务端取反 ⇒ output("1"/"0", "nova_title_browser:tg_set_collapsed")
   ⇒ 页面一行 JS 给 <body> 挂/摘 tg_collapsed 类 ⇒ 下面三条 CSS 规则一起动。
   ⇒ 保留平滑动画（不重投页面、不闪）：.tg_dock/.tg_extlinks 先走(0.14s)、.tg_side 后走(0.22s+0.06s)。
   ⚠️ .tg_extlinks 必须是 .tg_dock 的**兄弟**，不能放在里面 —— 在里面时 left 相对 dock 叠加，
      实测表现为"展开时两个框跑到屏幕右外很远"（dock 50vmin + 框 50vmin = 100vmin）。 */
/* 收到 -51vmin 而不是 -50：侧边栏内还有 1.1vmin 的 padding，只移 50 会漏出按钮右边缘的残影。 */

.tg_dock {
	position: absolute;
	left: 50vmin; top: 0;
	width: 0; height: 100%;
	z-index: 4;
	transition: left 0.14s ease-out; /* 比侧边栏快且无延迟 ⇒ 外壳先走、侧边栏后走（错位） */
}

/* 收起态：三处一起走 —— 手柄外壳/two 跳转框先走(0.14s)，侧边栏后走(0.22s+0.06s 延迟)。
   状态由服务端持（tg_sidebar_collapsed），经 output() 投给页面 JS 挂到 <body> 上。 */
body.tg_collapsed .tg_dock      { left: 2.5vmin; }   /* 手柄留在左缘，否则没法再展开 */
/* 两个跳转框：和侧边栏一样**滑出屏幕左侧消失**（不是停在左缘）。
   框宽 17vmin，展开时 left=50vmin ⇒ 收到 -20vmin 即完全滑出视野。 */
body.tg_collapsed .tg_extlinks  { left: -20vmin; }
body.tg_collapsed .tg_side      { left: -51vmin; }
.tg_handle:after { content: "◀"; }
body.tg_collapsed .tg_handle:after { content: "▶"; }

.tg_handle {
	position: absolute;
	left: 0; top: 50%;
	width: 3.2vmin; height: 13vmin;
	margin-top: -6.5vmin;
	z-index: 4;
	display: block;
	box-sizing: border-box;
	background-color: rgba(20, 20, 20, 0.82);
	background-image: linear-gradient(to right, rgba(255,255,255,0.16), rgba(255,255,255,0.02));
	border: 1px solid rgba(255,255,255,0.22);
	border-left: none;
	border-radius: 0 4px 4px 0;
	box-shadow: inset 0 1px 0 rgba(255,255,255,0.28), 2px 0 10px rgba(0,0,0,0.45);
	color: #cccccc;
	font-family: "Fixedsys";
	font-size: 2.2vmin;
	line-height: 13vmin;
	text-align: center;
	cursor: pointer;
	transition: left 0.22s ease-out;
}
.tg_handle:hover { color: #fff9c4; background-color: rgba(44, 44, 44, 0.90); }


/* 顶部展示图 */
.tg_art {
	position: relative;
	width: 100%; height: 18vmin;
	overflow: hidden;
	box-sizing: border-box;
	margin-bottom: 1.1vmin;
	background-color: rgba(0,0,0,0.35);
	border: 1px solid rgba(255,255,255,0.16);
	border-radius: 4px;
}
.tg_art img {
	position: absolute;
	left: 50%; top: 50%;
	height: 100%; width: auto;
	transform: translate(-50%, -50%);
	-ms-interpolation-mode: nearest-neighbor;
}

/* 角色卡 */
.tg_card { text-align: center; margin-bottom: 1.1vmin; }
.tg_avatar {
	height: 15vmin; width: auto;
	image-rendering: pixelated;
	-ms-interpolation-mode: nearest-neighbor;
}
.tg_pname {
	font-family: "Fixedsys";
	font-size: 3.3vmin;
	line-height: 3.8vmin;
	color: #eeeeee;
	letter-spacing: 1px;
	text-shadow: 0 0 6px rgba(255,255,255,0.30), 2px 2px 2px black;
}
.tg_pid {
	font-family: "Fixedsys";
	font-size: 2.1vmin;
	line-height: 2.6vmin;
	color: #9a9a9a;
}

/* 偏好摘要：做成一条独立的浅色带（自带上下边线 + 极轻的纵向渐变），
   在「角色卡」与「按钮区」之间再分出一层，同时把这条带与侧边栏底色的关系拉开。 */
.tg_prefs {
	background-color: rgba(255,255,255,0.035);
	background-image: linear-gradient(to bottom, rgba(255,255,255,0.05), rgba(0,0,0,0.06));
	border-top: 1px solid rgba(255,255,255,0.16);
	border-bottom: 1px solid rgba(0,0,0,0.50);
	box-shadow: inset 0 1px 0 rgba(255,255,255,0.06);
	padding: 0.7vmin 0.6vmin;
	margin-bottom: 1.1vmin;
	font-family: "Fixedsys";
	font-size: 2.1vmin;
	line-height: 2.9vmin;
}
.tg_prow { white-space: nowrap; overflow: hidden; }
.tg_prefs .k { color: #8a8a8a; display: inline-block; width: 8vmin; }
.tg_prefs .v { color: #e2e2e2; }

/* 按钮：玻璃片 */
.tg_side .menu_button {
	display: block;
	box-sizing: border-box;
	font-family: "Fixedsys";
	font-weight: lighter;
	text-decoration: none;
	font-size: 2.85vmin;
	line-height: 3.4vmin;
	height: 3.4vmin;
	width: 100%;
	text-align: left;
	color: #dedede;
	padding-left: 1.2vmin;
	letter-spacing: 1px;
	cursor: pointer;
	white-space: nowrap;
	overflow: hidden;
	margin-bottom: 0.35vmin;
	border: 1px solid rgba(255,255,255,0.10);
	border-radius: 3px;
	background-image: linear-gradient(to bottom, rgba(255,255,255,0.09), rgba(255,255,255,0.015));
	text-shadow: 1px 1px 2px black;
}
.tg_side .menu_button:hover {
	padding-left: 0.4vmin;
	color: #fff9c4;
	border-color: rgba(255,255,255,0.30);
	background-image: linear-gradient(to bottom, rgba(255,255,255,0.20), rgba(255,255,255,0.05));
}
.tg_side .menu_button:active { transform: translate(1px, 1px); }
.tg_side .menu_button:hover::before,
.tg_side .menu_button:active::before { width: 2.6vmin; }
.tg_side hr {
	height: 1px;
	margin: 0.7vmin 0;
	border: none;
	background-color: rgba(255,255,255,0.16);
	box-shadow: none;
}

/* ===================== 右上通知栏 ===================== */
.container_notice {
	left: auto;
	right: 1.4vmin;
	top: 1.4vmin;
	transform: none;
	text-align: right;
	max-width: 44vmin;
	z-index: 3;
	padding: 0.8vmin 1.1vmin;
	box-sizing: border-box;
}
.tg_nhd {
	font-family: "Fixedsys";
	font-size: 1.9vmin;
	line-height: 2.3vmin;
	color: #a8a8a8;
}
.container_notice .menu_notice {
	font-size: 2.2vmin;
	line-height: 2.7vmin;
	text-align: right;
}
</style>
"}

/// 把模块 icons/ 里的图发给客户端，返回可直接放进 <img src> 的短资源名。
/// ⚠️ 必须走 browse_rsc（与顶部展示图同一套路）：直接写文件路径浏览器取不到。
/// ⚠️ 资源名要带正确扩展名 —— browse_rsc 靠它判断类型。
/mob/dead/new_player/proc/tg_lobby_ext_icon(rel_path, rsc_name)
	if(!client || !fexists(rel_path))
		return ""
	src << browse_rsc(file(rel_path), rsc_name)
	return rsc_name

/mob/dead/new_player/proc/get_title_html()
	var/dat = SStitle.title_html
	dat += TG_LOBBY_CSS

	if(SSticker.current_state == GAME_STATE_STARTUP)
		dat += {"<img src="loading_screen.gif" class="bg" alt="">"}
		dat += {"<div class="container_terminal" id="terminal"></div>"}
		// 进度条：**纯 CSS 动画驱动**（不依赖 JS）。
		// 前台已验证同一个浏览器能跑 CSS @keyframes（大厅侧边栏的彩虹变色就是它），而浏览器里
		// 那段 JS 一直没有执行（用户实测：诊断行停在初始文字）⇒ 索性用 CSS 让条自己 0→99% 走过去。
		// 150 秒线性：约本服初始化量级（实测 Initializations complete within ~193s）。
		dat += {"<style>@keyframes tg_load { from { width: 0%; } to { width: 99%; } } #progress { animation: tg_load 150s linear forwards; }</style>"}
		dat += {"<div class="container_progress" id="progress_container"><div class="progress_bar" id="progress"><div class="sub_progress_bar" id="sub_progress"></div></div></div>"}
		// 路标①、诊断行已在定位完成后移除（真凶＝上游拼出的数组尾逗号，见下方注释）

		dat += {"
		<script language="JavaScript">
			var terminal = document.getElementById("terminal");
			var terminal_lines = \[\];
		"}

		for(var/message in GLOB.startup_messages)
			dat += {"terminal_lines.push(""[replacetext(message, "\"", "\\\"")]"");"}

		dat += {"
			// ⚠️ 这里原本是数组字面量的收尾 `\];`。上游把启动消息拼成
			//    \["a","b",\] 这种**尾逗号**数组 —— BYOND 内嵌浏览器是 IE 内核，
			//    老 IE 引擎在数组字面量里遇到尾逗号会直接抛语法错误 ⇒ **整段 <script> 被丢弃**
			//    （实测症状：加载条不动、终端不刷、诊断行停在初始文字）。
			//    改成 var terminal_lines = \[\]; + push() 逐条添加：无数组字面量、无尾逗号。
			function append_terminal_text(text) {
				if(text) {
					terminal_lines.push(text);
				}
				while(terminal_lines.length > [MAX_STARTUP_MESSAGES]) {
					terminal_lines.shift();
				}

				terminal.innerHTML = terminal_lines.join("");
			}

			append_terminal_text();

			var progress_bar = document.getElementById("progress");
			var sub_progress_bar = document.getElementById("sub_progress");
			var progress_container = document.getElementById("progress_container");
			// 进度条：**完全不依赖服务端数值** —— 从本页加载那一刻起、按一个估时往上爬。
			// 为什么改掉上游那套：上游用「world.timeofday − 服务端开局时刻」当分子、
			// 「历史平均/默认估时」当分母 ⇒ **开服几分钟后才连进来的人**分子早已超过分母
			// ⇒ 比例一上来就 ≥100% ⇒ 条满格不动（实测症状：「加载条不动，加载完直接进去」）。
			// 现在：分子 = 本页自己的运行时长 ⇒ 从 0 一定往上走，不可能不动。
			var progress_started_ms = (new Date()).getTime();
			// 估时 150 秒（本服实测初始化 ~193 秒，取略小值让条走得动、不早早封顶）。
			// 注意：这里**不再引用服务端的 world.timeofday/average_completion_time** ——
			// 上游那套对"开服几分钟后才连进来的人"天然失效（分子早已超过分母 ⇒ 条满格不动）。
			// 服务端后续仍可通过 update_loading_progress 修正估时。
			var progress_total_ms = 150000;
			if(progress_total_ms < 30000)
				progress_total_ms = 30000;

			setInterval(function() {
				var elapsed_ms = (new Date()).getTime() - progress_started_ms;
				var pct = elapsed_ms / progress_total_ms * 100;
				if(pct > 99) pct = 99;
				progress_bar.style.width = "" + pct + "%";
				sub_progress_bar.style.width = "" + Math.min(pct + 6, 99) + "%";
			}, 16.666666667);

			function update_loading_progress(current_time, total_time) {
				// 服务端推的东西是坏的（output(list2params(list(a,b)), …) ⇒ 页面只剩一个 "a=b"），
				// 所以这里只做一件事：它若给了个**像样的总量**就用来修正估时；坏值一律忽略，
				// 绝不允许把动画弄坏（分子是本页自己的运行时长，永远在长）。
				var raw = (current_time === undefined || current_time === null) ? "" : String(current_time);
				var s = (total_time === undefined || total_time === null) ? raw : String(total_time);
				if((total_time === undefined || total_time === null) && raw.indexOf("=") !== -1)
					s = raw.split("=")\[1\];
				var got = parseFloat(s);
				if(got > 0 && got < 100000)
					progress_total_ms = got * 100;
			}

			function update_current_character() {}
		</script>
		"}

	else
		dat += {"<img src="loading_screen.gif" class="bg" alt="">"}

		dat += {"<div class="container_notice tg_glass">"}
		dat += {"<div class="tg_nhd">◆ 通知</div>"}
		if(SStitle.current_notice)
			dat += {"<p class="menu_notice">[SStitle.current_notice]</p>"}
		else
			dat += {"<p class="menu_notice" style="color:#7d93a8;font-size:1.9vmin">暂无新通知</p>"}
		dat += "</div>"

		// 收起开关：走 byond:// Topic（与 READY / 开始游戏同一套），服务端存状态后用
		// 手柄与两个外链框装进同一个 .tg_dock 外壳 ⇒ 外壳一移，里面的东西必然一起走。
		// 收起状态直接算成值：位置写进行内 style、箭头出字符 ⇒ 不依赖任何前端机制。
		dat += {"<div class="tg_dock">"}
		dat += {"<a class="tg_handle" href='byond://?src=[text_ref(src)];tg_sidebar_toggle=1' title="收起/展开侧边栏"></a>"}
		dat += {"</div>"}  // dock 到此为止 —— 下面两个跳转框是独立兄弟元素，位置不再叠加
		// 两个外部跳转：**不再依附任何外壳**，位置由服务端直接写在它自己的行内 style 上
		// （收起 2.5vmin / 展开 50vmin）。前几轮试过 :checked 兄弟选择器、轮询 JS、body 类、dock 外壳，
		// 全都指望某个前端机制生效，结果框始终不动；现在位置直接进标记 ⇒ 不依赖任何选择器或脚本。
		// 图标在文字右侧。
		// ⚠️ 图标不能直接写文件路径：浏览器取不到，必须像顶部展示图那样走 browse_rsc 发给客户端。
		// ⚠️ 外链不能写 http 的 href：BYOND 的浏览器只认 byond:// ⇒ 走 Topic 再用 link() 交给系统浏览器。
		var/wiki_icon = tg_lobby_ext_icon("modular_tianguan/modules/tg_lobby/icons/wiki.png", "tg_ext_wiki.png")
		var/moneybag_icon = tg_lobby_ext_icon("modular_tianguan/modules/tg_lobby/icons/moneybag.png", "tg_ext_moneybag.png")
		dat += {"<div class="tg_extlinks">"}
		dat += {"<a class="tg_ext" href='byond://?src=[text_ref(src)];tg_ext=wiki' title="天关维基（用系统浏览器打开）">天关wiki<img src="[wiki_icon]" alt=""></a>"}
		dat += {"<a class="tg_ext" href='byond://?src=[text_ref(src)];tg_ext=afdian' title="爱发电 · 支持天关（用系统浏览器打开）"><span class="tg_rainbow">支持我们</span><img class="tg_pixel" src="[moneybag_icon]" alt=""></a>"}
		dat += {"</div>"}



		// 页面侧只做一件事：给 <body> 增/删 tg_collapsed 类，CSS 认这个类（平滑动画靠它）。
		// ⚠️ 服务端投的是**字符串** "1"/"0"：投数字 0 时那次 JS 调用可能不触发（表现为"点一次能收、再点打不开"）。
		// ⚠️ 不整块覆盖 className（会擦掉 body 上其它类，且 IE 内核下清空不总是生效），只增删这一个。
		// ⚠️ DM 的 {"..."} 字符串里不能有正则字面量（\s 等是雷区），也不能有未转义的 [ ⇒ 写成 \[ \]。
		dat += {"
		<script language="JavaScript">
			// ── 以下 ready / antag / character 三块从上游同文件搬回 ──
			// （当初接管这个文件时整段 script 丢了 ⇒ 准备图标点了不变、加载终端不动）
			// ⚠️⚠️ 元素查找**必须惰性**（放在函数里），不能像上游那样写成模块级变量：
			//   上游的 <script> 排在按钮**之后**，而我们这个 <script> 排在按钮**之前**
			//   ⇒ 脚本求值时 document.getElementById("ready") 还是 null，
			//   写成模块级变量会让三个 mark 全是 null、之后每次赋值都抛异常
			//   ⇒ 图标永远不变（实测症状：点准备，左侧图标不动）。
			//   惰性查找与顺序无关，以后再挪按钮也不会坏。
			var ready_int = 0;
			// ⚠️ 只换图标的 class 与字符，**绝不重写整个 innerHTML**：
			//    按钮文字由服务端渲染、并已过 lang_localize_title_html() 汉化；
			//    上游那套「整块 innerHTML = 英文常量数组」会把汉化顶掉
			//    （实测症状：点一下准备，中文「准备」变回英文「READY」）。图标与语言无关。
			function set_ready_look(want) {
				var el = document.getElementById("ready");
				if(!el) return;
				var ico = el.getElementsByTagName("span")\[0\];
				if(!ico) return;
				ico.className = want ? "checked" : "unchecked";
				ico.innerHTML = want ? "☑" : "☒";
			}
			function toggle_ready(setReady) {
				// ⚠️ 服务端投的是**字符串** "1"/"0"（投数字 0 时那次 JS 调用会丢）。
				//    JS 里字符串 "0" 是 **truthy** ⇒ 绝不能写 if(setReady)，
				//    必须显式认 "1"/1/true 为"已准备"、"0"/0/false 为"未准备"；
				//    参数完全缺失时（例如旧页面残留）按取反处理。
				if(setReady === 1 || setReady === "1" || setReady === true)
					ready_int = 1;
				else if(setReady === 0 || setReady === "0" || setReady === false)
					ready_int = 0;
				else
					ready_int = ready_int ? 0 : 1;
				set_ready_look(ready_int);
			}
			var antag_int = 0;
			function set_antag_look(want) {
				var el = document.getElementById("be_antag");
				if(!el) return;
				var ico = el.getElementsByTagName("span")\[0\];
				if(!ico) return;
				ico.className = want ? "checked" : "unchecked";
				ico.innerHTML = want ? "☑" : "☒";
			}
			function toggle_antag(setAntag) {
				// 同 toggle_ready：显式认 "1"/"0"（字符串 "0" 是 truthy）
				if(setAntag === 1 || setAntag === "1" || setAntag === true)
					antag_int = 1;
				else if(setAntag === 0 || setAntag === "0" || setAntag === false)
					antag_int = 0;
				else
					antag_int = antag_int ? 0 : 1;
				set_antag_look(antag_int);
			}

			function update_current_character(name) {
				var slot = document.getElementById("character_slot");
				if(slot && name) slot.textContent = name.toUpperCase();
			}

			// ── 天关追加：大厅角色卡的实时刷新接收端（lobby_card.dm 往这些函数名 push）──
			// ⚠️ output() 到 browser 会按 URL 参数解析 ⇒ base64 里的 + 被解码成空格，必须还原，
			//    否则 PNG 数据损坏、头像显示成一个叉。不用正则（DM 字符串雷区），用 split/join。
			function tg_set_avatar(data) {
				var e = document.getElementById("tg_avatar");
				if(!e || !data) return;
				e.src = "data:image/png;base64," + data.split(" ").join("+");
			}
			function tg_set_prefs(html) {
				var e = document.getElementById("tg_prefs");
				if(e) e.innerHTML = html;
			}
			function tg_set_name(name) {
				var e = document.getElementById("tg_pname");
				if(e) e.innerHTML = name;
			}
			function tg_set_pid(text) {
				var e = document.getElementById("tg_pid");
				if(e) e.innerHTML = text;
			}

			function tg_set_collapsed(on) {
				var b = document.body;
				if(!b) return;
				var want = (on === 1 || on === "1" || on === true);
				var cur = b.className ? (" " + b.className + " ") : " ";
				var has = cur.indexOf(" tg_collapsed ") !== -1;
				if(want && !has) {
					b.className = b.className ? (b.className + " tg_collapsed") : "tg_collapsed";
				}
				else if(!want && has) {
					var parts = cur.split(" ");
					var out = "";
					for(var i = 0; i < parts.length; i++) {
						if(parts\[i\] && parts\[i\] !== "tg_collapsed") {
							out = out ? (out + " " + parts\[i\]) : parts\[i\];
						}
					}
					b.className = out;
				}
			}
			tg_set_collapsed("[tg_sidebar_collapsed ? 1 : 0]");
		</script>
		"}

		dat += {"<div class="tg_side tg_glass">"}

		var/art_tag = tg_lobby_art_html()
		if(art_tag)
			dat += {"<div class="tg_art">[art_tag]</div>"}

		dat += tg_lobby_card_html()

		dat += {"<div class="tg_btns">"}
		if(!SSticker || SSticker.current_state <= GAME_STATE_PREGAME)
			dat += {"<a id="ready" class="menu_button" href='byond://?src=[text_ref(src)];toggle_ready=1'>[ready == PLAYER_READY_TO_PLAY ? "<span class='checked'>☑</span> READY" : "<span class='unchecked'>☒</span> READY"]</a>"}
		else
			dat += {"
				<a class="menu_button" href='byond://?src=[text_ref(src)];late_join=1'>JOIN GAME</a>
				<a class="menu_button" href='byond://?src=[text_ref(src)];view_manifest=1'>CREW MANIFEST</a>
				<a class="menu_button" href='byond://?src=[text_ref(src)];view_directory=1'>CHARACTER DIRECTORY</a>
			"}

		dat += {"<a class="menu_button" href='byond://?src=[text_ref(src)];observe=1'>OBSERVE</a>"}

		dat += {"
			<hr>
			<a class="menu_button" href='byond://?src=[text_ref(src)];character_setup=1'>SETUP CHARACTER (<span id="character_slot">[uppertext(client.prefs.read_preference(/datum/preference/name/real_name))]</span>)</a>
			<a class="menu_button" href='byond://?src=[text_ref(src)];game_options=1'>GAME OPTIONS</a>
			<a id="be_antag" class="menu_button" href='byond://?src=[text_ref(src)];toggle_antag=1'>[client.prefs.read_preference(/datum/preference/toggle/be_antag) ? "<span class='checked'>☑</span> BE ANTAGONIST" : "<span class='unchecked'>☒</span> BE ANTAGONIST"]</a>
			<span class="menu_button info_display">LATEJOIN QUEUE: [SStitle.get_latejoin_queue_count()]</span>
			<hr>
			<a class="menu_button" href='byond://?src=[text_ref(src)];server_swap=1'>SWAP SERVERS</a>
		"}

		if(!is_guest_key(src.key))
			dat += playerpolls()


		dat += "</div>"
		dat += "</div>"

		dat += {"
		"}

	// Tell the server this page loaded.
	dat += {"
		<script>
			var ready_request = new XMLHttpRequest();
			ready_request.open("GET", "?src=[text_ref(src)];title_is_ready=1", true);
			ready_request.send();
		</script>
	"}

	dat += "</body></html>"

	// NOVA EDIT - i18n: 标题界面经 raw browse()（绕过 browser.dm 的 AC 钩子），在此专项本地化菜单文案
	// （JOIN GAME/CREW MANIFEST/… 含 JS 切换数组里的 BE ANTAGONIST）。用带 HTML 边界的整词替换、不走全局 AC，
	// 避免单词(OBSERVE/READY)被 AC 子串误嵌进 OBSERVER/ALREADY。
	if(GLOB.i18n_server_locale != DEFAULT_UI_LOCALE)
		dat = lang_localize_title_html(dat)

	return dat

/// 侧边栏顶部展示图：按 TG_LOBBY_ART_CANDIDATES 顺序取第一个存在的文件并投递到客户端资源缓存。
/// 返回到 <div class="tg_art"> 里的 <img> 片段；全部缺失时返回空串（该区块自动隐藏）。
/mob/dead/new_player/proc/tg_lobby_art_html()
	if(!client)
		return ""
	for(var/art_path in TG_LOBBY_ART_CANDIDATES)
		if(!fexists(art_path))
			continue
		// browse_rsc 是靠扩展名决定类型的，所以资源名要带上原扩展名。
		var/rsc_name = "tg_lobby_art.[copytext(art_path, -2)]"
		src << browse_rsc(file(art_path), rsc_name)
		return {"<img src="[rsc_name]" alt="">"}
	return ""

/// 标题界面 HTML 的菜单文案本地化（zh-Hans；全服中文时由 get_title_html 调用）。多词整词替换，
/// 单词项带 `>…<` / ` …<` HTML 边界以防嵌进其它词。未来加 locale 时在此分支扩展。
/proc/lang_localize_title_html(html)
	if(!istext(html))
		return html
	// 多词菜单项（不会嵌进别的词）。"BE ANTAGONIST" 同时覆盖链接与 JS 切换数组两处。
	html = replacetext(html, "JOIN GAME", "加入游戏")
	html = replacetext(html, "CREW MANIFEST", "船员名册")
	html = replacetext(html, "CHARACTER DIRECTORY", "角色目录")
	html = replacetext(html, "SETUP CHARACTER", "角色设置")
	html = replacetext(html, "GAME OPTIONS", "游戏选项")
	html = replacetext(html, "BE ANTAGONIST", "扮演反派")
	html = replacetext(html, "LATEJOIN QUEUE", "补位队列")
	html = replacetext(html, "SWAP SERVERS", "切换服务器")
	// 单词项：带 HTML 边界，避免 AC/整串误伤（OBSERVE→OBSERVER、READY→ALREADY）。
	html = replacetext(html, ">OBSERVE<", ">旁观<")
	html = replacetext(html, " READY<", " 准备就绪<")
	return html

#undef TG_LOBBY_CSS
#undef TG_LOBBY_ART_CANDIDATES
