#!/usr/bin/env bash
# PreToolUse hook: gate PR-exposure and push commands on a staff-eng pre-flight sentinel.
#
# Registered as its OWN PreToolUse hook matcher on "Bash" — runs independently of main.sh.
# Input: JSON on stdin  { "tool_name": "Bash", "tool_input": { "command": "<cmd>" } }
#
# Output contract:
#   HARD BLOCK  → print deny JSON, exit 0
#   SOFT NUDGE  → print additionalContext JSON, exit 0
#   SILENT ALLOW → print nothing, exit 0
#   INTERNAL ERROR → fail OPEN (silent allow, exit 0) — never break the user's workflow

set -uo pipefail

# ── Fail-open trap ─────────────────────────────────────────────────────────────
# Any unexpected error → silent allow. A gate bug must not block all PRs.
trap 'exit 0' ERR

# ── Messages ───────────────────────────────────────────────────────────────────
HARD_BLOCK_MSG="Staff-eng pre-flight not recorded for this change. Run the staff-eng-pre-flight skill (Definition of Done) before opening the PR / requesting reviews — it records the sentinel that clears this gate. There is NO env-var bypass; a genuine emergency still requires running the gate (or recording the sentinel via ~/.claude/skills/staff-eng-pre-flight/record-preflight.sh). Subagents must NOT attempt to skip this — return control to the user instead."
SOFT_NUDGE_MSG="Staff-eng pre-flight not recorded for this push. If this push completes substantive work, run the staff-eng-pre-flight Definition of Done. (Non-blocking.)"

SENTINEL_DIR="$HOME/.claude/.staff-preflight"
CHECK_SCRIPT="$HOME/.claude/skills/staff-eng-pre-flight/check-preflight.sh"
RECENCY_MINUTES=120

# ── Read stdin ────────────────────────────────────────────────────────────────
INPUT=$(cat)

# Only act on Bash tool calls
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')
if [[ "$TOOL" != "Bash" ]]; then
  exit 0
fi

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')
[[ -z "$CMD" ]] && exit 0

# ── No bypass (intentional) ──────────────────────────────────────────────────
# The STAFF_PREFLIGHT_SKIP env-var / inline bypass was removed deliberately: a
# subagent abused it to publish a PR without running the gate. The ONLY way to
# clear this gate is a valid sentinel, recorded by actually running the pre-flight
# (or `record-preflight.sh` for a deliberate emergency). The `trap 'exit 0' ERR`
# above still fails OPEN on internal error, so a gate bug can never block every PR.

# ── Command classification ────────────────────────────────────────────────────
# Returns: "hard-block", "soft-nudge", or "silent"
classify_command() {
  local cmd="$1"

  # ── Must-silent list: read-only / review-others commands ─────────────────
  # gh pr view / list / checks / diff / status
  if echo "$cmd" | grep -qE 'gh[[:space:]]+pr[[:space:]]+(view|list|checks|diff|status)([[:space:]]|$)'; then
    echo "silent"; return
  fi

  # gh pr review (reviewing others — not create/ready/edit)
  if echo "$cmd" | grep -qE 'gh[[:space:]]+pr[[:space:]]+review([[:space:]]|$)'; then
    echo "silent"; return
  fi

  # ── Branch-delete git push: another hook's domain → silent ───────────────
  # git push <remote> --delete <branch>  OR  git push <remote> -d <branch>
  if echo "$cmd" | grep -qE 'git[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+(--delete|-d)[[:space:]]+'; then
    echo "silent"; return
  fi
  # git push <remote> :<branch>  (colon prefix = delete)
  if echo "$cmd" | grep -qE 'git[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+:[^[:space:]]'; then
    echo "silent"; return
  fi

  # ── HARD-BLOCK commands ───────────────────────────────────────────────────

  # gh pr create
  if echo "$cmd" | grep -qE 'gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)'; then
    echo "hard-block"; return
  fi

  # gh pr ready
  if echo "$cmd" | grep -qE 'gh[[:space:]]+pr[[:space:]]+ready([[:space:]]|$)'; then
    echo "hard-block"; return
  fi

  # gh pr edit with --add-reviewer or --reviewer
  if echo "$cmd" | grep -qE 'gh[[:space:]]+pr[[:space:]]+edit([[:space:]]|$)'; then
    if echo "$cmd" | grep -qE '(--add-reviewer|--reviewer)([[:space:]]|=|$)'; then
      echo "hard-block"; return
    fi
  fi

  # gh api with /requested_reviewers in the path
  if echo "$cmd" | grep -qE 'gh[[:space:]]+api([[:space:]]|$)'; then
    if echo "$cmd" | grep -q '/requested_reviewers'; then
      echo "hard-block"; return
    fi
  fi

  # ── SOFT-NUDGE commands ───────────────────────────────────────────────────

  # git push (non-delete)
  if echo "$cmd" | grep -qE 'git[[:space:]]+push([[:space:]]|$)'; then
    echo "soft-nudge"; return
  fi

  # Default: silent allow
  echo "silent"
}

CLASS=$(classify_command "$CMD")
[[ "$CLASS" == "silent" ]] && exit 0

# ── Sentinel resolution ───────────────────────────────────────────────────────
has_valid_sentinel() {
  local cmd="$1"
  local repo_root=""

  # 1a. cd <path> && ... or cd <path>; ...
  if echo "$cmd" | grep -qE 'cd[[:space:]]+[^[:space:];]+[[:space:]]*(&&|;)'; then
    repo_root=$(echo "$cmd" | sed -E 's/.*cd[[:space:]]+([^[:space:];]+)[[:space:]]*(&&|;).*/\1/')
  # 1b. git -C <path>
  elif echo "$cmd" | grep -qE 'git[[:space:]]+-C[[:space:]]+[^[:space:]]+'; then
    repo_root=$(echo "$cmd" | sed -E 's/.*git[[:space:]]+-C[[:space:]]+([^[:space:]]+).*/\1/')
  # 1c. $PWD if inside a git repo
  elif git -C "$PWD" rev-parse --show-toplevel &>/dev/null 2>&1; then
    repo_root=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)
  fi

  # Precise mode: try to resolve HEAD sha from candidate repo root
  if [[ -n "$repo_root" ]]; then
    local sha
    sha=$(git -C "$repo_root" rev-parse HEAD 2>/dev/null) || sha=""
    if [[ -n "$sha" ]]; then
      local sentinel="$SENTINEL_DIR/${sha}.done"
      if [[ -f "$sentinel" ]]; then
        return 0
      fi

      # Worktree-aware fallback (A1): the sentinel is keyed on the HEAD SHA, so a
      # sentinel recorded from a linked worktree is valid regardless of which
      # checkout $PWD/the command resolved to. This is the fix for gh/git commands
      # that run WITHOUT cd-ing into the worktree first: $PWD (or the scraped path)
      # points at the primary checkout, whose HEAD has no sentinel, even though the
      # worktree's HEAD was genuinely pre-flighted.
      #
      # Scope is bounded to THIS repo's worktrees: `git worktree list` only
      # enumerates worktrees sharing the same .git (same --git-common-dir), so a
      # sentinel from an unrelated repo can never match here. If any sibling
      # worktree's HEAD has a sentinel, accept — and log which SHA matched so a
      # multi-worktree false-allow (only one worktree cleared) is visible in hook
      # logs. stderr does not affect the allow/deny decision.
      local wt_sha
      while read -r _kw wt_sha; do
        [[ "$_kw" == "HEAD" && -n "$wt_sha" ]] || continue
        [[ "$wt_sha" == "$sha" ]] && continue  # already checked $PWD's HEAD above
        if [[ -f "$SENTINEL_DIR/${wt_sha}.done" ]]; then
          echo "staff-eng-preflight-gate: cleared via sibling worktree HEAD ${wt_sha} (command's checkout HEAD ${sha} had no sentinel)" >&2
          return 0
        fi
      done < <(git -C "$repo_root" worktree list --porcelain 2>/dev/null)

      # Precise mode resolved a sha and no worktree HEAD matched → definitive miss
      return 1
    fi
  fi

  # Recency fallback: any sentinel modified within the last RECENCY_MINUTES minutes
  if [[ -d "$SENTINEL_DIR" ]]; then
    local now mtime f
    now=$(date +%s)
    for f in "$SENTINEL_DIR"/*.done; do
      [[ -e "$f" ]] || continue
      mtime=$(stat -f %m "$f" 2>/dev/null) || continue
      if (( now - mtime <= RECENCY_MINUTES * 60 )); then
        return 0
      fi
    done
  fi

  return 1
}

if has_valid_sentinel "$CMD"; then
  exit 0
fi

# ── Emit block or nudge ───────────────────────────────────────────────────────
if [[ "$CLASS" == "hard-block" ]]; then
  jq -n --arg reason "$HARD_BLOCK_MSG" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$reason}}'
else
  # soft-nudge
  jq -n --arg ctx "$SOFT_NUDGE_MSG" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":$ctx}}'
fi

exit 0
