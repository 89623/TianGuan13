#!/usr/bin/env bash
# NovaSector 全量汉化：i18n 重同步。
#
# 合并上游之后 / 定期运行：刷新英文主目录，并把「新出现的」玩家可见字符串改写为 LANG()。
# rewrite 是幂等的——已改写的调用点不会被再次改写，所以可反复安全运行。
#
# 分工（重要）：本脚本只负责「让新串变得可翻译」——extract 抽英文进目录、rewrite 用**内容哈希
# key** 把新 sink 包成 LANG()。这两步是确定性的、无法用「让 AI 直接改」替代（AI 扫不全整库、
# 也写不出哈希 key）。真正的**翻译**（en→zh）是随后单独的一步（`bun tools/i18n/mt/i18n-mt.ts`
# 或人工）。脚本结尾会打印「翻译覆盖率」告诉你 extract 之后还差哪些。
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
# cargo build 在 nix develop 之外常因 rustup 链接器损坏而失败。若已有预编译二进制则容错沿用，
# 不让整个 resync 因构建环境问题而硬崩。
if ! cargo build --release --manifest-path tools/i18n/Cargo.toml; then
	if [[ -x "$TOOL" ]]; then
		echo "!! cargo build 失败——沿用已有预编译二进制 $TOOL（若本机非 nix develop，链接器报错属常见）。" >&2
		echo "   如需最新工具，请在 'nix develop' 环境内重跑本脚本。" >&2
	else
		echo "!! cargo build 失败且无预编译二进制：请在 'nix develop' 内运行，或先手动构建 nova-i18n。" >&2
		exit 1
	fi
fi

echo "==> 刷新英文主目录 strings/i18n/en（含 DM sink/SINK_VARS + strings/ flavor 数据 → strings.json）"
"$TOOL" extract --dme tgstation.dme --out strings/i18n/en

echo "==> 刷新 DM 显示标签 tools/i18n/dm_labels.json（AST：choiced 选项/类型作用域 name/全局 list）"
"$TOOL" labels --dme tgstation.dme

echo "==> 刷新 TGUI 静态文本目录 strings/i18n/en/tgui.json（含上一步的 AST 标签 + JSX 文本）"
node tools/i18n/tgui-catalog.mjs extract

echo "==> 抑制纯重排噪音（还原语义无变化、仅顺序不同的目录文件；手维护 _*.json 不再刷屏）"
node tools/i18n/suppress-reorder.mjs

echo "==> 改写新出现的纯字符串消息为 LANG()（幂等；核心文件自动加 NOVA EDIT 标记）"
"$TOOL" rewrite --dme tgstation.dme

echo "==> i18n lint（建议性）：目录卫生 + 标识符碰撞静态分析。"
echo "    上游新代码可能引入新的「标识符 ↔ 可翻译值」碰撞（StripMenu 蓝屏 / 出生点错位类）。"
echo "    新增高置信碰撞会以非零码报告——请逐条判断后，确认安全的用 --update-baseline 收进基线。"
"$TOOL" lint --dme tgstation.dme --catalog strings/i18n --locale zh-Hans \
	--baseline tools/i18n/identifier-baseline.txt || echo "    （lint 有发现，见上；不阻断 resync。）"

echo "==> 翻译覆盖率（extract 之后还差哪些 zh 译文）"
node tools/i18n/coverage.mjs

echo "==> 完成。review 上面的 git diff 后提交；随后翻译新增英文条目："
echo "      bun tools/i18n/mt/i18n-mt.ts        # 默认只补缺失；或人工补译（遵循 glossary / keep-english）"
git --no-pager diff --stat | tail -20
