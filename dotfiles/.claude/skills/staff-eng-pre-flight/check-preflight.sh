#!/usr/bin/env bash
# Exit 0 if a staff-eng pre-flight sentinel exists for the current HEAD of <repo-root>.
# Exit 1 if not (and print the missing path). Exit 2 on usage/repo error.
# Used by the pre-push-checks hook to gate gh pr create / review-requests.
set -uo pipefail

repo_root="${1:-$PWD}"
sha="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null)" || { echo "not-a-git-repo: $repo_root" >&2; exit 2; }

sentinel="$HOME/.claude/.staff-preflight/${sha}.done"
if [[ -f "$sentinel" ]]; then
  exit 0
fi
echo "$sentinel"
exit 1
