---
name: multi-commit
description: Use when you have changed files across multiple git repos and want to group changes by theme, get confirmation, then commit and push each repo.
---

## Inputs

If the user didn't specify repos, ask: "Which repos? (absolute paths or ~ paths)"

Accept space-separated paths, a bullet list, or inline text — normalize to absolute paths.

## Step 1 — Collect state across all repos

For each repo, run in parallel:
```bash
git -C <path> status --short
git -C <path> diff --stat HEAD
```

Skip repos with no changes (report them as "nothing to commit").

## Step 2 — Propose themed commit plan

Group ALL changed files (across all repos) into logical themes. A theme = one conventional commit that may touch one or more repos.

**Grouping rules:**
- One theme per logical change, not per file or per repo
- A theme may span multiple repos (e.g., a fix that changes both a library and its consumer)
- Unrelated changes in the same repo become separate themes
- Use prefixes: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`
- Message format: `<prefix>: <short imperative subject>` — no body, no footer

**Present the plan as a table:**

| Theme | Message | Repo | Files |
|-------|---------|------|-------|
| 1 | fix: handle missing hook on install | ~/projects/memory-bank | hooks.py, installer.py |
| 1 | fix: handle missing hook on install | ~/projects/mac-setup | setup.sh |
| 2 | docs: update install instructions | ~/projects/memory-bank | README.md |

Then ask: **"Confirm this plan, or tell me what to adjust (messages, groupings, file assignments)?"**

Do not proceed until the user confirms or approves adjusted plan.

## Step 3 — Commit and push, theme by theme

Process one theme at a time. For each theme:

1. For each affected repo (in the order listed in the plan):
   ```bash
   git -C <path> add <file1> <file2> ...
   git -C <path> commit -m "<message>"
   git -C <path> push
   ```
2. Report the commit SHA immediately after each push:
   `✓ memory-bank — abc1234 — fix: handle missing hook on install`
3. If push fails: stop, report the error, do not continue to next repo or theme.

After all themes are done, print a final summary:
- Repos touched
- Commit SHAs per repo
- Any repos skipped (nothing to commit)

## Hard rules

- Use `git -C <path>` — never `cd` into repos
- No co-authored-by footer in any commit message
- Never commit without explicit user confirmation of the plan
- Never auto-push a repo that was not in the confirmed plan
- If any commit or push fails, stop immediately and show the full error
