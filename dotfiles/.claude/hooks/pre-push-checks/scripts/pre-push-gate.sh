#!/usr/bin/env bash
# @hook-event: PreToolUse
# @hook-command: ~/.claude/hooks/pre-push-checks/scripts/pre-push-gate.sh
# @hook-matcher: Bash(git push*)
# @description: Blocks git push unless /pre-push-checks has been run for the current HEAD commit
#
# Uses a sentinel file in ~/.cache/.claude-pre-push-checks/ keyed by repo toplevel hash.
# The sentinel contains the HEAD SHA at the time checks passed.
# A new commit invalidates the sentinel since HEAD changes.
# The /pre-push-checks skill writes the sentinel after all checks pass.

set -euo pipefail

# Deny push on unexpected errors (fail-closed)
trap 'echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"Pre-push gate encountered an unexpected error. Run /pre-push-checks and retry.\"}}" ; exit 0' ERR

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Skip dry-run pushes used for testing hooks
if echo "$CMD" | grep -qE -- '--dry-run'; then
  exit 0
fi

# Get repo identity and current HEAD
REPO_TOP=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$REPO_TOP" ]; then
  exit 0  # not in a git repo, pass through
fi

REPO_HASH=$(echo "$REPO_TOP" | md5)
HEAD=$(git rev-parse HEAD 2>/dev/null || echo "")
SENTINEL_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/.claude-pre-push-checks"
mkdir -p "$SENTINEL_DIR"
SENTINEL="${SENTINEL_DIR}/${REPO_HASH}"

# Check sentinel exists and matches current HEAD
if [ -f "$SENTINEL" ] && [ "$(cat "$SENTINEL")" = "$HEAD" ]; then
  exit 0  # checks passed for this commit, allow push
fi

# Deny with instruction to run checks
jq -n --arg head "$HEAD" \
  '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "Pre-push checks have not been run for the current HEAD commit.",
      "additionalContext": ("BLOCKED: You must run /pre-push-checks skill before pushing. Current HEAD: " + $head + ". The skill will validate formatting, linting, and tests, then unlock pushing for this commit.")
    }
  }'
