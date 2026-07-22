#!/usr/bin/env bash
# Tests for bin/run-agent. Uses LOGIN_AGENTS_STATE_DIR to sandbox state.
set -uo pipefail

WRAP="$(cd "$(dirname "$0")/.." && pwd)/run-agent"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export LOGIN_AGENTS_STATE_DIR="$TMP/state"

pass=0; fail=0
check() { # label, condition-already-evaluated ("0" ok)
  if [ "$2" = "0" ]; then echo "PASS  $1"; pass=$((pass+1))
  else echo "FAIL  $1"; fail=$((fail+1)); fi
}
json() { # file, key -> value (bash parse, no jq dependency in tests)
  grep -o "\"$2\"[[:space:]]*:[[:space:]]*\"\{0,1\}[^\",}]*" "$1" \
    | sed 's/.*:[[:space:]]*"\{0,1\}//'
}

echo "=== run-agent tests ==="

# success case
"$WRAP" ok-agent -- /bin/sh -c 'echo hello; exit 0' >/dev/null 2>&1
rc=$?
check "success: exit code propagates (0)" "$([ "$rc" -eq 0 ] && echo 0 || echo 1)"
J="$LOGIN_AGENTS_STATE_DIR/ok-agent.json"
check "success: json created" "$([ -f "$J" ] && echo 0 || echo 1)"
check "success: name field" "$([ "$(json "$J" name)" = "ok-agent" ] && echo 0 || echo 1)"
check "success: status=success" "$([ "$(json "$J" status)" = "success" ] && echo 0 || echo 1)"
check "success: exit_code=0" "$([ "$(json "$J" exit_code)" = "0" ] && echo 0 || echo 1)"
check "success: log has output" "$(grep -q hello "$LOGIN_AGENTS_STATE_DIR/ok-agent.log" && echo 0 || echo 1)"

# failure case — real child code, not hardcoded
"$WRAP" bad-agent -- /bin/sh -c 'exit 7' >/dev/null 2>&1
rc=$?
check "failure: exit code propagates (7)" "$([ "$rc" -eq 7 ] && echo 0 || echo 1)"
JB="$LOGIN_AGENTS_STATE_DIR/bad-agent.json"
check "failure: exit_code matches child" "$([ "$(json "$JB" exit_code)" = "$rc" ] && echo 0 || echo 1)"
check "failure: status=failure" "$([ "$(json "$JB" status)" = "failure" ] && echo 0 || echo 1)"

# rotation: with a tiny cap, the log stays bounded near the cap
export LOGIN_AGENTS_LOG_MAX_BYTES=2048
"$WRAP" rot-agent -- /bin/sh -c 'for i in $(seq 1 500); do echo "line-$i-xxxxxxxxxxxxxxxx"; done' >/dev/null 2>&1
LR="$LOGIN_AGENTS_STATE_DIR/rot-agent.log"
rbytes=$(wc -c < "$LR" | tr -d ' ')
check "rotation: log bounded (<= 2x cap)" "$([ "$rbytes" -le 4096 ] && echo 0 || echo 1)"
unset LOGIN_AGENTS_LOG_MAX_BYTES

# sub-second resolution: a ~50ms child must record a non-zero, sub-1000ms
# duration_ms. Against the old whole-second now_ms() (date +%s * 1000), any
# run finishing inside the same second would record exactly 0 -- this would
# have failed before the fix. Only runs if a ms-precision backend exists.
if command -v python3 >/dev/null 2>&1 || command -v perl >/dev/null 2>&1; then
  "$WRAP" fast-agent -- /bin/sh -c 'sleep 0.05' >/dev/null 2>&1
  JF="$LOGIN_AGENTS_STATE_DIR/fast-agent.json"
  fast_ms="$(json "$JF" duration_ms)"
  check "sub-second: duration_ms > 0 and < 1000 (got ${fast_ms:-<missing>})" \
    "$([ -n "$fast_ms" ] && [ "$fast_ms" -gt 0 ] 2>/dev/null && [ "$fast_ms" -lt 1000 ] 2>/dev/null && echo 0 || echo 1)"
else
  echo "SKIP  sub-second: no python3/perl available for ms-precision clock"
fi

echo "==============================="
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
