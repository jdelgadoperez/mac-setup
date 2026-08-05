#!/usr/bin/env bash
# PreToolUse (Bash) — soft, non-blocking reminder to run the Definition-of-Done
# checklist when a commit looks like it completes code work.
# Self-gates on the command containing `git commit` (does not rely on the `if`
# filter alone). Never blocks: emits additionalContext only, always exits 0.
set -uo pipefail

HOOK_SRC="${BASH_SOURCE[0]}"
while [ -L "$HOOK_SRC" ]; do HOOK_SRC="$(readlink "$HOOK_SRC")"; done
# CDPATH= : cd echoes the resolved dir when it uses CDPATH, which would be
# captured by $( ) and double the path. Harmless for absolute paths, breaks
# relative invocation.
HOOK_DIR="$(CDPATH= cd "$(dirname "$HOOK_SRC")" && pwd)"
# shellcheck source=/dev/null
if [ -r "$HOOK_DIR/hook-log.sh" ]; then . "$HOOK_DIR/hook-log.sh"; else hook_log() { :; }; fi

INPUT=$(cat 2>/dev/null || true)
jq_status=0
cmd=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null) || jq_status=$?

if [ "$jq_status" -ne 0 ] || [ -z "$INPUT" ]; then
  hook_log dod-commit-nudge error "could not parse command"
  exit 0
fi

# Only nudge on an actual git commit; silent for everything else.
case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

hook_log dod-commit-nudge nudged "git commit"

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"Definition-of-Done nudge: if this commit completes substantive code work, run the staff-eng-pre-flight Definition of Done before declaring it done — evidence (build/test green) → lens + anti-pattern catalog → diff-shape gate routing. Skip if this is a WIP/checkpoint, doc, or trivial commit."}}
JSON
