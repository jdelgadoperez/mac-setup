# Personal Claude Code Configuration

This file contains my personal preferences and guidelines for Claude Code across all projects.

## Who I Am

I am a Senior Software Engineer with backgrounds in API and web development, NestJS, SQL, PostgreSQL, MySQL, Temporal, React, Angular, AWS, Terraform, Docker, and Bash. I have worked in the industry for over 15 years, with over 10 years in TypeScript. Always answer me with responses that align with my knowledge level.

## Personal Coding Preferences

- Take your time to come up with the best answer vs rushing to the fastest response
- Prefer easy to read code that aligns with best practice over clever code
- Prefer code that is named with clarity and doesn't use abbreviations
- Prefer not to add unnecessary dependencies - use existing dependencies or custom functions where reasonable
- Always have strong typing
- Do not hard code values in expect statements while writing tests
- Prefer JavaScript Date objects over Moment. Use date-fns if available
- Give me an outline of your approach and changes before making them
- Do not add unnecessary comments. Comments should only clarify non-obvious things and add context, not restate what the code is already doing
- Use Context7 to understand latest dependency and SDK documentation
- **[Important]** Avoid type assertions as much as possible, with the exception of writing tests. NEVER use the `!` assertion
- Prefer smaller, themed commits over large grouped commits
- **[Important]** Do NOT add the Claude co-authored footer to commits or PR descriptions

## Git Safety Rules

- **NEVER push to `release` or `main` branches from local machine**
- Always create feature branches for work
- If no ticket exists, use `feat/` prefix instead of making up a ticket number
- Use `git -C <path>` instead of `cd`-ing into directories to avoid shell hook issues

## Git Worktree Workflow

When working on multiple things in a single repo, use git worktrees instead of switching branches.

```bash
# List existing worktrees
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

Worktrees are sibling directories to the repository:
```
/projects/
├── my-repo/                    # Main repo (stays on default branch)
├── my-repo-feature-branch/     # Worktree for feature work
```

## PR Preferences

- All PR descriptions should ease the review experience - focus on clarity, context, and making it easy for reviewers to understand what changed and why

## Bash Command Preferences

- Keep bash commands simple - run one at a time when possible
- Avoid chaining commands with `&&` - it causes hangs and failures
- Use normal `git` commands instead of absolute paths like `/usr/bin/git`

## Node Version Management

- I do not use `nvm`. All repos use `fnm` instead: https://github.com/Schniz/fnm
- Run `fnm use` to switch to project-specific Node version
