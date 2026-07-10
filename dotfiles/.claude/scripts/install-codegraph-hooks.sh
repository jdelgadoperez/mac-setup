#!/usr/bin/env bash
# Install the shared codegraph post-merge hook into every git repo under
# ~/projects by symlinking .git/hooks/post-merge to the shared hook body.
# Idempotent. Skips repos that already have a non-symlink post-merge hook.
set -u

projects_dir="${1:-$HOME/projects}"
hook_src="$HOME/.claude/scripts/codegraph-post-merge-hook.sh"

if [ ! -f "$hook_src" ]; then
  echo "ERROR: hook body not found at $hook_src (is dotfiles synced?)" >&2
  exit 1
fi

installed=0
skipped=0
for gitdir in "$projects_dir"/*/.git; do
  [ -d "$gitdir" ] || continue
  repo="$(dirname "$gitdir")"
  hook_dst="$gitdir/hooks/post-merge"

  if [ -L "$hook_dst" ]; then
    # Already a symlink — repoint it (handles moved hook source).
    ln -sf "$hook_src" "$hook_dst"
    echo "updated: $repo"
    installed=$((installed + 1))
    continue
  fi

  if [ -e "$hook_dst" ]; then
    echo "SKIP (existing non-symlink hook): $repo" >&2
    skipped=$((skipped + 1))
    continue
  fi

  mkdir -p "$gitdir/hooks"
  ln -s "$hook_src" "$hook_dst"
  echo "installed: $repo"
  installed=$((installed + 1))
done

echo "---"
echo "installed/updated: $installed, skipped: $skipped"
