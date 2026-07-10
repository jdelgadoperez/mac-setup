#!/usr/bin/env bash
# CodeGraph post-merge hook body (shared, symlinked into each repo's
# .git/hooks/post-merge by install-codegraph-hooks.sh).
#
# Re-indexes the repo after a merge into main. MUST NEVER block or fail a
# merge: every path exits 0.

# git runs post-merge hooks from the repo's top-level working directory.
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$repo_root" ]; then
  echo "codegraph-post-merge: not inside a git work tree; skipping" >&2
  exit 0
fi

branch="$(git symbolic-ref --short HEAD 2>/dev/null)"

default_branch="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"
default_branch="${default_branch#origin/}"

if [ -n "$default_branch" ]; then
  # origin/HEAD is set — re-index only on the true default branch.
  if [ "$branch" != "$default_branch" ]; then
    exit 0
  fi
else
  # No origin/HEAD — fall back to the common default branch names.
  if [ "$branch" != "main" ] && [ "$branch" != "master" ]; then
    exit 0
  fi
fi

if ! command -v codegraph >/dev/null 2>&1; then
  echo "codegraph-post-merge: codegraph not on PATH; skipping re-index" >&2
  exit 0
fi

if codegraph status --json "$repo_root" 2>/dev/null | grep -q '"initialized":true'; then
  if ! codegraph sync --quiet "$repo_root" >&2; then
    echo "codegraph-post-merge: sync failed for $repo_root (merge unaffected)" >&2
  fi
else
  # Never indexed — do the one-time init so future syncs work.
  if ! codegraph init "$repo_root" >&2; then
    echo "codegraph-post-merge: init failed for $repo_root (merge unaffected)" >&2
  fi
fi

exit 0
