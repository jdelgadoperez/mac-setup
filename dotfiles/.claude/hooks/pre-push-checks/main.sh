#!/usr/bin/env bash
# PreToolUse dispatcher: runs registered pre-push child checks in order.
# First child to emit a block/deny JSON wins; output is forwarded.

set -uo pipefail

# Fail-closed on internal errors — hook bugs should surface, not silently bypass push checks
trap 'exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

INPUT=$(cat)

# Fast path: only Bash tool needs these checks
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')
if [ "$TOOL" != "Bash" ]; then
  exit 0
fi

# Each child reads the same stdin payload and may emit a block JSON.
# First child to emit a block wins; its output is forwarded as-is.
run_child() {
  local child_cmd="$1"
  local out
  out=$(echo "$INPUT" | eval "$child_cmd" 2>/dev/null || true)
  if [ -n "$out" ] && echo "$out" | grep -Eq '"(decision|permissionDecision)"[[:space:]]*:[[:space:]]*"(block|deny)"'; then
    echo "$out"
    return 1
  fi
  return 0
}

run_child "$SCRIPT_DIR/scripts/block-remote-branch-delete.sh" || exit 0
run_child "node $SCRIPT_DIR/scripts/validate-push.js" || exit 0

exit 0
