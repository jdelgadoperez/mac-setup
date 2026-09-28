---
name: worktree-workflow
description: "Git worktree workflow. Commands, naming conventions, rules, and example workflow. Use when creating worktrees, switching branches, or starting parallel work."
---

# Git Worktree Workflow

**RULE: ALWAYS use git worktrees instead of checking out branches in the main working directory.**

## When to Create a Worktree

| Trigger | Action |
|---------|--------|
| Starting new feature/bugfix/task | Create worktree |
| Checking out PR branch for review | Create worktree |
| Working on branch other than current | Create worktree |
| User wants parallel work on multiple tasks | Create worktree per task |

## Worktree Commands

```bash
# List existing worktrees (check first to avoid conflicts)
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

## Naming Convention

Worktrees are siblings of the main checkout, named `<repo>-<TICKET>`. With no ticket, use
`<repo>-<short-branch-slug>`:
```
/projects/
├── my-app/                           # Main checkout (stays on default branch)
├── my-app-ABC-123/                   # Worktree for ticket ABC-123
├── other-repo/                       # Main checkout
├── other-repo-fix-button/            # Worktree with no ticket
```

## Rules

1. **NEVER checkout branches in main working directory** - always create worktree
2. **Keep main directory on default branch** (main/master/release) for reference
3. **Run all task commands in worktree directory**, not main directory
4. **Inform user which worktree you're working in**
5. **Full autonomy in worktrees:** commit and push without permission (worktrees only, not main)

## Example Workflow

```bash
# 1. From main repo, create the branch, then a worktree for it
cd my-app
git branch --no-track ABC-123/add-export origin/main
git worktree add ../my-app-ABC-123 ABC-123/add-export

# 2. Work in worktree
cd ../my-app-ABC-123
# ... make changes ...

# 3. Commit and push (no permission needed in worktrees)
git add .
git commit -m "feat(exports): add CSV export"
git push -u origin ABC-123/add-export

# 4. When merged, clean up
cd ../my-app
git worktree remove ../my-app-ABC-123
```
