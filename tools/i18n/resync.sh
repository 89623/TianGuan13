#!/usr/bin/env bash
# NovaSector 全量汉化：i18n 重同步。
#
# 合并上游之后 / 定期运行：刷新英文主目录，并把「新出现的」玩家可见字符串改写为 LANG()。
# rewrite 是幂等的——已改写的调用点不会被再次改写，所以可反复安全运行。
#
# 合并上游冲突的处理策略（配合自动合并机器人）：
#   1. 正常 `git merge upstream/master`；
#   2. 对「i18n 改写行」(LANG(...)) 的冲突，一律取「上游原始英文版本」(theirs/upstream)；
#   3. 运行本脚本 —— extract 会把上游新字符串补进英文目录，rewrite 会把它们重新改写为 LANG()；
#   4. 提交结果。如此上游改动与本地 i18n 层可确定性地自动合流。
set -euo pipefail
cd "$(dirname "$0")/../.."

TOOL=tools/i18n/target/release/nova-i18n

echo "==> 构建 nova-i18n"
cargo build --release --manifest-path tools/i18n/Cargo.toml

echo "==> 刷新英文主目录 strings/i18n/en（含 DM sink/SINK_VARS + strings/ flavor 数据 → strings.json）"
"$TOOL" extract --dme tgstation.dme --out strings/i18n/en

echo "==> 刷新 DM 显示标签 tools/i18n/dm_labels.json（AST：choiced 选项/类型作用域 name/全局 list）"
"$TOOL" labels --dme tgstation.dme

echo "==> 刷新 TGUI 静态文本目录 strings/i18n/en/tgui.json（含上一步的 AST 标签 + JSX 文本）"
node tools/i18n/tgui-catalog.mjs extract

echo "==> 改写新出现的纯字符串消息为 LANG()（幂等；核心文件自动加 NOVA EDIT 标记）"
"$TOOL" rewrite --dme tgstation.dme

echo "==> i18n lint（建议性）：目录卫生 + 标识符碰撞静态分析。"
echo "    上游新代码可能引入新的「标识符 ↔ 可翻译值」碰撞（StripMenu 蓝屏 / 出生点错位类）。"
echo "    新增高置信碰撞会以非零码报告——请逐条判断后，确认安全的用 --update-baseline 收进基线。"
"$TOOL" lint --dme tgstation.dme --catalog strings/i18n --locale zh-Hans \
	--baseline tools/i18n/identifier-baseline.txt || echo "    （lint 有发现，见上；不阻断 resync。）"

echo "==> 完成。请检查 git diff 后提交；随后用 Codex 把 strings/i18n/en 的新增项翻译到 zh-Hans。"
git --no-pager diff --stat | tail -20
