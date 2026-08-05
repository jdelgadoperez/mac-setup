#!/usr/bin/env bash
# PreToolUse hook: block destructive remote branch deletions
# Blocks: git push <remote> --delete <branch>, git push <remote> -d <branch>,
#         git push <remote> :<branch>, gh api ... DELETE refs/heads/...
# On match, emits a block JSON to stdout; otherwise exits 0 silently.

set -uo pipefail

HOOK_SRC="${BASH_SOURCE[0]}"
while [ -L "$HOOK_SRC" ]; do HOOK_SRC="$(readlink "$HOOK_SRC")"; done
# CDPATH= : cd echoes the resolved dir when it uses CDPATH, which would be
# captured by $( ) and double the path. Harmless for absolute paths, breaks
# relative invocation.
HOOK_DIR="$(CDPATH= cd "$(dirname "$HOOK_SRC")" && pwd)"
# shellcheck source=/dev/null
if [ -r "$HOOK_DIR/../../hook-log.sh" ]; then . "$HOOK_DIR/../../hook-log.sh"; else hook_log() { :; }; fi

# Fail-open on internal errors so hook bugs don't lock the user out
trap 'hook_log block-remote-branch-delete error "internal failure — protection did not run"; exit 0' ERR

INPUT=$(cat)

TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')
if [ "$TOOL" != "Bash" ]; then
  exit 0
fi

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Patterns for remote branch deletion
git_delete_long='git[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+(--delete|-d)[[:space:]]+[^[:space:]]+'
git_delete_colon='git[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+:[^[:space:]]+'

# gh api branch delete: order-agnostic — must contain `gh api`, a DELETE method flag, and `refs/heads/`
is_gh_api_branch_delete() {
  echo "$1" | grep -Eq 'gh[[:space:]]+api([[:space:]]|$)' \
    && echo "$1" | grep -Eq '(--method[[:space:]]+DELETE|-X[[:space:]]+DELETE|-XDELETE)' \
    && echo "$1" | grep -Eq 'refs/heads/'
}

matched_pattern=""
if echo "$CMD" | grep -Eq "$git_delete_long"; then
  matched_pattern="git-delete-long"
elif echo "$CMD" | grep -Eq "$git_delete_colon"; then
  matched_pattern="git-delete-colon"
elif is_gh_api_branch_delete "$CMD"; then
  matched_pattern="gh-api-delete"
fi

if [ -n "$matched_pattern" ]; then
  hook_log block-remote-branch-delete blocked "$matched_pattern"
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "decision": "block",
      "reason": "Remote branch deletion is destructive and visible to others. This needs explicit per-action user authorization — ask the user before retrying, do not bundle into cleanup steps."
    }
  }'
  exit 0
fi

exit 0
