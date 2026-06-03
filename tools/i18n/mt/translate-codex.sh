#!/usr/bin/env bash
# NovaSector 全量汉化：翻译入口（薄 shim，转交 bun i18n-mt.ts）。
#
# 全部逻辑（后端选择 codex/claude/openai、前置检查、.env 加载、待译计算/分批/并发/术语表/合并）
# 都在 i18n-mt.ts 里——用法、后端、环境变量见 i18n-mt.ts 顶部注释与 tools/i18n/mt/.env.example。
#
#   bash tools/i18n/mt/translate-codex.sh                 # 全部命名空间（默认 translate）
#   bash tools/i18n/mt/translate-codex.sh tgui.json       # 指定文件
#   bash tools/i18n/mt/translate-codex.sh pending         # 只看待译（不调模型）
#   I18N_BACKEND=openai OPENAI_API_KEY=sk-... bash tools/i18n/mt/translate-codex.sh
# 配置可写进 tools/i18n/mt/.env（cp .env.example .env），免去每次手敲。
set -euo pipefail
exec bun "$(cd "$(dirname "$0")" && pwd)/i18n-mt.ts" "$@"
