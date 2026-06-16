#!/usr/bin/env bash
# clean-stale-git-lock.sh — Safely remove a stale .git/index.lock
#
# Usage:
#   clean-stale-git-lock.sh <repo-path>
#
# Exit codes:
#   0  Lock cleared, or no lock present (idempotent success)
#   1  Lock present and actively held by a live git process — refused
#   2  Bad arguments / repo not found
#
# Behavior: checks <repo>/.git/index.lock. If absent, exits 0. If present,
# uses lsof to detect a live holder. Refuses to remove a held lock. Reports
# lock age before removal.

set -euo pipefail

repo="${1:-}"

if [[ -z "$repo" ]]; then
  echo "usage: $0 <repo-path>" >&2
  exit 2
fi

if [[ ! -d "$repo/.git" ]] && [[ ! -f "$repo/.git" ]]; then
  echo "not a git repo: $repo" >&2
  exit 2
fi

# Resolve git dir (handles worktrees where .git is a file pointing to gitdir)
if [[ -f "$repo/.git" ]]; then
  gitdir=$(sed -n 's/^gitdir: //p' "$repo/.git")
  # Make absolute if relative
  case "$gitdir" in
    /*) ;;
    *) gitdir="$repo/$gitdir" ;;
  esac
else
  gitdir="$repo/.git"
fi

lock="$gitdir/index.lock"

if [[ ! -e "$lock" ]]; then
  echo "OK   no lock at $lock"
  exit 0
fi

# Check for live holder
holder=$(lsof -t -- "$lock" 2>/dev/null || true)
if [[ -n "$holder" ]]; then
  echo "HELD lock at $lock held by pid(s): $holder" >&2
  ps -p $holder -o pid=,command= 2>/dev/null >&2 || true
  exit 1
fi

# Stat age (macOS BSD stat)
mtime=$(stat -f %m "$lock" 2>/dev/null || echo 0)
now=$(date +%s)
age=$((now - mtime))

rm -f "$lock"
echo "OK   removed stale lock at $lock (age: ${age}s)"
exit 0
