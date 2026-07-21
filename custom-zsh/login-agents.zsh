#!/usr/bin/env zsh
# agents — Docker-style observability CLI for login LaunchAgents.
# Reads run-agent state + `launchctl print` / `log stream`. Read-only except restart.

_la_state_dir() {
  echo "${LOGIN_AGENTS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/login-agents}"
}
_la_on_login_dir() {
  echo "${LOGIN_AGENTS_ON_LOGIN_DIR:-$HOME/projects/mac-setup/on-login}"
}
_la_label() { echo "com.jdp.agent.$1"; }

# _la_json_get <file> <key> — jq if present, else bash/sed fallback.
_la_json_get() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$key" '.[$k] // empty' "$file"
  else
    grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"\{0,1\}[^\",}]*" "$file" \
      | sed 's/.*:[[:space:]]*"\{0,1\}//'
  fi
}

_la_plist_path() { echo "$(_la_on_login_dir)/$(_la_label "$1").plist"; }
_la_health_path() { echo "$(_la_on_login_dir)/health/$1.sh"; }

_la_kind() {
  local p="$(_la_plist_path "$1")"
  if [ -f "$p" ] && grep -q '<key>KeepAlive</key>' "$p"; then echo daemon; else echo oneshot; fi
}
_la_discover() {
  local dir="$(_la_on_login_dir)" f base
  for f in "$dir"/com.jdp.agent.*.plist(N); do
    base="${f:t}"; base="${base#com.jdp.agent.}"; base="${base%.plist}"
    echo "$base"
  done
}
# _la_launchctl_field <name> <needle> — pull "runs"/"pid" etc. from launchctl print. Empty if unavailable.
_la_launchctl_field() {
  local label="$(_la_label "$1")" needle="$2"
  launchctl print "gui/${UID}/${label}" 2>/dev/null \
    | grep -E "^[[:space:]]*${needle} = " | head -1 | sed 's/.*= //'
}

agents() {
  local sub="${1:-help}"; shift 2>/dev/null
  case "$sub" in
    inspect)
      local name="$1"
      [ -n "$name" ] || { echo "usage: agents inspect <name>" >&2; return 64; }
      echo "${BOLD}label:${NC}  $(_la_label "$name")"
      echo "${BOLD}plist:${NC}  $(_la_plist_path "$name")"
      echo "${BOLD}health:${NC} $(_la_health_path "$name")"
      echo "${BOLD}state:${NC}"
      local jf="$(_la_state_dir)/$name.json"
      if [ -f "$jf" ]; then cat "$jf"; else echo "  (no runs recorded)"; fi
      ;;
    ps)
      local only_running=0
      [ "${1:-}" = "--running" ] && only_running=1
      printf '%-18s %-10s %-22s %-5s %-6s %s\n' NAME STATE LAST-RUN EXIT RUNS KIND
      local name jf agent_status exit_code finished runs pid state kind
      for name in $(_la_discover); do
        jf="$(_la_state_dir)/$name.json"
        agent_status="$(_la_json_get "$jf" status 2>/dev/null)"
        exit_code="$(_la_json_get "$jf" exit_code 2>/dev/null)"
        finished="$(_la_json_get "$jf" finished_at 2>/dev/null)"
        pid="$(_la_launchctl_field "$name" pid)"
        runs="$(_la_launchctl_field "$name" runs)"; [ -n "$runs" ] || runs="-"
        kind="$(_la_kind "$name")"
        if [ -n "$pid" ]; then state="running"; else state="${agent_status:-never}"; fi
        if [ "$only_running" = "1" ] && [ -z "$pid" ]; then continue; fi
        printf '%-18s %-10s %-22s %-5s %-6s %s\n' \
          "$name" "$state" "${finished:--}" "${exit_code:--}" "$runs" "$kind"
      done
      ;;
    logs)
      local follow=0
      if [ "${1:-}" = "-f" ]; then follow=1; shift; fi
      local name="$1"; [ -n "$name" ] || { echo "usage: agents logs [-f] <name>" >&2; return 64; }
      local lf="$(_la_state_dir)/$name.log"
      [ -f "$lf" ] || { echo "no log for '$name'" >&2; return 1; }
      if [ "$follow" = "1" ]; then tail -f "$lf"; else cat "$lf"; fi
      ;;
    events)
      local name="$1"; [ -n "$name" ] || { echo "usage: agents events <name>" >&2; return 64; }
      log stream --predicate "process == \"$name\""
      ;;
    health)
      local name="$1"; [ -n "$name" ] || { echo "usage: agents health <name>" >&2; return 64; }
      local hook="$(_la_health_path "$name")"
      if [ ! -x "$hook" ] && [ ! -f "$hook" ]; then
        echo "no healthcheck defined for '$name'"; return 0
      fi
      local out; out="$(bash "$hook" 2>&1)"; local hstatus=$?
      echo "$out"
      if [ "$hstatus" -eq 0 ]; then echo "${GREEN}health: pass${NC}"; else echo "${RED}health: fail (exit $hstatus)${NC}"; return "$hstatus"; fi
      ;;
    stats)
      local name="$1"; [ -n "$name" ] || { echo "usage: agents stats <name>" >&2; return 64; }
      local pid="$(_la_launchctl_field "$name" pid)"
      if [ -z "$pid" ]; then echo "$name: not running (oneshot or stopped)"; return 0; fi
      ps -o pid,%cpu,%mem,etime -p "$pid"
      ;;
    restart)
      local name="$1"; [ -n "$name" ] || { echo "usage: agents restart <name>" >&2; return 64; }
      launchctl kickstart -k "gui/${UID}/$(_la_label "$name")"
      ;;
    help|--help|-h|"")
      echo "usage: agents <ps|logs|events|health|stats|restart|inspect> [name]"
      ;;
    *)
      echo "agents: unknown subcommand '$sub'" >&2
      echo "usage: agents <ps|logs|events|health|stats|restart|inspect> [name]" >&2
      return 1
      ;;
  esac
}
