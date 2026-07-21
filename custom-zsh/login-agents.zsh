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
