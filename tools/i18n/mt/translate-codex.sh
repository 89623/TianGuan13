#!/usr/bin/env bash
# NovaSector 全量汉化：用 Codex 增量翻译（薄封装，转交 i18n-mt.ts）。
#
# 只翻「待译」的条目（缺失 / 未译 / 中英混杂），大文件自动分批，断点续译。
#   bash tools/i18n/mt/translate-codex.sh                 # 全部命名空间
#   bash tools/i18n/mt/translate-codex.sh obj.json        # 指定文件
#   bash tools/i18n/mt/translate-codex.sh translate-terms obj.json # 只修术语不一致
#   bun tools/i18n/mt/i18n-mt.ts pending                  # 先看哪里待译（不调用 Codex）
#   bun tools/i18n/mt/i18n-mt.ts terms                    # 先看哪里术语不一致（不调用 Codex）
#
# 环境：
#   I18N_LOCALE（默认 zh-Hans）
#   I18N_CHUNK（每批条数，默认 200）
#   I18N_MAX_CODEX_CALLS（每次运行最多启动 Codex 调用数，默认 0 不限；仍然单并发串行）
#   I18N_MAX_AGENTS（兼容旧名，同义于 I18N_MAX_CODEX_CALLS）
#   I18N_CONTINUE_ON_FAIL=1（可选，失败后继续；默认失败即停，避免额度/登录错误时继续开调用）
#   I18N_CODEX_DELAY_MS（可选，每个 Codex 调用之间等待的毫秒数）
#   I18N_FULL_GLOSSARY=1（可选，每批发送完整术语表；默认只发送本批命中的术语）
#   I18N_CODEX_REASONING（默认 low；翻译不需要 xhigh）
#   I18N_CODEX_MODEL（可选，覆盖 codex 默认模型）
#   I18N_CODEX_STDIO=inherit（可选，恢复 Codex 全量输出；默认写入 .pending/*.codex.log）
# 需 codex CLI（自动禁用 MCP）。
set -euo pipefail
cd "$(dirname "$0")/../../.."

case "${1:-}" in
  pending | terms | term-pending)
    exec bun tools/i18n/mt/i18n-mt.ts "$@"
    ;;
esac

if ! command -v codex >/dev/null 2>&1; then
  echo "未找到 codex CLI。请先安装并登录 Codex。" >&2
  exit 1
fi

case "${1:-}" in
  translate | translate-terms | repair-terms)
    exec bun tools/i18n/mt/i18n-mt.ts "$@"
    ;;
  *)
    exec bun tools/i18n/mt/i18n-mt.ts translate "$@"
    ;;
esac
