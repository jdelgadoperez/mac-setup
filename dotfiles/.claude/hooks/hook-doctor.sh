#!/usr/bin/env bash
# hook-doctor.sh — active liveness probe for Claude Code hooks.
#
# Why this exists: hook-log.sh (see hook-log.sh header) tells you what a hook
# decided AFTER it ran. It cannot tell you a hook is broken in a way that
# produces no decision at all — a hook that runs, exits 0, and silently emits
# nothing. That exact failure mode hid the ICM integration for ten weeks, and
# separately let inject-sonnet-default.sh match the wrong tool name (`Task`
# only, when the live tool was `Agent`) without any signal that it had gone
# quiet. Logging is passive: it only speaks when the hook chooses to log.
# This script is active: it sends each hook a payload the hook SHOULD react
# to, and reports when nothing comes back. Run it after any hook edit, or
# periodically, to catch "still running, no longer doing anything."
#
# Standalone by design: does not source shared.sh so it keeps working even if
# this directory is invoked outside a full mac-setup checkout.

set -uo pipefail

# Probe runs must never pollute the real observability log.
export CLAUDE_HOOK_LOG=0

HOOK_SRC="${BASH_SOURCE[0]}"
while [ -L "$HOOK_SRC" ]; do HOOK_SRC="$(readlink "$HOOK_SRC")"; done
# CDPATH= : cd echoes the resolved dir when it uses CDPATH, which would be
# captured by $( ) and double the path. Harmless for absolute paths, breaks
# relative invocation.
HOOKS_DIR="$(CDPATH= cd "$(dirname "$HOOK_SRC")" && pwd)"

BLUE=$'\033[0;34m'
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
BOLD=$'\033[1m'
NC=$'\033[0m'

# ---------------------------------------------------------------------------
# Hook probe table
# Columns: relative path (from hooks dir) | human name | payload | expected behavior
# ---------------------------------------------------------------------------
# shellcheck disable=SC2034  # HOOK_TABLE is read via the loop below, not directly
HOOK_TABLE=(
  "inject-sonnet-default.sh|inject-sonnet-default|{\"tool_name\":\"Agent\",\"tool_input\":{\"prompt\":\"x\"}}|emits injection JSON (hookSpecificOutput.updatedInput with model=sonnet)"
  "cd-git-allow.sh|cd-git-allow|{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git -C /tmp status\"}}|emits block JSON (decision=block, git -C disallowed)"
  "dod-commit-nudge.sh|dod-commit-nudge|{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m x\"}}|emits additionalContext nudge JSON"
  "pre-push-checks/scripts/block-remote-branch-delete.sh|block-remote-branch-delete|{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git push origin --delete main\"}}|emits block JSON (decision=block, remote branch deletion)"
  "load-skill-anti-sycophancy.sh|load-skill-anti-sycophancy|{\"hook_event_name\":\"SessionStart\"}|emits additionalContext JSON with skill body"
)

fail_count=0

print_header() {
  printf "%s\n" "${BOLD}${BLUE}=== hook-doctor: liveness probe ===${NC}"
  printf "%s\n\n" "Hooks dir: $HOOKS_DIR"
}

probe_hooks() {
  printf "%s\n" "${BOLD}-- Probing hooks with synthetic payloads --${NC}"
  local entry rel_path name payload expected full_path
  local stdout_output exit_code
  for entry in "${HOOK_TABLE[@]}"; do
    IFS='|' read -r rel_path name payload expected <<<"$entry"
    full_path="$HOOKS_DIR/$rel_path"

    printf "\n%s\n" "${BOLD}${name}${NC} (${rel_path})"
    printf "  expected: %s\n" "$expected"

    if [ ! -r "$full_path" ]; then
      printf "  %s\n" "${RED}FAIL (hook file missing or unreadable: $full_path)${NC}"
      fail_count=$((fail_count + 1))
      continue
    fi

    stdout_output=$(printf '%s' "$payload" | CLAUDE_HOOK_LOG=0 bash "$full_path" 2>/dev/null)
    exit_code=$?

    if [ "$exit_code" -ne 0 ]; then
      printf "  %s\n" "${YELLOW}suspicious: non-zero exit code ($exit_code)${NC}"
    else
      printf "  exit code: 0\n"
    fi

    if [ -z "$stdout_output" ]; then
      printf "  %s\n" "${RED}FAIL (empty stdout — hook produced nothing)${NC}"
      fail_count=$((fail_count + 1))
      continue
    fi

    if printf '%s' "$stdout_output" | jq -e . >/dev/null 2>&1; then
      printf "  %s\n" "${GREEN}PASS${NC} (non-empty stdout, valid JSON)"
    else
      printf "  %s\n" "${YELLOW}PASS (invalid JSON)${NC} — hook emitted output but it does not parse"
      fail_count=$((fail_count + 1))
    fi
  done
  printf "\n"
}

verify_configured_hooks() {
  printf "%s\n" "${BOLD}-- Verifying hook paths referenced in settings.json exist --${NC}"
  local settings_file="$HOME/.claude/settings.json"

  if [ ! -r "$settings_file" ]; then
    printf "  %s\n" "${YELLOW}skipped: settings.json not found or unreadable at $settings_file${NC}"
    printf "\n"
    return
  fi

  # Extract every command string under .hooks.*[].hooks[].command, then pull
  # out anything that looks like a path to a hook script (contains .sh or .js
  # and a path separator) so we can check it resolves on disk.
  local commands missing_count=0
  commands=$(jq -r '
    .hooks // {}
    | to_entries[].value[]?.hooks[]?.command // empty
  ' "$settings_file" 2>/dev/null)

  if [ -z "$commands" ]; then
    printf "  %s\n" "${YELLOW}no hook commands found in settings.json${NC}"
    printf "\n"
    return
  fi

  local cmd token resolved
  while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    for token in $cmd; do
      case "$token" in
        *.sh|*.js)
          resolved="${token/#\~/$HOME}"
          case "$resolved" in
            /*) : ;;
            *) continue ;;
          esac
          if [ -r "$resolved" ]; then
            printf "  %s %s\n" "${GREEN}OK${NC}" "$resolved"
          else
            printf "  %s %s (referenced in settings.json, not found on disk)\n" "${RED}MISSING${NC}" "$resolved"
            missing_count=$((missing_count + 1))
            fail_count=$((fail_count + 1))
          fi
          ;;
      esac
    done
  done <<<"$commands"

  if [ "$missing_count" -eq 0 ]; then
    printf "  %s\n" "${GREEN}all referenced hook paths resolve${NC}"
  fi
  printf "\n"
}

main() {
  print_header
  probe_hooks
  verify_configured_hooks

  if [ "$fail_count" -eq 0 ]; then
    printf "%s\n" "${BOLD}${GREEN}All checks passed.${NC}"
    exit 0
  else
    printf "%s\n" "${BOLD}${RED}${fail_count} check(s) failed.${NC}"
    exit 1
  fi
}

main
