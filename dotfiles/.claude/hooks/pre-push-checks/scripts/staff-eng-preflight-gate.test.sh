#!/usr/bin/env bash
# Test harness for staff-eng-preflight-gate.sh — run with NO sentinel present.
# Classifies each case as DENY / NUDGE / SILENT and asserts the expected class.
set -uo pipefail

GATE="$(cd "$(dirname "$0")" && pwd)/staff-eng-preflight-gate.sh"

cls() {
  local cmd="$1" out
  out=$(printf '{"tool_name":"Bash","tool_input":{"command":%s}}' \
        "$(node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' "$cmd")" \
        | bash "$GATE" 2>/dev/null)
  if [ -z "$out" ]; then echo "SILENT"
  elif printf '%s' "$out" | grep -Eq '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"'; then echo "DENY"
  elif printf '%s' "$out" | grep -q 'additionalContext'; then echo "NUDGE"
  else echo "OTHER"; fi
}

pass=0; fail=0
check() { # expected, label, cmd
  local got; got=$(cls "$3")
  if [ "$got" = "$1" ]; then echo "PASS  [$1]  $2"; pass=$((pass+1))
  else echo "FAIL  exp=$1 got=$got  $2"; fail=$((fail+1)); fi
}

echo "=== staff-eng-preflight-gate — test run (no sentinel) ==="
check DENY   "gh pr create"                 "gh pr create --repo acme/app --head br --title x"
check DENY   "cd + gh pr create"            "cd /tmp/acme-app && gh pr create --head br"
check DENY   "gh pr ready"                  "gh pr ready 12 --repo acme/app"
check DENY   "gh pr edit --add-reviewer"    "gh pr edit 12 --repo acme/app --add-reviewer someone"
check DENY   "gh api requested_reviewers"   "gh api repos/acme/app/pulls/12/requested_reviewers --method POST -f reviewers[]=x"
check NUDGE  "cd + git push"                "cd /tmp/acme-app && git push -u origin br"
check SILENT "gh pr view"                   "gh pr view 12 --repo acme/app"
check SILENT "gh pr list"                   "gh pr list --repo acme/app"
check SILENT "gh pr checks"                 "gh pr checks 12 --repo acme/app"
check SILENT "gh pr diff"                   "gh pr diff 12 --repo acme/app"
check SILENT "gh pr review (others)"        "gh pr review 12 --repo acme/app --approve"
check SILENT "git status"                   "git status"
check SILENT "git commit"                   "git commit -m x"
check SILENT "ls"                           "ls -la"
check SILENT "bypass STAFF_PREFLIGHT_SKIP"  "STAFF_PREFLIGHT_SKIP=1 gh pr create --repo acme/app --head br"
check SILENT "git push --delete"            "cd /tmp/x && git push origin --delete br"

echo "==================================================="
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
