#!/usr/bin/env bash
# Tests for on-login/agents/launch-apps.sh.
# Regression coverage for: `APPS: unbound variable` under `set -u` when the
# shipped default APPS array is empty (caught by an e2e launchd run).
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/agents/launch-apps.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
check() { # label, condition-already-evaluated ("0" ok)
  if [ "$2" = "0" ]; then echo "PASS  $1"; pass=$((pass+1))
  else echo "FAIL  $1"; fail=$((fail+1)); fi
}

echo "=== launch-apps tests ==="

# --- empty APPS (the bug): must exit 0, print the message, zero iterations ---
out="$(bash "$SCRIPT" 2>&1)"
rc=$?
check "empty APPS: exit code 0" "$([ "$rc" -eq 0 ] && echo 0 || echo 1)"
check "empty APPS: prints 'no apps configured'" \
  "$(echo "$out" | grep -q 'no apps configured' && echo 0 || echo 1)"
check "empty APPS: no 'launched:' lines (zero iterations)" \
  "$(echo "$out" | grep -q 'launched:' && echo 1 || echo 0)"
check "empty APPS: no 'WARN:' lines (zero iterations)" \
  "$(echo "$out" | grep -q 'WARN:' && echo 1 || echo 0)"

# --- non-empty APPS: shim `open` on PATH to record calls without launching real apps ---
BINDIR="$TMP/bin"
mkdir -p "$BINDIR"
cat > "$BINDIR/open" <<'EOF'
#!/usr/bin/env bash
# Fake `open`: records every invocation; succeeds for "Good App", fails otherwise.
echo "open $*" >> "$OPEN_CALLS_LOG"
for arg in "$@"; do
  case "$arg" in
    "Good App") exit 0 ;;
    "Bad App") exit 1 ;;
  esac
done
exit 0
EOF
chmod +x "$BINDIR/open"

export OPEN_CALLS_LOG="$TMP/open-calls.log"
: > "$OPEN_CALLS_LOG"

FAKE_SCRIPT="$TMP/launch-apps-nonempty.sh"
sed 's/^APPS=($/APPS=(\n  "Good App"\n  "Bad App"/' "$SCRIPT" > "$FAKE_SCRIPT"
chmod +x "$FAKE_SCRIPT"

out2="$(PATH="$BINDIR:$PATH" bash "$FAKE_SCRIPT" 2>&1)"
rc2=$?
check "non-empty APPS: exit code 1 (one app failed)" "$([ "$rc2" -eq 1 ] && echo 0 || echo 1)"
check "non-empty APPS: launched good app" \
  "$(echo "$out2" | grep -q 'launched: Good App' && echo 0 || echo 1)"
check "non-empty APPS: warns on bad app" \
  "$(echo "$out2" | grep -q "WARN: could not launch 'Bad App'" && echo 0 || echo 1)"
check "non-empty APPS: open invoked for both apps" \
  "$([ "$(wc -l < "$OPEN_CALLS_LOG" | tr -d ' ')" -eq 2 ] && echo 0 || echo 1)"

echo "==============================="
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
