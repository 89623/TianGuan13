#!/usr/bin/env bash
# 中文指令名（verb 命令面板）构建。
#
# verb 名是 BYOND **编译期**元数据，无法像其它文本那样运行时按 I18N_SERVER_LOCALE 切换
# （config 管不到它）。仓库源码因此保持**英文**（默认态，普通 build.sh 产物=英文指令）；
# 想要中文命令面板时用本脚本：注入译文 → 编译 → 还原源码。
# 产物 tgstation.dmb 带中文 verb 名；源码/git 状态不留痕（失败也会还原，见 trap）。
#
# 用法：bash tools/i18n/build-verbs-zh.sh
#   可选 I18N_VERBS_LOCALE=zh-Hans（默认）。需先 extract + 翻译过 verb 名。
set -euo pipefail
cd "$(dirname "$0")/../.."

LOCALE="${I18N_VERBS_LOCALE:-zh-Hans}"
BIN=tools/i18n/target/release/nova-i18n
if [ ! -x "$BIN" ]; then
	(cd tools/i18n && cargo build --release)
fi

revert() { "$BIN" verbs --locale "$LOCALE" --revert; }
trap revert EXIT

"$BIN" verbs --locale "$LOCALE"
tools/build/build.sh dm
