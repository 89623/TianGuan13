#!/usr/bin/env bash
# NovaSector 全量汉化：增量翻译（薄封装，转交 i18n-mt.ts）。可选三种后端。
#
# 只翻「待译」的条目（缺失 / 未译 / 中英混杂），大文件自动分批，断点续译。
#   bash tools/i18n/mt/translate-codex.sh                 # 全部命名空间
#   bash tools/i18n/mt/translate-codex.sh obj.json        # 指定文件
#   bash tools/i18n/mt/translate-codex.sh translate-terms obj.json # 只修术语不一致
#   bun tools/i18n/mt/i18n-mt.ts pending                  # 先看哪里待译（不调用模型）
#   bun tools/i18n/mt/i18n-mt.ts terms                    # 先看哪里术语不一致（不调用模型）
#
# 后端（I18N_BACKEND，默认 codex）：
#   codex   —— Codex CLI（agent 写文件）。需 codex 已登录。
#   claude  —— Claude Code CLI（agent 写文件，`claude -p`）。需 claude 已登录；可选 I18N_CLAUDE_MODEL。
#   openai  —— OpenAI 兼容 API（HTTP 返回 JSON，无需 CLI）。需 OPENAI_API_KEY；可选 I18N_OPENAI_MODEL
#             （默认 gpt-4o-mini）、I18N_OPENAI_BASE_URL（可指向 DeepSeek/通义/本地 vLLM 等兼容服务）。
#   例：I18N_BACKEND=openai OPENAI_API_KEY=sk-... bash tools/i18n/mt/translate-codex.sh tgui.json
#       I18N_BACKEND=claude bash tools/i18n/mt/translate-codex.sh tgui.json
#
# 优化（默认已开/合理值）：
#   I18N_CONCURRENCY（并发批数；openai 默认 4，agent 默认 1。API 后端调大可显著加速，注意限流/额度）
#   I18N_NO_REUSE=1（关闭「跨命名空间复用」；默认开：同一英文别处已译过就直接套用、不再调模型）
#
# 环境：
#   I18N_LOCALE（默认 zh-Hans）
#   I18N_CHUNK（每批条数；openai 默认 400、agent 默认 200）
#   I18N_MAX_CODEX_CALLS（每次运行最多启动的模型调用数，默认 0 不限；仍然单并发串行）
#   I18N_MAX_AGENTS（兼容旧名，同义于 I18N_MAX_CODEX_CALLS）
#   I18N_CONTINUE_ON_FAIL=1（可选，失败后继续；默认失败即停，避免额度/登录错误时继续开调用）
#   I18N_CODEX_DELAY_MS（可选，每个模型调用之间等待的毫秒数）
#   I18N_FULL_GLOSSARY=1（可选，每批发送完整术语表；默认只发送本批命中的术语）
#   I18N_CODEX_REASONING（codex 默认 low；翻译不需要 xhigh）
#   I18N_CODEX_MODEL / I18N_CLAUDE_MODEL（可选，覆盖各 agent 后端默认模型）
#   I18N_CODEX_STDIO=inherit（可选，恢复 agent 全量输出；默认写入 .pending/*.codex.log）
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/../../.."

# 加载 tools/i18n/mt/.env（若存在）；**已设置的 shell 变量优先**（只填未设置的，不覆盖）。
# i18n-mt.ts 也会各自加载（同样 shell 优先）；这里加载是给本脚本 bash 层的后端检查用。
# 复制 .env.example 为 .env 填好即可，免去每次手敲。
if [ -f "$SCRIPT_DIR/.env" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}" # 去左侧空白
    case "$line" in '' | '#'*) continue ;; esac
    key="${line%%=*}"
    val="${line#*=}"
    key="$(printf '%s' "$key" | tr -d '[:space:]')"
    [ -z "$key" ] && continue
    val="${val#\"}"; val="${val%\"}"; val="${val#\'}"; val="${val%\'}" # 去两端引号
    [ -z "${!key+x}" ] && export "$key=$val"
  done < "$SCRIPT_DIR/.env"
fi

backend="${I18N_BACKEND:-codex}"

case "${1:-}" in
  pending | terms | term-pending)
    exec bun tools/i18n/mt/i18n-mt.ts "$@"
    ;;
esac

# 按后端检查前置条件（pending/terms 不需要，已在上面 exec）。
case "$backend" in
  codex)
    command -v codex >/dev/null 2>&1 || { echo "未找到 codex CLI。请先安装并登录 Codex（或用 I18N_BACKEND=claude/openai）。" >&2; exit 1; }
    ;;
  claude)
    command -v claude >/dev/null 2>&1 || { echo "未找到 claude CLI。请先安装并登录 Claude Code。" >&2; exit 1; }
    ;;
  openai)
    [ -n "${OPENAI_API_KEY:-${I18N_OPENAI_API_KEY:-}}" ] || { echo "I18N_BACKEND=openai 需设置 OPENAI_API_KEY。" >&2; exit 1; }
    ;;
  *)
    echo "未知 I18N_BACKEND=$backend（可选 codex / claude / openai）。" >&2; exit 1
    ;;
esac

case "${1:-}" in
  translate | translate-terms | repair-terms)
    exec bun tools/i18n/mt/i18n-mt.ts "$@"
    ;;
  *)
    exec bun tools/i18n/mt/i18n-mt.ts translate "$@"
    ;;
esac
