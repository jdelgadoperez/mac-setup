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

# ps: discovery + kind from plist fixtures
cat > "$LOGIN_AGENTS_ON_LOGIN_DIR/com.jdp.agent.demo.plist" <<'EOF'
<plist><dict><key>Label</key><string>com.jdp.agent.demo</string><key>RunAtLoad</key><true/></dict></plist>
EOF
cat > "$LOGIN_AGENTS_ON_LOGIN_DIR/com.jdp.agent.watch.plist" <<'EOF'
<plist><dict><key>Label</key><string>com.jdp.agent.watch</string><key>KeepAlive</key><true/></dict></plist>
EOF

check "kind: oneshot (no KeepAlive)" "$([ "$(_la_kind demo)" = "oneshot" ] && echo 0 || echo 1)"
check "kind: daemon (KeepAlive)" "$([ "$(_la_kind watch)" = "daemon" ] && echo 0 || echo 1)"

psout="$(agents ps 2>&1)"
check "ps: header present" "$(printf '%s' "$psout" | grep -q 'NAME' && echo 0 || echo 1)"
check "ps: lists demo" "$(printf '%s' "$psout" | grep -q 'demo' && echo 0 || echo 1)"
check "ps: lists watch" "$(printf '%s' "$psout" | grep -q 'watch' && echo 0 || echo 1)"
check "ps: demo shows last exit 0" "$(printf '%s' "$psout" | grep demo | grep -q ' 0 ' && echo 0 || echo 1)"

# logs
echo "hello-log-line" > "$LOGIN_AGENTS_STATE_DIR/demo.log"
logout="$(agents logs demo 2>&1)"
check "logs: prints log contents" "$(printf '%s' "$logout" | grep -q hello-log-line && echo 0 || echo 1)"

# health: missing hook
hmiss="$(agents health demo 2>&1)"
check "health: no hook message" "$(printf '%s' "$hmiss" | grep -qi 'no healthcheck' && echo 0 || echo 1)"

# health: present hook runs and its exit is surfaced
mkdir -p "$LOGIN_AGENTS_ON_LOGIN_DIR/health"
cat > "$LOGIN_AGENTS_ON_LOGIN_DIR/health/demo.sh" <<'EOF'
#!/usr/bin/env bash
echo "healthy-output"; exit 0
EOF
chmod +x "$LOGIN_AGENTS_ON_LOGIN_DIR/health/demo.sh"
hok="$(agents health demo 2>&1)"
check "health: runs hook (output)" "$(printf '%s' "$hok" | grep -q healthy-output && echo 0 || echo 1)"
check "health: reports pass" "$(printf '%s' "$hok" | grep -qi 'pass' && echo 0 || echo 1)"

# stats: oneshot with no live pid
sout="$(agents stats demo 2>&1)"
check "stats: not running message" "$(printf '%s' "$sout" | grep -qi 'not running' && echo 0 || echo 1)"

echo "==============================="
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
