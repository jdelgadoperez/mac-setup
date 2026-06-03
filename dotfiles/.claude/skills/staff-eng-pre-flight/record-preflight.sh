#!/usr/bin/env bash
# Record a staff-eng pre-flight sentinel for the current HEAD of <repo-root>.
# Usage: record-preflight.sh <repo-root> "<one-line verdict note>"
set -uo pipefail

repo_root="${1:-$PWD}"
note="${2:-READY}"
sha="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null)" || { echo "not-a-git-repo: $repo_root" >&2; exit 2; }
branch="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"

dir="$HOME/.claude/.staff-preflight"
mkdir -p "$dir"
sentinel="$dir/${sha}.done"
{
  echo "sha: $sha"
  echo "repo: $(basename "$(git -C "$repo_root" rev-parse --show-toplevel 2>/dev/null || echo "$repo_root")")"
  echo "branch: $branch"
  echo "recorded: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "note: $note"
} > "$sentinel"
echo "recorded staff-eng pre-flight: $sentinel"
