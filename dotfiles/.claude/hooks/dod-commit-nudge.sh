#!/usr/bin/env bash
# PreToolUse (Bash) — soft, non-blocking reminder to run the Definition-of-Done
# checklist when a commit looks like it completes code work.
# Self-gates on the command containing `git commit` (does not rely on the `if`
# filter alone). Never blocks: emits additionalContext only, always exits 0.
set -uo pipefail

INPUT=$(cat 2>/dev/null || true)
cmd=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# Only nudge on an actual git commit; silent for everything else.
case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"Definition-of-Done nudge: if this commit completes substantive code work, run the staff-eng-pre-flight Definition of Done before declaring it done — evidence (build/test green) → lens + anti-pattern catalog → diff-shape gate routing. Skip if this is a WIP/checkpoint, doc, or trivial commit."}}
JSON
