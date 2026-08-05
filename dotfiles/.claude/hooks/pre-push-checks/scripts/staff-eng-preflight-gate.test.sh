#!/usr/bin/env bash
# Test harness for staff-eng-preflight-gate.sh
# Runs every classification case and asserts expected outcome.
# Must be run with NO valid sentinel present.

set -uo pipefail

# CDPATH= : cd echoes the resolved dir when it uses CDPATH, which would be
# captured by $( ) and double the path. Harmless for absolute paths, breaks
# relative invocation.
GATE="$(CDPATH= cd "$(dirname "$0")" && pwd)/staff-eng-preflight-gate.sh"
SENTINEL_DIR="$HOME/.claude/.staff-preflight"
SENTINEL_BACKUP="$HOME/.claude/.staff-preflight-backup-$$"

PASS=0
FAIL=0

# ── Colour helpers ─────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

# ── Temporarily move sentinels aside ──────────────────────────────────────────
moved_sentinel=0
if [[ -d "$SENTINEL_DIR" ]]; then
  mv "$SENTINEL_DIR" "$SENTINEL_BACKUP"
  moved_sentinel=1
fi
mkdir -p "$SENTINEL_DIR"   # empty dir — no sentinels

# Restore on exit no matter what
restore_sentinels() {
  rm -rf "$SENTINEL_DIR"
  if [[ "$moved_sentinel" -eq 1 ]]; then
    mv "$SENTINEL_BACKUP" "$SENTINEL_DIR"
  fi
}
trap restore_sentinels EXIT

# ── Test runner ───────────────────────────────────────────────────────────────
# outcome_class:
#   DENY   → output contains "permissionDecision":"deny"
#   NUDGE  → output contains "additionalContext" but NOT permissionDecision
#   SILENT → output is empty

run_case() {
  local expected="$1"
  local cmd="$2"
  local label="${3:-$cmd}"

  local payload
  payload=$(jq -n --arg cmd "$cmd" '{"tool_name":"Bash","tool_input":{"command":$cmd}}')

  local output
  output=$(printf '%s' "$payload" | bash "$GATE" 2>/dev/null)

  local actual
  if [[ -z "$output" ]]; then
    actual="SILENT"
  elif echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' &>/dev/null; then
    actual="DENY"
  elif echo "$output" | jq -e '.hookSpecificOutput | has("additionalContext")' &>/dev/null; then
    actual="NUDGE"
  else
    # Non-empty but neither pattern — treat as SILENT (fail-open unexpected output)
    actual="UNKNOWN($output)"
  fi

  if [[ "$actual" == "$expected" ]]; then
    printf "${GREEN}PASS${RESET}  %-8s  %s\n" "[$expected]" "$label"
    (( PASS++ )) || true
  else
    printf "${RED}FAIL${RESET}  expected=%-6s got=%-10s  %s\n" "$expected" "$actual" "$label"
    (( FAIL++ )) || true
  fi
}

echo ""
echo "=== staff-eng-preflight-gate — test run (no sentinel) ==="
echo ""

# ── DENY cases ────────────────────────────────────────────────────────────────
echo "--- DENY (hard-block) ---"
run_case DENY \
  "gh pr create --repo drata/api --head br --title x" \
  "gh pr create (remote only)"

run_case DENY \
  "cd /Users/jessdelgadoperez/projects/drata/api && gh pr create --head br" \
  "cd + gh pr create"

run_case DENY \
  "gh pr ready 123 --repo drata/api" \
  "gh pr ready"

run_case DENY \
  "gh pr edit 123 --repo drata/api --add-reviewer kevin-janssen" \
  "gh pr edit --add-reviewer"

run_case DENY \
  "gh api repos/drata/api/pulls/123/requested_reviewers --method POST -f reviewers[]=x" \
  "gh api /requested_reviewers POST"

run_case DENY \
  "STAFF_PREFLIGHT_SKIP=1 gh pr create --repo drata/api --head br" \
  "STAFF_PREFLIGHT_SKIP=1 no longer bypasses (unskippable)"

echo ""

# ── NUDGE cases ───────────────────────────────────────────────────────────────
echo "--- NUDGE (soft nudge) ---"
run_case NUDGE \
  "cd /Users/jessdelgadoperez/projects/drata/api-PLAT-1 && git push -u origin br" \
  "cd + git push (non-existent repo → recency fallback → no sentinel → nudge)"

echo ""

# ── SILENT cases ──────────────────────────────────────────────────────────────
echo "--- SILENT (allow) ---"
run_case SILENT \
  "gh pr view 123 --repo drata/api" \
  "gh pr view"

run_case SILENT \
  "gh pr list --repo drata/api" \
  "gh pr list"

run_case SILENT \
  "gh pr checks 123 --repo drata/api" \
  "gh pr checks"

run_case SILENT \
  "gh pr diff 123 --repo drata/api" \
  "gh pr diff"

run_case SILENT \
  "gh pr review 123 --repo drata/api --approve" \
  "gh pr review (reviewing others)"

run_case SILENT \
  "git status" \
  "git status"

run_case SILENT \
  'git commit -m "x"' \
  "git commit"

run_case SILENT \
  "ls -la" \
  "ls -la"

run_case SILENT \
  "cd /x && git push origin --delete br" \
  "git push --delete (branch delete passthrough)"

echo ""

# ── A1 worktree-aware acceptance ──────────────────────────────────────────────
echo "--- A1 worktree-aware acceptance ---"

run_a1_case() {
  local expected="$1"
  local label="$2"
  local record_worktree_sentinel="$3"  # "yes" or "no"

  local primary_dir wt_dir primary_sha wt_sha
  primary_dir=$(mktemp -d)
  wt_dir=$(mktemp -d)
  rmdir "$wt_dir"  # git worktree add requires the target not to already exist

  (
    cd "$primary_dir" || exit 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "initial" > file.txt
    git add file.txt
    git commit -q -m "initial commit"
    git worktree add -q -b test-a1-branch "$wt_dir" &>/dev/null
  )

  primary_sha=$(git -C "$primary_dir" rev-parse HEAD 2>/dev/null)

  (
    cd "$wt_dir" || exit 1
    echo "worktree change" > file.txt
    git add file.txt
    git commit -q -m "worktree commit"
  )

  wt_sha=$(git -C "$wt_dir" rev-parse HEAD 2>/dev/null)

  if [[ "$record_worktree_sentinel" == "yes" ]]; then
    echo "test sentinel" > "$SENTINEL_DIR/${wt_sha}.done"
  fi

  local payload
  payload=$(jq -n --arg cmd "gh api repos/drata/api/pulls/1/requested_reviewers --method POST -f reviewers[]=x" \
    '{"tool_name":"Bash","tool_input":{"command":$cmd}}')

  local output
  output=$(printf '%s' "$payload" | (cd "$primary_dir" && bash "$GATE" 2>/dev/null))

  local actual
  if [[ -z "$output" ]]; then
    actual="SILENT"
  elif echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' &>/dev/null; then
    actual="DENY"
  elif echo "$output" | jq -e '.hookSpecificOutput | has("additionalContext")' &>/dev/null; then
    actual="NUDGE"
  else
    actual="UNKNOWN($output)"
  fi

  if [[ "$actual" == "$expected" ]]; then
    printf "${GREEN}PASS${RESET}  %-8s  %s\n" "[$expected]" "$label"
    (( PASS++ )) || true
  else
    printf "${RED}FAIL${RESET}  expected=%-6s got=%-10s  %s\n" "$expected" "$actual" "$label"
    (( FAIL++ )) || true
  fi

  # Clean up: remove sentinel (if recorded) and both temp repos
  rm -f "$SENTINEL_DIR/${wt_sha}.done"
  rm -f "$SENTINEL_DIR/${primary_sha}.done"
  git -C "$primary_dir" worktree remove --force "$wt_dir" &>/dev/null || true
  rm -rf "$primary_dir" "$wt_dir"
}

run_a1_case SILENT \
  "primary HEAD has no sentinel, sibling worktree HEAD does → accepted via fallback" \
  "yes"

run_a1_case DENY \
  "primary HEAD has no sentinel, no worktree HEAD has one either → still denied" \
  "no"

echo ""
echo "==================================================="
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "==================================================="
echo ""

[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
