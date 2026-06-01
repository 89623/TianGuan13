#!/usr/bin/env bash
# NovaSector 全量汉化：用 Codex 把英文主目录翻译成简体中文。
#
# 使用你 Codex 的默认模型（如 gpt-5.5 xhigh）。增量翻译：只补译 zh-Hans 里尚缺的 key。
# 用法：
#   bash tools/i18n/mt/translate-codex.sh            # 翻译全部命名空间文件
#   bash tools/i18n/mt/translate-codex.sh obj.json   # 只翻译指定文件
#
# 注意：obj.json/datum.json 较大（MB 级），Codex 可能需要自行分块；如遇上下文超限，
# 可先用 tools/i18n 的命名空间拆分，或对单文件分批运行。
set -euo pipefail
cd "$(dirname "$0")/../../.."

SRC=strings/i18n/en
DST=strings/i18n/zh-Hans
GLOSSARY=tools/i18n/mt/glossary.zh-Hans.json
mkdir -p "$DST"

if ! command -v codex >/dev/null 2>&1; then
  echo "未找到 codex CLI。请先安装并登录 Codex。" >&2
  exit 1
fi

files=("$@")
if [ ${#files[@]} -eq 0 ]; then
  mapfile -t files < <(cd "$SRC" && ls ./*.json | sed 's#^\./##')
fi

for f in "${files[@]}"; do
  echo "==> 翻译 $f"
  codex exec "你是 Space Station 13 游戏文本的专业本地化译者。\
请把 $SRC/$f 中的英文值翻译为简体中文，写入 $DST/$f：\
(1) key 完全保持不变；\
(2) 逐字保留所有 {0}/{1}… 占位符与 HTML 标签（如 <b> <br> <span>）以及 DM 文本宏（如 \\improper、\\the）；\
(3) 遵循术语表 $GLOSSARY；\
(4) 若 $DST/$f 已存在，只补译其中缺失的 key，不要改动已有译文；\
(5) 输出合法 JSON，保持与源文件相同的 key 顺序与缩进。"
done

echo "完成。请人工抽检后提交 $DST（也可导入 Tolgee 做团队校对，见 tolgee.config.ts）。"
