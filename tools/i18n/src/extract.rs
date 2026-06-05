//! DM 字符串抽取。
//!
//! 解析复用 SpacemanDMM 的 dreammaker 解析器（API 与 DreamChecker 一致）。
//! 抽取来源：
//!   1. 类型变量初始化里的玩家可见文本（SINK_VARS：name/desc 等，动态渲染文本主要来源）。
//!   2. proc 体内的汇聚点调用（SINK_CALLS：to_chat / visible_message / balloon_alert 等）。
//! 内插字符串 (Term::InterpString) 与字符串 `+` 拼接被转为 {0}/{1} 占位符模板，
//! 以适配中文语序；span_* 等宏在预处理期已展开为 HTML 包裹 + 内层文本的拼接，
//! 其纯标签片段（如 "<span class='notice'>"）会被过滤掉，只留可翻译文本。
//!
//! 本阶段只做抽取（产出英文主目录）；改写调用点为 LANG/LANGU 是后续阶段。

use anyhow::{Context as _, Result};
use std::collections::HashSet;
use std::path::Path;

use dm::ast::{AssignOp, BinaryOp, Expression, Follow, Statement, Term};

use crate::catalog::Catalog;
use crate::keys::{make_key, namespace_for};

/// 视为玩家可见的变量名。
/// message_* 系列是 /datum/emote 的各形态表情模板（人形/默剧/外星/AI/机器人等），玩家在聊天
/// 高频可见；它们是 var 赋值而非 sink 调用，靠抽取进目录 + /datum/emote/New() 整串反查落地。
const SINK_VARS: &[&str] = &[
    "name",
    "desc",
    "message",
    "flavor_text",
    "title",
    // 其它可靠的玩家可见显示字段（type 变量；非 desc 的别名 / 专有显示串）。
    "description",      // /datum/reagent 等用 description（非 desc）——之前完全漏抽。
    "taste_description", // 试剂味道（"It tastes of …"）。
    "display_name",     // 机器/发射台等的展示名。
    "wiki_desc",        // wiki 界面描述。
    "war_declaration",  // 核弹战争宣言（全员公告）。
    "explanation_text", // /datum/objective 反派目标文本（反派面板 + 授予时聊天）。
    // /datum/personality 玩法效果行（特质与个性→人格 tab 卡片里的 ±/+/- 描述；经偏好常量 asset 渲染，
    // 由 master_files/code/modules/client/preferences/assets.dm 的 lang_reverse_pref_descriptions 反查）。
    "pos_gameplay_desc",
    "neg_gameplay_desc",
    "neut_gameplay_desc",
    // ② 类「type 变量里的整条消息，经 to_chat 发出」——多为 span_*() 包裹，抽取得到内层文本，
    // 运行时靠聊天 AC 子串层（I18N_CHAT_FALLBACK）在包裹串里命中替换（整串反查会因 span 包裹不匹配）。
    "gain_text",        // 脑创伤等获得时消息（45 处）。
    "lose_text",        // 失去时消息。
    "playstyle_string", // 特殊角色玩法说明。
    // /datum/disease 玩家可见字段（医疗/疫病 UI）。
    "cure_text",
    "spread_text",
    // 书本初始标题/正文（/obj/item/book/manual 等；运行时在 book.dm Initialize 整串反查落地）。
    "starting_title",
    "starting_content",
    // 说话动词（says/asks/exclaims/whispers/sings/yells 及各 mob 变体如 beeps/signs/hisses；
    // 运行时在 say.dm 的 say_quote 整串反查落地）。
    "verb_say",
    "verb_ask",
    "verb_exclaim",
    "verb_whisper",
    "verb_sing",
    "verb_yell",
    // /datum/emote 表情模板变体。
    "message_mime",
    "message_alien",
    "message_larva",
    "message_robot",
    "message_AI",
    "message_monkey",
    "message_animal_or_basic",
    "message_param",
];

/// 「句子型」玩家可见文案启发式：多词自然语句（含空格 + 首字母大写 + 含小写字母 + 无占位符）。
/// 用于把「不在 sink 调用处」的玩家可见静态串（config_entry 公告默认值、具名累加器 examine 句）
/// 抽进目录，靠聊天 AC 子串层翻译。含 {0} 的插值模板排除（那需 LANG 改写、且会被 AC 守卫跳过）。
/// examine 信号处理器（COMSIG_ATOM_EXAMINE）的累加器参数名——`examine_list += "…"` 等，
/// 是 examine 输出、必玩家可见，与裸 `.` 同等处理（全抽 + 改写为 LANG）。
pub fn is_examine_accumulator(id: &str) -> bool {
    matches!(
        id,
        // examine 信号处理器累加器 + 自我检查/体检累加器（combined_msg=自我检查、check_list=肢体伤情，
        // 均 `+= span_*("…")` 拼成 to_chat 的玩家可见体检报告）。
        "examine_list" | "examine_text" | "examine_strings" | "combined_msg" | "check_list"
    )
}

fn is_sentence_like(s: &str) -> bool {
    let s = s.trim();
    s.contains(' ')
        && !s.contains('{')
        && s.chars().next().is_some_and(|c| c.is_ascii_uppercase())
        && s.chars().any(|c| c.is_ascii_lowercase())
}

/// 从 list 字面量里抽「多词字符串值」（用于 /datum/aas_config_entry 的 announcement_lines_map
/// 公告模板：`list("Message" = "%PERSON has signed up as %RANK")`）。取 assoc 的**值**(键如
/// "Message"/"RETA Granted" 不抽)；模板用 %VAR 占位符（含空格、无 {），运行时在 compile_announce
/// 用 lang_reverse_text 整条反查、再做 %VAR 替换。
fn emit_message_list(expr: &Expression, ns: &str, catalog: &mut Catalog) {
    let Expression::Base { term, follow } = expr else {
        return;
    };
    if !follow.is_empty() {
        return;
    }
    let args = match &term.elem {
        Term::List(args) => args,
        Term::Call(name, args) if name == "list" => args,
        _ => return,
    };
    for arg in args.iter() {
        let val_expr = if let Expression::AssignOp { rhs, .. } = arg {
            rhs.as_ref()
        } else {
            arg
        };
        if let Some(t) = build_template(val_expr) {
            if t.contains(' ') && !t.contains('{') {
                emit(catalog, ns, &t);
            }
        }
    }
}

/// 汇聚点 proc 名 -> 其消息参数下标。
fn sink_message_args(name: &str) -> Option<&'static [usize]> {
    match name {
        "to_chat" => Some(&[1]),
        "balloon_alert" => Some(&[1]),
        "visible_message" => Some(&[0, 1, 2]), // [2]=blind_message（盲人可见）。
        "audible_message" => Some(&[0, 1, 3]),
        "say" => Some(&[0]),
        "manual_emote" => Some(&[0]),
        // 提示/对话框（玩家可见）。只取消息+标题；按钮/选项列表/返回值不动，
        // 以免破坏 `if(alert(...) == "Yes")` 之类的比较。alert 取 [0,1,2] 同时覆盖
        // `alert("msg")` 与 `alert(user, msg, title)` 两种写法（非字符串实参会被安全跳过）。
        "alert" => Some(&[0, 1, 2]),
        "input" => Some(&[0, 1, 2]),
        "tgui_alert" => Some(&[1, 2]),
        "tgui_input_list" => Some(&[1, 2]),
        "tgui_input_text" => Some(&[1, 2]),
        "tgui_input_number" => Some(&[1, 2]),
        _ => None,
    }
}

pub fn run(dme: &Path, out: &Path, dry_run: bool) -> Result<()> {
    let mut context = dm::Context::default();
    context.set_print_severity(Some(dm::Severity::Error));

    let pp = dm::preprocessor::Preprocessor::new(&context, dme.to_path_buf())
        .with_context(|| format!("无法打开 .dme: {}", dme.display()))?;
    let indents = dm::indents::IndentProcessor::new(&context, pp);
    let mut parser = dm::parser::Parser::new(&context, indents);
    parser.enable_procs();
    let (fatal, tree) = parser.parse_object_tree_2();
    if fatal {
        anyhow::bail!("DM 解析出现致命错误，无法继续抽取");
    }

    // pass 1：收集纯函数 proc 名（与 rewrite 一致，按名跳过以覆盖继承纯度的子类型实现）。
    let mut pure_procs: HashSet<String> = HashSet::new();
    for ty in tree.iter_types() {
        for (proc_name, type_proc) in ty.procs.iter() {
            for proc_value in type_proc.value.iter() {
                if let Some(block) = &proc_value.code {
                    if block_is_pure(block) {
                        pure_procs.insert(proc_name.clone());
                    }
                }
            }
        }
    }

    let mut catalog = Catalog::new();
    for ty in tree.iter_types() {
        let namespace = namespace_for(&ty.path);

        // 1) 变量初始化（name/desc 等）。
        for (var_name, type_var) in ty.vars.iter() {
            let is_sink = SINK_VARS.contains(&var_name.as_str());
            // config_entry 的 default：玩家可见公告/模板（安全等级公告、提示等，从配置加载、非 sink 调用）。
            // 仅 /datum/config_entry 类型且「句子型」default 才抽，避开数字/标志/路径等非显示默认值。
            let is_config_default =
                var_name == "default" && ty.path.starts_with("/datum/config_entry");
            // aas_config_entry 的公告模板（list，含 %VAR 占位符的玩家可见公告）。
            let is_aas_template = var_name == "announcement_lines_map"
                && ty.path.starts_with("/datum/aas_config_entry");
            if !is_sink && !is_config_default && !is_aas_template {
                continue;
            }
            if let Some(expr) = &type_var.value.expression {
                if is_aas_template {
                    emit_message_list(expr, &namespace, &mut catalog);
                    continue;
                }
                if let Some(template) = build_template(expr) {
                    if is_config_default && !is_sentence_like(&template) {
                        continue;
                    }
                    emit(&mut catalog, &namespace, &template);
                }
            }
        }

        // 2) proc 体内的汇聚点调用（跳过纯函数名的 proc）。
        for (proc_name, type_proc) in ty.procs.iter() {
            if pure_procs.contains(proc_name) {
                continue;
            }
            for proc_value in type_proc.value.iter() {
                if let Some(block) = &proc_value.code {
                    visit_block(block, &namespace, &mut catalog);
                }
            }
        }
    }

    // 3) strings/ flavor 数据文件（tips/ion_laws/junkmail…）并入主目录的 `strings` 命名空间，
    //    使其与 sink/SINK_VARS 走同一翻译界面（运行时在 load 处反查落地，见 _string_lists.dm /
    //    type2type.dm）。strings 根目录由 out（.../strings/i18n/en）回推两级得到。
    if let Some(strings_root) = out.parent().and_then(|p| p.parent()) {
        extract_flavor(strings_root, &mut catalog);
    }

    eprintln!(
        "抽取 {} 条字符串，{} 个命名空间",
        catalog.entry_count(),
        catalog.namespace_count()
    );
    if !dry_run {
        // 合并已存在目录：保留已被 rewrite 改写（源码里已不是字面量）的 key（重同步必需）。
        catalog.load_dir(out);
        catalog.write(out)?;
        eprintln!(
            "已写入英文主目录: {}（合并后 {} 条）",
            out.display(),
            catalog.entry_count()
        );
    }
    Ok(())
}

/// 该 proc 是否标了 `set SpacemanDMM_should_be_pure`（与 rewrite.rs 一致，跳过不抽取）。
fn block_is_pure(block: &[dm::ast::Spanned<Statement>]) -> bool {
    block.iter().any(|s| {
        matches!(&s.elem, Statement::Setting { name, .. } if name.as_str() == "SpacemanDMM_should_be_pure")
    })
}

fn emit(catalog: &mut Catalog, namespace: &str, template: &str) {
    if !template.chars().any(|c| c.is_alphabetic()) {
        return;
    }
    let key = make_key(namespace, template);
    catalog.insert(namespace, &key, template);
}

// ---- strings/ flavor 数据文件抽取 ----
//
// 只纳入**展示型 flavor**（整句/整段，玩家直接看到）。**不纳入**关键词表 / 文本变换表 /
// 名字生成器（如 phobia 触发词、heckacious 替换表、pirates/exodrone/arcade 名字片段、口音表、
// names/、词频表）——它们要么是功能性匹配会被翻译破坏，要么是会因语序错乱的生成器片段。
// 运行时**不需要白名单**：load 处对所有 strings 文件跑反查，但只有这里抽进目录的串才会命中改写，
// 其余天然 no-op（再加多词门槛防单词误伤）。逐字保留（含前导 @/% 与 @pick(...) 宏、HTML），
// 与运行时 file2list/json_load 拿到的串一致，反查才命中；译者须保留这些 token。
const FLAVOR_FILES: &[&str] = &[
    "tips.txt",
    "sillytips.txt",
    "chemistrytips.txt",
    "fishing_tips.txt",
    "junkmail.txt",
    "abductee_objectives.txt",
    "bane.json",
    "boomer.json",
    "eigenstasium.json",
    "mother.json",
    "ninja.json",
    "flavor_reports.json",
    "memories.json",
];

/// 递归纳入其下所有 .json 的 flavor 子目录。
const FLAVOR_DIRS: &[&str] = &["antagonist_flavor", "wounds"];

fn extract_flavor(strings_root: &Path, catalog: &mut Catalog) {
    for name in FLAVOR_FILES {
        extract_flavor_file(&strings_root.join(name), catalog);
    }
    for dir in FLAVOR_DIRS {
        if let Ok(entries) = std::fs::read_dir(strings_root.join(dir)) {
            for entry in entries.flatten() {
                extract_flavor_file(&entry.path(), catalog);
            }
        }
    }
}

fn extract_flavor_file(path: &Path, catalog: &mut Catalog) {
    let Ok(text) = std::fs::read_to_string(path) else {
        return;
    };
    match path.extension().and_then(|s| s.to_str()) {
        Some("txt") => {
            // 逐非空行（trim，与 file2list 默认 trim=TRUE 一致）。
            for line in text.lines() {
                let line = line.trim();
                if !line.is_empty() {
                    emit(catalog, "strings", line);
                }
            }
        }
        Some("json") => {
            if let Ok(value) = serde_json::from_str::<serde_json::Value>(&text) {
                collect_json_strings(&value, catalog);
            }
        }
        _ => {}
    }
}

/// 递归取 JSON 的字符串叶子（数组元素 / 关联值）；key 不取（程序标识）。
fn collect_json_strings(value: &serde_json::Value, catalog: &mut Catalog) {
    match value {
        serde_json::Value::String(s) => {
            let s = s.trim();
            if !s.is_empty() {
                emit(catalog, "strings", s);
            }
        }
        serde_json::Value::Array(arr) => {
            for v in arr {
                collect_json_strings(v, catalog);
            }
        }
        serde_json::Value::Object(map) => {
            for v in map.values() {
                collect_json_strings(v, catalog);
            }
        }
        _ => {}
    }
}

// ---- 语句/表达式遍历：找到汇聚点调用 ----

fn visit_block(block: &[dm::ast::Spanned<Statement>], ns: &str, catalog: &mut Catalog) {
    for stmt in block.iter() {
        visit_stmt(&stmt.elem, ns, catalog);
    }
}

fn visit_stmt(stmt: &Statement, ns: &str, catalog: &mut Catalog) {
    match stmt {
        Statement::Expr(e) => visit_expr(e, ns, catalog),
        Statement::Return(Some(e)) => visit_expr(e, ns, catalog),
        Statement::While { condition, block } => {
            visit_expr(condition, ns, catalog);
            visit_block(block, ns, catalog);
        }
        Statement::If { arms, else_arm } => {
            for (cond, blk) in arms.iter() {
                visit_expr(&cond.elem, ns, catalog);
                visit_block(blk, ns, catalog);
            }
            if let Some(blk) = else_arm {
                visit_block(blk, ns, catalog);
            }
        }
        Statement::ForInfinite { block } => visit_block(block, ns, catalog),
        Statement::ForLoop {
            init,
            test,
            inc,
            block,
        } => {
            if let Some(s) = init {
                visit_stmt(s, ns, catalog);
            }
            if let Some(e) = test {
                visit_expr(e, ns, catalog);
            }
            if let Some(s) = inc {
                visit_stmt(s, ns, catalog);
            }
            visit_block(block, ns, catalog);
        }
        Statement::Switch {
            input,
            cases,
            default,
        } => {
            visit_expr(input, ns, catalog);
            // 修复：之前 `..` 漏掉了 cases —— switch 各 case 分支体里的语句全部没被抽取。
            for (_case_conditions, blk) in cases.iter() {
                visit_block(blk, ns, catalog);
            }
            if let Some(blk) = default {
                visit_block(blk, ns, catalog);
            }
        }
        Statement::Spawn { delay, block } => {
            if let Some(e) = delay {
                visit_expr(e, ns, catalog);
            }
            visit_block(block, ns, catalog);
        }
        Statement::Var(v) => {
            if let Some(e) = &v.value {
                visit_expr(e, ns, catalog);
            }
        }
        Statement::Vars(vs) => {
            for v in vs.iter() {
                if let Some(e) = &v.value {
                    visit_expr(e, ns, catalog);
                }
            }
        }
        Statement::Setting { value, .. } => visit_expr(value, ns, catalog),
        _ => {}
    }
}

fn visit_expr(expr: &Expression, ns: &str, catalog: &mut Catalog) {
    match expr {
        Expression::Base { term, follow } => {
            // 汇聚点调用检测。
            if let Term::Call(name, args) = &term.elem {
                if let Some(indices) = sink_message_args(name.as_str()) {
                    for &i in indices {
                        if let Some(arg) = args.get(i) {
                            if let Some(template) = build_template(arg) {
                                emit(catalog, ns, &template);
                            }
                        }
                    }
                }
            }
            // input() 是专用 Term::Input（非 Call），与 rewrite 保持一致地抽取其消息/标题。
            if let Term::Input { args, .. } = &term.elem {
                if let Some(indices) = sink_message_args("input") {
                    for &i in indices {
                        if let Some(arg) = args.get(i) {
                            if let Some(template) = build_template(arg) {
                                emit(catalog, ns, &template);
                            }
                        }
                    }
                }
            }
            recurse_term(&term.elem, ns, catalog);
            for f in follow.iter() {
                recurse_follow(&f.elem, ns, catalog);
            }
        }
        Expression::BinaryOp { lhs, rhs, .. } => {
            visit_expr(lhs, ns, catalog);
            visit_expr(rhs, ns, catalog);
        }
        Expression::AssignOp { op, lhs, rhs } => {
            // examine / 消息累加：`. += <text>`（裸 `.`）原样抽；具名累加器（combined_msg += span_*("…")
            // 等，self-examine、descriptor 等）仅抽「静态句子型」串供聊天 AC 兜底——span 是宏、AST 判不出
            // 包裹，故用内容启发式；插值模板(含 {0})排除（那需 LANG 改写）。
            if matches!(op, AssignOp::AddAssign) {
                if let Expression::Base { term, follow } = lhs.as_ref() {
                    if follow.is_empty() {
                        if let Term::Ident(id) = &term.elem {
                            if let Some(template) = build_template(rhs) {
                                // 裸 `.` 与 examine 信号处理器的累加器（examine_list/text/strings）：
                                // examine 输出，必玩家可见 → 全抽（含插值，供 LANG）。其它具名累加器只抽静态句供 AC。
                                if id == "." || is_examine_accumulator(id) {
                                    emit(catalog, ns, &template);
                                } else if is_sentence_like(&template) {
                                    emit(catalog, ns, &template);
                                }
                            }
                        }
                    }
                }
            }
            visit_expr(lhs, ns, catalog);
            visit_expr(rhs, ns, catalog);
        }
        Expression::TernaryOp {
            cond, if_, else_, ..
        } => {
            visit_expr(cond, ns, catalog);
            visit_expr(if_, ns, catalog);
            visit_expr(else_, ns, catalog);
        }
    }
}

fn recurse_term(term: &Term, ns: &str, catalog: &mut Catalog) {
    match term {
        Term::Expr(e) => visit_expr(e, ns, catalog),
        Term::InterpString(_, parts) => {
            for (opt, _) in parts.iter() {
                if let Some(e) = opt {
                    visit_expr(e, ns, catalog);
                }
            }
        }
        Term::Call(_, args)
        | Term::SelfCall(args)
        | Term::ParentCall(args)
        | Term::List(args)
        | Term::GlobalCall(_, args) => {
            for a in args.iter() {
                visit_expr(a, ns, catalog);
            }
        }
        Term::DynamicCall(a, b) => {
            for e in a.iter() {
                visit_expr(e, ns, catalog);
            }
            for e in b.iter() {
                visit_expr(e, ns, catalog);
            }
        }
        Term::NewImplicit { args } | Term::NewPrefab { args, .. } | Term::NewMiniExpr { args, .. } => {
            if let Some(args) = args {
                for e in args.iter() {
                    visit_expr(e, ns, catalog);
                }
            }
        }
        Term::Input { args, in_list, .. } => {
            for e in args.iter() {
                visit_expr(e, ns, catalog);
            }
            if let Some(e) = in_list {
                visit_expr(e, ns, catalog);
            }
        }
        Term::Locate { args, in_list } => {
            for e in args.iter() {
                visit_expr(e, ns, catalog);
            }
            if let Some(e) = in_list {
                visit_expr(e, ns, catalog);
            }
        }
        Term::ExternalCall {
            library,
            function,
            args,
        } => {
            if let Some(e) = library {
                visit_expr(e, ns, catalog);
            }
            visit_expr(function, ns, catalog);
            for e in args.iter() {
                visit_expr(e, ns, catalog);
            }
        }
        _ => {}
    }
}

fn recurse_follow(follow: &Follow, ns: &str, catalog: &mut Catalog) {
    match follow {
        Follow::Index(_, e) => visit_expr(e, ns, catalog),
        Follow::Call(_, name, args) => {
            // 方法调用形式的汇聚点（`user.visible_message(...)`/`src.say(...)`/`M.balloon_alert(...)` 等）。
            // 此前只检测裸调用 `Term::Call`，漏掉了大量 `X.sink(...)` 形式（战斗/交互可见消息多为此形）。
            if let Some(indices) = sink_message_args(name.as_str()) {
                for &i in indices {
                    if let Some(arg) = args.get(i) {
                        if let Some(template) = build_template(arg) {
                            emit(catalog, ns, &template);
                        }
                    }
                }
            }
            for a in args.iter() {
                visit_expr(a, ns, catalog);
            }
        }
        _ => {}
    }
}

// ---- 占位符模板构建 ----

/// 把一个表达式（字符串/内插串/字符串拼接）转为带 {0}/{1} 占位符的模板。
/// 非文本（纯变量/调用）返回 None。整体无字母（纯标签/标点）也返回 None。
///
/// 注意：本函数是「抽取 key」与「改写 key」的**唯一真相来源**（rewrite.rs 也调用它），
/// 二者必须用同一函数算 key 才能保证目录命中。
pub(crate) fn build_template(expr: &Expression) -> Option<String> {
    let mut out = String::new();
    let mut idx = 0usize;
    let is_text = render(expr, &mut out, &mut idx);
    // 整体去标签后需含字母，避免把纯标签/纯占位符当作可翻译文本。
    if is_text && strip_tags(&out).chars().any(|c| c.is_alphabetic()) {
        Some(out)
    } else {
        None
    }
}

/// 模板里的占位符个数（{0}/{1}… 顺序生成，这里数 `{` 紧跟数字的出现次数）。
pub(crate) fn placeholder_count(template: &str) -> usize {
    let b = template.as_bytes();
    let mut n = 0usize;
    let mut i = 0usize;
    while i + 1 < b.len() {
        if b[i] == b'{' && b[i + 1].is_ascii_digit() {
            n += 1;
        }
        i += 1;
    }
    n
}

/// 返回该表达式是否为「文本节点」（字符串/内插/字符串相加，含括号包裹）。
/// - 独立字符串字面量：纯标签/纯标点（去标签后无字母）丢弃（如 span 包裹），否则原样写入；
/// - 内插串：lead 与各段字面量**原样**写入（保留 "!" 等标点），内插表达式写成 {N}；
/// - 其余（变量、调用、带 follow 取值等）：在拼接语境里写成 {N} 占位符并返回 false。
fn render(expr: &Expression, out: &mut String, idx: &mut usize) -> bool {
    match expr {
        Expression::Base { term, follow } if follow.is_empty() => match &term.elem {
            Term::String(s) => {
                // 独立字符串：仅当去标签后含字母才保留（丢弃 span 包裹、纯标点独立串）。
                if strip_tags(s).chars().any(|c| c.is_alphabetic()) {
                    out.push_str(s);
                }
                true
            }
            Term::InterpString(lead, parts) => {
                out.push_str(lead.as_str());
                for (opt, lit) in parts.iter() {
                    if opt.is_some() {
                        out.push_str(&format!("{{{}}}", *idx));
                        *idx += 1;
                    }
                    out.push_str(lit);
                }
                true
            }
            // 括号包裹（如 span_* 宏展开为 ("<span>" + str + "</span>")）：穿透进去。
            Term::Expr(inner) => render(inner, out, idx),
            _ => {
                out.push_str(&format!("{{{}}}", *idx));
                *idx += 1;
                false
            }
        },
        Expression::BinaryOp {
            op: BinaryOp::Add,
            lhs,
            rhs,
        } => {
            let l = render(lhs, out, idx);
            let r = render(rhs, out, idx);
            l || r
        }
        _ => {
            out.push_str(&format!("{{{}}}", *idx));
            *idx += 1;
            false
        }
    }
}

/// 去掉 `<...>` 标签后的文本（用于判断片段是否只是标签）。
pub(crate) fn strip_tags(s: &str) -> String {
    let mut result = String::new();
    let mut in_tag = false;
    for c in s.chars() {
        match c {
            '<' => in_tag = true,
            '>' => in_tag = false,
            _ if !in_tag => result.push(c),
            _ => {}
        }
    }
    result
}
