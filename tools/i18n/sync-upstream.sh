#!/usr/bin/env bash
# NovaSector 汉化分支：一键同步上游。
#
# 流程：fetch → 把 origin/master（已被 GitHub 自动追上游）merge 进当前 i18n 分支
#       → 跑 resync.sh（重抽取英文目录 + 幂等改写新字符串）→ 编译验证。
#
# 不自动 commit：合并 + 重同步产物由你 review 后再提交。
# 翻译源目录、术语表和 TGUI 同步出的运行时目录都属于可提交产物。
#
# 用法：
#   bash tools/i18n/sync-upstream.sh          # 全流程（含编译）
#   SYNC_BUILD=0 bash tools/i18n/sync-upstream.sh   # 跳过编译（快速看合并结果）
#
# 合并出现冲突时脚本会停下并打印解决策略；解决并 commit 后**再次运行本脚本**即可继续。
set -euo pipefail
cd "$(dirname "$0")/../.."

BRANCH="feat/i18n-localization"
UPSTREAM_REF="origin/master"        # 你的 master 已由 GitHub 自动同步上游，直接合它即可
RUN_BUILD="${SYNC_BUILD:-1}"

# ── 0. 前置检查 ─────────────────────────────────────────────
cur="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$cur" != "$BRANCH" ]]; then
	echo "!! 当前在 '$cur'，本脚本预期在 '$BRANCH'。先切过去：git checkout $BRANCH" >&2
	exit 1
fi
if [[ -e .git/MERGE_HEAD ]]; then
	echo "!! 有未完成的合并。先解决冲突并 'git commit'（或 'git merge --abort'）后再跑。" >&2
	exit 1
fi
# 这些是机器本地文件，不属于同步提交，始终处于「脏」态属正常，不应阻塞同步。
# 同时用 --untracked-files=no 跳过未跟踪扫描：既不被本脚本自身/新建文件绊住，
# 也顺带跳过 root 所有的 tolgee-* 残留目录（自托管 Tolgee 已弃用），免去权限警告。
LOCAL_EXCLUDES=(
	':!.vscode/settings.json'
	':!config/admins.txt'
)
dirty="$(git status --porcelain --untracked-files=no -- "${LOCAL_EXCLUDES[@]}")"
if [[ -n "$dirty" ]]; then
	echo "!! 工作区有未提交改动（已忽略机器本地文件）。先 commit 或 stash，避免和合并/重同步混在一起：" >&2
	echo "$dirty" >&2
	exit 1
fi

# ── 1. fetch ───────────────────────────────────────────────
echo "==> git fetch origin --prune"
git fetch origin --prune

behind="$(git rev-list --count "HEAD..$UPSTREAM_REF")"
echo "==> $UPSTREAM_REF 领先当前分支 $behind 个提交"
if [[ "$behind" == "0" ]]; then
	echo "    已追平上游；仍会跑一次 resync 以防本地源码有未抽取的字符串。"
fi

# ── 2. 合并上游 ─────────────────────────────────────────────
if [[ "$behind" != "0" ]]; then
	echo "==> 合并 $UPSTREAM_REF"
	if git merge --no-edit "$UPSTREAM_REF"; then
		echo "==> 合并干净。"
	else
		echo >&2
		echo "!! 合并有冲突。按下面策略解决，然后【再次运行本脚本】（会继续 resync）：" >&2
		echo "   · codemod 行 LANG(...) 与上游英文文案冲突 → 取上游(theirs)，resync 会重新 LANG 化：" >&2
		echo "       git checkout --theirs <文件> && git add <文件>" >&2
		echo "   · 你手写的核心 i18n 改动(lang_reverse_* 包裹等)冲突 → 手动保留你的逻辑，别盲取 theirs。" >&2
		echo "   · 冲突文件：" >&2
		git --no-pager diff --name-only --diff-filter=U | sed 's/^/       /' >&2
		echo "   解决后：git commit，然后重新运行 $0" >&2
		exit 1
	fi
fi

# ── 3. 重同步（抽取英文目录 + 幂等改写）─────────────────────
echo "==> 运行 tools/i18n/resync.sh"
bash tools/i18n/resync.sh

# ── 4. 编译验证 ─────────────────────────────────────────────
if [[ "$RUN_BUILD" == "1" ]]; then
	echo "==> 编译验证（SYNC_BUILD=0 可跳过）"
	tools/build/build.sh
fi

# ── 5. 收尾提示 ─────────────────────────────────────────────
echo
echo "==> 同步完成。待提交改动："
git --no-pager status --short
cat <<'EOF'

下一步：
  1. review 上面的 diff（合并 commit + resync 产生的英文目录刷新/新 LANG 改写）。
  2. i18n 产物均可提交，包括：
       strings/i18n/en/*.json
       strings/i18n/zh-Hans/*.json
       tools/i18n/mt/glossary.zh-Hans.json
       tgui/packages/tgui/i18n/*.json
     只排除这些机器本地文件：
       .vscode/settings.json
       config/admins.txt
  3. 翻译新增英文条目： bun tools/i18n/mt/i18n-mt.ts   （默认只补缺失）
  4. 重新构建起服。
EOF
