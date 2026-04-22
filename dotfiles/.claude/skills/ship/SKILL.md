---
name: ship
description: Stage changed files, write conventional commit messages grouped by theme, commit, and push. Use after implementation is done and tests pass.
---

1. Run `git status` and `git diff --stat` to see all changed files
2. Group changes into logical themes — each theme becomes one commit. Common prefixes: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`
3. If more than one theme, list the proposed split and ask for confirmation before committing
4. Write conventional commit messages (short imperative subject, no co-authored footer per CLAUDE.md)
5. Stage and commit each group in dependency order (e.g., config before code that uses it)
6. Push to origin
7. Report the commit SHAs and one-line summaries
