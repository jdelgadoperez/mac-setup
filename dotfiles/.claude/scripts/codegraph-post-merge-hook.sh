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
if [ "$branch" != "main" ]; then
  # Only re-index on merges into main.
  exit 0
fi

if ! command -v codegraph >/dev/null 2>&1; then
  echo "codegraph-post-merge: codegraph not on PATH; skipping re-index" >&2
  exit 0
fi

if ! codegraph sync --quiet "$repo_root" >&2; then
  echo "codegraph-post-merge: sync failed for $repo_root (merge unaffected)" >&2
fi

exit 0
