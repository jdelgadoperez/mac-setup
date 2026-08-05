#!/usr/bin/env bash
# Sourceable helper: observability logging for Claude Code hooks.
#
# Why this exists: a hook that runs but silently declines to act (wrong tool
# name matched, condition not met, model already set, etc.) is indistinguishable
# from a hook that never fired at all -- or worse, from a hook that is broken.
# hook_log() leaves a one-line trace for each outcome so "declined silently"
# has evidence instead of being invisible.
#
# Hook stdout is a protocol channel: Claude Code parses it as JSON
# (decision/approve/block/hookSpecificOutput). This helper therefore NEVER
# writes to stdout -- everything goes to a plain file.
#
# This helper must never be the reason a hook breaks. Every operation here is
# failure-tolerant: on any error it gives up quietly and returns 0 so the
# calling hook's exit code and control flow are completely unaffected.

hook_log() {
  # Off switch. Use ${VAR-} (not "$VAR") so this is safe under a caller's
  # `set -u` — CLAUDE_HOOK_LOG is normally unset, and this helper must never
  # be the reason a hook dies to an unbound-variable error.
  if [ "${CLAUDE_HOOK_LOG-}" = "0" ] || [ "${CLAUDE_HOOK_LOG-}" = "off" ]; then
    return 0
  fi

  local hook_name="$1"
  local outcome="$2"
  local detail="${3:-}"

  # NOT ~/.claude/logs -- that name is a legacy directory Claude Code's startup
  # retention sweep deletes outright ("todos/, statsig/, logs/ ... the sweep
  # removes their contents and then the empty directory"). A diagnostic log that
  # vanishes on restart is worse than none, because its absence reads as "no
  # hooks declined" rather than "the file was deleted".
  local log_dir="$HOME/.claude/hook-logs"
  local log_file="$log_dir/hooks.jsonl"

  mkdir -p "$log_dir" 2>/dev/null || true

  # Size cap: keep the log from growing unbounded (~2MB), retain last 500 lines.
  if [ -f "$log_file" ]; then
    local size
    size=$( (wc -c < "$log_file") 2>/dev/null || echo 0)
    if [ "${size:-0}" -gt 2097152 ] 2>/dev/null; then
      (tail -n 500 "$log_file" > "$log_file.tmp" && mv "$log_file.tmp" "$log_file") 2>/dev/null || true
    fi
  fi

  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

  # Escape detail for JSON safety: backslash, double-quote, tab (via sed), then
  # newline (via awk — BSD sed's N/$!ba multi-line join drops single-line input
  # with no trailing newline, so sed alone is not safe here).
  local escaped_detail
  escaped_detail=$(printf '%s' "$detail" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/	/\\t/g' \
    | awk '{printf "%s%s", (NR>1?"\\n":""), $0}')

  printf '{"ts":"%s","hook":"%s","outcome":"%s","detail":"%s"}\n' \
    "$ts" "$hook_name" "$outcome" "$escaped_detail" >> "$log_file" 2>/dev/null || true

  return 0
}
