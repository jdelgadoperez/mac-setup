# fnm Bash Hang — Workaround

`fnm` auto-switches Node versions when `cd` detects a `.nvmrc` file. This causes bash commands that `cd` into project directories to hang indefinitely. Any repo with a `.nvmrc` or `.node-version` file is a potential trigger.

## Rules

- **For git commands:** `cd` into the directory first, then run git (the `cd-git-allow.sh` hook auto-approves safe `cd` commands and blocks `git -C`)
- **For gh CLI:** Use `--repo <org>/<repo>` and `--head <branch>` flags — never `cd` first
- **For other tools:** Use absolute paths; avoid `cd` into any repo directory that has a `.nvmrc` file

## Examples

```bash
# Good — cd is auto-approved by hook
cd /path/to/repo-with-nvmrc
git status
gh pr view 123 --repo myorg/myrepo

# Bad — git -C is blocked by the cd-git-allow.sh hook
git -C /path/to/repo-with-nvmrc status
```
