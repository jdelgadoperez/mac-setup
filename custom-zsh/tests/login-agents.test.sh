#!/usr/bin/env zsh
# Tests for custom-zsh/login-agents.zsh helper resolution + inspect.
set -uo pipefail
emulate -L zsh

HERE="${0:A:h}"
export LOGIN_AGENTS_TEST=1
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export LOGIN_AGENTS_STATE_DIR="$TMP/state"
export LOGIN_AGENTS_ON_LOGIN_DIR="$TMP/on-login"
mkdir -p "$LOGIN_AGENTS_STATE_DIR" "$LOGIN_AGENTS_ON_LOGIN_DIR"

# minimal styles stub so sourcing works standalone
for v in BLUE GREEN RED YELLOW CYAN BOLD NC RESET; do typeset -g "$v"=""; done

source "$HERE/../login-agents.zsh"

pass=0; fail=0
check() { if [ "$2" = "0" ]; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1"; fail=$((fail+1)); fi }

echo "=== login-agents CLI tests ==="

lbl="$(_la_label demo)"
check "label scheme" "$([ "$lbl" = "com.jdp.agent.demo" ] && echo 0 || echo 1)"

cat > "$LOGIN_AGENTS_STATE_DIR/demo.json" <<'EOF'
{
  "name": "demo",
  "status": "success",
  "exit_code": 0,
  "duration_ms": 42,
  "started_at": "2026-07-21T09:00:00Z",
  "finished_at": "2026-07-21T09:00:00Z"
}
EOF
check "json_get status" "$([ "$(_la_json_get "$LOGIN_AGENTS_STATE_DIR/demo.json" status)" = "success" ] && echo 0 || echo 1)"
check "json_get exit_code" "$([ "$(_la_json_get "$LOGIN_AGENTS_STATE_DIR/demo.json" exit_code)" = "0" ] && echo 0 || echo 1)"

# Force the bash/sed fallback branch: shadow `command -v jq` to report absent,
# and shadow `jq` itself to fail loudly if it's ever invoked, so a pass here
# can only happen via the sed path, never via real jq.
fallback_status="$(
  jq() { echo "ERROR: jq was called!" >&2; return 99; }
  command() { if [ "$1" = "-v" ] && [ "$2" = "jq" ]; then return 1; fi; builtin command "$@"; }
  _la_json_get "$LOGIN_AGENTS_STATE_DIR/demo.json" status
)"
check "json_get fallback (no jq) returns status" "$([ "$fallback_status" = "success" ] && echo 0 || echo 1)"

fallback_exit_code="$(
  jq() { echo "ERROR: jq was called!" >&2; return 99; }
  command() { if [ "$1" = "-v" ] && [ "$2" = "jq" ]; then return 1; fi; builtin command "$@"; }
  _la_json_get "$LOGIN_AGENTS_STATE_DIR/demo.json" exit_code
)"
check "json_get fallback (no jq) returns exit_code" "$([ "$fallback_exit_code" = "0" ] && echo 0 || echo 1)"

out="$(agents inspect demo 2>&1)"
check "inspect shows label" "$(printf '%s' "$out" | grep -q 'com.jdp.agent.demo' && echo 0 || echo 1)"
check "inspect shows json" "$(printf '%s' "$out" | grep -q '"status": "success"' && echo 0 || echo 1)"

echo "==============================="
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
