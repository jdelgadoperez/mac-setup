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

# Create worktree for NEW branch
git worktree add -b <branch-name> ../<repo>-<branch-name>

# Create worktree for EXISTING branch
git worktree add ../<repo>-<branch-name> <branch-name>

# Remove worktree when done
git worktree remove ../<repo>-<branch-name>

# Clean up stale references
git worktree prune
```

## Naming Convention

Worktrees are sibling directories to the repository:
```
/projects/
├── my-app/                           # Main repo (stays on default branch)
├── my-app-feat-add-export/           # Worktree for feature work
├── other-repo/                       # Main repo
├── other-repo-fix-button/            # Worktree for fix
```

## Rules

1. **NEVER checkout branches in main working directory** - always create worktree
2. **Keep main directory on default branch** (main/master/release) for reference
3. **Run all task commands in worktree directory**, not main directory
4. **Inform user which worktree you're working in**
5. **Full autonomy in worktrees:** commit and push without permission (worktrees only, not main)

## Example Workflow

```bash
# 1. From main repo, create worktree for a branch
cd my-app
git worktree add -b feat/add-export ../my-app-feat-add-export

# 2. Work in worktree
cd ../my-app-feat-add-export
# ... make changes ...

# 3. Commit and push (no permission needed in worktrees)
git add .
git commit -m "feat(exports): add CSV export"
git push -u origin feat/add-export

# 4. When merged, clean up
cd ../my-app
git worktree remove ../my-app-feat-add-export
```
