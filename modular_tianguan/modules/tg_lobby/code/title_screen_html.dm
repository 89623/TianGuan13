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
///   .tg_side    左侧边栏
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
	transition: left 0.22s ease-out;
}

/* ===================== 侧边栏收起（纯 CSS checkbox，无 JS） =====================
   input 必须排在 .tg_handle 和 .tg_side 之前，`~` 兄弟选择器才能命中它们。
   默认未勾选 = 展开，符合"默认打开"。 */
.tg_collapse_input { display: none; }
/* 收到 -51vmin 而不是 -50：侧边栏内还有 1.1vmin 的 padding，只移 50 会漏出按钮右边缘的残影。 */
.tg_collapse_input:checked ~ .tg_side { left: -51vmin; }

.tg_handle {
	position: absolute;
	left: 50vmin; top: 50%;
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
.tg_handle:after { content: "◀"; }
.tg_collapse_input:checked ~ .tg_handle { left: 2.5vmin; }
.tg_collapse_input:checked ~ .tg_handle:after { content: "▶"; }

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

/* 偏好摘要 */
.tg_prefs {
	border-top: 1px solid rgba(255,255,255,0.13);
	border-bottom: 1px solid rgba(255,255,255,0.13);
	padding: 0.7vmin 0;
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

/mob/dead/new_player/proc/get_title_html()
	var/dat = SStitle.title_html
	dat += TG_LOBBY_CSS

	if(SSticker.current_state == GAME_STATE_STARTUP)
		dat += {"<img src="loading_screen.gif" class="bg" alt="">"}
		dat += {"<div class="container_terminal" id="terminal"></div>"}
		dat += {"<div class="container_progress" id="progress_container"><div class="progress_bar" id="progress"><div class="sub_progress_bar" id="sub_progress"></div></div></div>"}

		dat += {"
		<script language="JavaScript">
			var terminal = document.getElementById("terminal");
			var terminal_lines = \[
		"}

		for(var/message in GLOB.startup_messages)
			dat += {""[replacetext(message, "\"", "\\\"")]","}

		dat += {"
			\];

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
			// milliseconds, the actual realtime tick number
			var previous_tick = new Date().getTime();
			// These times are all in 10ths of a second, like byond.
			var progress_current_time = [world.timeofday - SStitle.progress_reference_time];
			var progress_completion_time = [SStitle.average_completion_time];
			// Current progress bar position from 0-100
			var progress_current_position = 0;
			// Current start position from 0-100 of subprogress area. Zooming towards target_sub_start.
			var progress_sub_start = 0;
			// Target start position of progress area. A captured value of progress_current_position.
			var target_sub_start = 0;

			setInterval(function() {
				// Compensate for shakey execution.
				if(progress_current_time < progress_completion_time) {
					var current_tick = new Date().getTime();
					progress_current_time += (current_tick - previous_tick) / 100;
					previous_tick = current_tick;
				}

				// Bound the new position between the old pos and 100: only go forwards
				progress_current_position = Math.min(Math.max(progress_current_time / progress_completion_time * 100, progress_current_position), 100);

				if(progress_sub_start == 0) {
					// person just connected, jump to current real progress pos.
					progress_sub_start = target_sub_start = progress_current_position;
				} else {
					// Animate the sub-progress position; requires old and new progress bar pos to know speed.
					progress_sub_start = Math.min(progress_sub_start + 0.1, target_sub_start);
				}

				// Recalculate gap as a % within a % since they're nested.
				var progress_sub_current_position = (progress_current_position - progress_sub_start) / progress_current_position * 100;

				progress_bar.style.width = "" + progress_current_position + "%";
				sub_progress_bar.style.width = "" + progress_sub_current_position + "%";
			}, 16.666666667);

			function update_loading_progress(current_time, total_time) {
				progress_current_time = parseFloat(current_time);
				progress_completion_time = parseFloat(total_time);
				target_sub_start = progress_current_position;
			}

			function update_current_character() {}
			function tg_set_avatar() {}
			function tg_set_prefs() {}
			function tg_set_name() {}
			function tg_set_pid() {}
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

		// 侧边栏收起开关：纯 CSS（checkbox + label），无 JS、不刷新页面、默认展开。
		// input 必须排在 .tg_handle / .tg_side 之前，:checked ~ 才能命中它们。
		dat += {"<input type="checkbox" id="tg_collapse" class="tg_collapse_input">"}
		dat += {"<label for="tg_collapse" class="tg_handle" title="收起/展开侧边栏"></label>"}

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
		<script language="JavaScript">
			var ready_int = 0;
			var ready_mark = document.getElementById("ready");
			var ready_marks = \[ "<span class='unchecked'>☒</span> READY", "<span class='checked'>☑</span> READY" \];
			function toggle_ready(setReady) {
				if(setReady) {
					ready_int = setReady;
					ready_mark.innerHTML = ready_marks\[ready_int\];
				}
				else {
					ready_int++;
					if (ready_int === ready_marks.length)
						ready_int = 0;
					ready_mark.innerHTML = ready_marks\[ready_int\];
				}
			}
			var antag_int = 0;
			var antag_mark = document.getElementById("be_antag");
			var antag_marks = \[ "<span class='unchecked'>☒</span> BE ANTAGONIST", "<span class='checked'>☑</span> BE ANTAGONIST" \];
			function toggle_antag(setAntag) {
				if(setAntag) {
					antag_int = setAntag;
					antag_mark.innerHTML = antag_marks\[antag_int\];
				}
				else {
					antag_int++;
					if (antag_int === antag_marks.length)
						antag_int = 0;
					antag_mark.innerHTML = antag_marks\[antag_int\];
				}
			}

			var character_name_slot = document.getElementById("character_slot");
			function update_current_character(name) {
				character_name_slot.textContent = name.toUpperCase();
			}

			// 天关：侧边栏角色卡刷新，由 /client/proc/tg_push_lobby_card() 逐字段单标量推送。
			// 不用一个函数收多参数：output() 到 browser 的文本按 URL 参数解析，多参打包不可靠。
			// 另外 base64 里的 "+" 会被 URL 解码成空格，必须还原，否则 PNG 数据损坏、头像变叉。
			function tg_set_avatar(base64_data) {
				var avatar_node = document.getElementById("tg_avatar");
				if(avatar_node && base64_data) {
					avatar_node.src = "data:image/png;base64," + base64_data.replace(/ /g, "+");
				}
			}
			function tg_set_prefs(prefs_html) {
				var prefs_node = document.getElementById("tg_prefs");
				if(prefs_node && prefs_html) {
					prefs_node.innerHTML = prefs_html;
				}
			}
			function tg_set_name(name) {
				var name_node = document.getElementById("tg_pname");
				if(name_node && name) {
					name_node.textContent = name;
				}
			}
			function tg_set_pid(text) {
				var pid_node = document.getElementById("tg_pid");
				if(pid_node && text) {
					pid_node.textContent = text;
				}
			}

			function append_terminal_text() {}
			function update_loading_progress() {}
		</script>
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
