## Git Safety Rules

- For collaborative or work repos, always create feature branches — never push directly to main
- For solo personal projects, push directly to `main` — no PR or feature branch needed
- If no ticket exists, use `feat/` prefix instead of making up a ticket number
- Use `git -C <path>` instead of `cd`-ing into directories to avoid shell hook issues
- If `gh pr create` fails for any reason, immediately fall back to providing the manual GitHub URL
  for PR creation — do not retry. Fail fast and let the user complete it manually.

## Git Worktree Workflow

When working on multiple things in a single repo, use git worktrees instead of switching branches.

Preferred worktree location: a sibling of the main checkout, named `<repo>-<TICKET>` — i.e.
`../<repo>-<TICKET>` relative to the main checkout. With no ticket, use `<repo>-<short-branch-slug>`.

```
projects/
├── my-app/              # main checkout (stays on the default branch)
├── my-app-ABC-123/      # worktree for ticket ABC-123
└── my-app-fix-login/    # worktree with no ticket
```

```bash
# List existing worktrees
git worktree list

# Create worktree for NEW branch — create the branch first, then add the worktree
git branch --no-track <branch> origin/main
git worktree add ../<repo>-<TICKET> <branch>

# Create worktree for EXISTING branch
git worktree add ../<repo>-<TICKET> <branch>

# Move a misplaced worktree
git worktree move <old-path> ../<repo>-<TICKET>

# Remove worktree when done
git worktree remove ../<repo>-<TICKET>

# Clean up stale references
git worktree prune
```

Avoid `git worktree add -b` and tracking branch creation: both write upstream config to `.git/config`,
which the Claude Code sandbox blocks (`could not lock config file .git/config`) — the branch is created
but the worktree isn't. `--no-track` skips that write; `git push -u` sets the upstream later.

## Shell & Environment Cleanup

When removing or replacing shell tools, CLIs, or aliases, always verify and clean up:
- Symlinks in `~/.oh-my-zsh/custom/`, `~/bin/`, `~/.local/bin/`
- Shell aliases in `.zshrc`, `.bashrc`, or oh-my-zsh custom plugin files
- Wrapper scripts or cached references pointing to the old tool name

Do not consider a removal or migration task complete until these are verified clean.

## Merging & PRs

- For solo personal projects, push directly to `main` — no PR needed
- For collaborative repos, all PR descriptions should ease the review experience — focus on clarity,
  context, and making it easy for reviewers to understand what changed and why
