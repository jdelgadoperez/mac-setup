# CodeGraph Knowledge Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a self-maintaining CodeGraph knowledge agent that indexes all 14 repos under `~/projects`, re-indexes each on merge to `main` via a non-blocking git hook, and adds a `/codegraph-feature-scope` command that queries the graph cross-project for terminology, reusable components, integration points, and convention conflicts.

**Architecture:** Three independent units. Unit 1 (indexing) is a one-time operational task run via the `codegraph` CLI. Unit 2 (re-index) is two bash scripts stored in `mac-setup/dotfiles/.claude/scripts/` and synced to `~/.claude/scripts/` — a shared `post-merge` hook body and an idempotent installer that symlinks it into each repo's `.git/hooks/`. Unit 3 (query) is a slash-command markdown file at `mac-setup/dotfiles/.claude/commands/codegraph/feature-scope.md`, synced to `~/.claude/commands/codegraph/`.

**Tech Stack:** `codegraph` CLI v1.2.0, Bash, git hooks (`core.hooksPath`-free, per-repo `.git/hooks/post-merge` symlink), Claude Code slash commands (markdown with frontmatter), the `codegraph` MCP server (`codegraph_explore`).

## Global Constraints

- All scripts and commands live under `mac-setup/dotfiles/.claude/` and are synced to `~/.claude/` — never write setup to `~/.claude/` directly as the source of truth.
- The post-merge hook MUST always `exit 0` — it must never block or fail a merge, even when `codegraph` is missing or `sync` fails.
- Use `codegraph sync --quiet` in the hook (the CLI's hook-intended path), not full `index`.
- Target repo set: the 14 git repos under `~/projects` (`cvforge`, `dp.github.io`, `home-lab`, `jdelgadoperez.github.io`, `job-hunt`, `job-hunter`, `job-hunter.wiki`, `memory-bank`, `mac-setup`, `paperboy`, `sandbox`, `spotify-exit`, `status-monitor`, `substacker`).
- Bash style per user rules: one command per line where practical, avoid `&&` chaining, use `git -C <path>` sparingly (fnm hang risk) — prefer `cd` then git for git ops, use absolute paths otherwise.
- No Claude co-authored footer on commits. Conventional Commit messages.
- `.codegraph/` must be gitignored in every target repo (`codegraph init` does this automatically; verify).

---

## File Structure

- `mac-setup/dotfiles/.claude/scripts/codegraph-post-merge-hook.sh` — hook body; runs `codegraph sync --quiet` on merges into `main`, always exits 0. (Create)
- `mac-setup/dotfiles/.claude/scripts/install-codegraph-hooks.sh` — installer; symlinks the hook into each repo's `.git/hooks/post-merge`, idempotent, skips pre-existing non-symlink hooks. (Create)
- `mac-setup/dotfiles/.claude/commands/codegraph/feature-scope.md` — slash command definition. (Create)
- `~/.claude/scripts/`, `~/.claude/commands/codegraph/` — sync targets (symlink or copy per existing dotfiles sync mechanism). (Modify/verify)

---

## Task 1: Initial indexing of all 14 repos

**Files:**
- No source files created; operational task. Produces `.codegraph/` dirs in the 8 unindexed repos and refreshes the 6 indexed ones.

**Interfaces:**
- Consumes: `codegraph` CLI v1.2.0 on PATH.
- Produces: every target repo has `codegraph status --json` reporting `"initialized": true` with `nodeCount > 0`.

- [ ] **Step 1: Confirm the CLI version**

Run: `codegraph --version`
Expected: `1.2.0`

- [ ] **Step 2: Index the 8 unindexed repos**

Run each (one per line; `init` builds the index by default in v1.2.0):

```bash
codegraph init /Users/jessdelgadoperez/projects/dp.github.io
codegraph init /Users/jessdelgadoperez/projects/home-lab
codegraph init /Users/jessdelgadoperez/projects/jdelgadoperez.github.io
codegraph init /Users/jessdelgadoperez/projects/job-hunt
codegraph init /Users/jessdelgadoperez/projects/job-hunter.wiki
codegraph init /Users/jessdelgadoperez/projects/sandbox
codegraph init /Users/jessdelgadoperez/projects/status-monitor
```

Note: `substacker` was listed as already-indexed in the spec's inventory; the 8-repo "not indexed" list is dp.github.io, home-lab, jdelgadoperez.github.io, job-hunt, job-hunter.wiki, sandbox, status-monitor (7 repos — the spec text said "8" but the inventory table lists 7). Index exactly the 7 above. If `codegraph status` on any of the "already indexed" set reports `initialized: false`, add it here.

- [ ] **Step 3: Refresh the already-indexed repos**

Run each:

```bash
codegraph sync /Users/jessdelgadoperez/projects/cvforge
codegraph sync /Users/jessdelgadoperez/projects/job-hunter
codegraph sync /Users/jessdelgadoperez/projects/mac-setup
codegraph sync /Users/jessdelgadoperez/projects/memory-bank
codegraph sync /Users/jessdelgadoperez/projects/paperboy
codegraph sync /Users/jessdelgadoperez/projects/spotify-exit
codegraph sync /Users/jessdelgadoperez/projects/substacker
```

- [ ] **Step 4: Verify all 14 repos are initialized with a non-empty index**

Run this verification loop:

```bash
cd /Users/jessdelgadoperez/projects
for r in cvforge dp.github.io home-lab jdelgadoperez.github.io job-hunt job-hunter job-hunter.wiki memory-bank mac-setup paperboy sandbox spotify-exit status-monitor substacker; do
  init=$(codegraph status --json "$r" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('initialized'), d.get('nodeCount'))" 2>/dev/null)
  echo "$r -> $init"
done
```

Expected: every line prints `True <n>` with `<n>` greater than 0. Any `None None` or `True 0` line is a failure — re-run `codegraph init` on that repo.

- [ ] **Step 5: Verify `.codegraph/` is gitignored in every repo**

```bash
cd /Users/jessdelgadoperez/projects
for r in cvforge dp.github.io home-lab jdelgadoperez.github.io job-hunt job-hunter job-hunter.wiki memory-bank mac-setup paperboy sandbox spotify-exit status-monitor substacker; do
  if grep -q "codegraph" "$r/.gitignore" 2>/dev/null; then echo "$r ✓"; else echo "$r MISSING"; fi
done
```

Expected: every repo prints `✓`. For any `MISSING`, append `.codegraph/` to that repo's `.gitignore` (do not commit here — leave the working tree change for the repo owner, just report it).

- [ ] **Step 6: No commit for this task**

This task mutates local index state only (`.codegraph/` is gitignored). Nothing to commit. Report the verification output as the deliverable.

---

## Task 2: The post-merge hook body

**Files:**
- Create: `/Users/jessdelgadoperez/projects/mac-setup/dotfiles/.claude/scripts/codegraph-post-merge-hook.sh`
- Test: manual, exercised in Task 4 after install.

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: an executable script that, when invoked as a `post-merge` hook from inside a repo, runs `codegraph sync --quiet` for that repo's root when the current branch is `main`, and always exits 0.

- [ ] **Step 1: Write the hook script**

Create `/Users/jessdelgadoperez/projects/mac-setup/dotfiles/.claude/scripts/codegraph-post-merge-hook.sh`:

```bash
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
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x /Users/jessdelgadoperez/projects/mac-setup/dotfiles/.claude/scripts/codegraph-post-merge-hook.sh`

- [ ] **Step 3: Syntax-check the script**

Run: `bash -n /Users/jessdelgadoperez/projects/mac-setup/dotfiles/.claude/scripts/codegraph-post-merge-hook.sh`
Expected: no output, exit 0.

- [ ] **Step 4: Verify it exits 0 when not on main (unit behavior)**

Simulate the non-main branch path by running from a repo where HEAD is not `main`. Use a lightweight check — run the script from inside `mac-setup` on a temp branch:

```bash
cd /Users/jessdelgadoperez/projects/mac-setup
git branch codegraph-hook-test 2>/dev/null || true
git checkout codegraph-hook-test 2>&1 | tail -1
bash /Users/jessdelgadoperez/projects/mac-setup/dotfiles/.claude/scripts/codegraph-post-merge-hook.sh
echo "exit=$?"
git checkout main 2>&1 | tail -1
git branch -D codegraph-hook-test 2>&1 | tail -1
```

Expected: `exit=0` and no `codegraph sync` runs (no sync output). This proves the branch guard works.

- [ ] **Step 5: Verify it exits 0 when codegraph is absent from PATH**

```bash
cd /Users/jessdelgadoperez/projects/mac-setup
env PATH=/usr/bin:/bin bash /Users/jessdelgadoperez/projects/mac-setup/dotfiles/.claude/scripts/codegraph-post-merge-hook.sh
echo "exit=$?"
```

Expected: `exit=0` with a `codegraph not on PATH; skipping` warning on stderr. (Note: HEAD is `main` here so it passes the branch guard and reaches the PATH check.)

- [ ] **Step 6: Commit**

```bash
cd /Users/jessdelgadoperez/projects/mac-setup
git add dotfiles/.claude/scripts/codegraph-post-merge-hook.sh
git commit -m "feat: add codegraph post-merge hook body"
```

---

## Task 3: The hook installer

**Files:**
- Create: `/Users/jessdelgadoperez/projects/mac-setup/dotfiles/.claude/scripts/install-codegraph-hooks.sh`
- Test: exercised in Task 4.

**Interfaces:**
- Consumes: `codegraph-post-merge-hook.sh` (Task 2) at the synced path `~/.claude/scripts/codegraph-post-merge-hook.sh`.
- Produces: after running, each target repo's `.git/hooks/post-merge` is a symlink to `~/.claude/scripts/codegraph-post-merge-hook.sh`; pre-existing non-symlink hooks are skipped with a warning; idempotent.

- [ ] **Step 1: Write the installer**

Create `/Users/jessdelgadoperez/projects/mac-setup/dotfiles/.claude/scripts/install-codegraph-hooks.sh`:

```bash
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
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x /Users/jessdelgadoperez/projects/mac-setup/dotfiles/.claude/scripts/install-codegraph-hooks.sh`

- [ ] **Step 3: Syntax-check**

Run: `bash -n /Users/jessdelgadoperez/projects/mac-setup/dotfiles/.claude/scripts/install-codegraph-hooks.sh`
Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
cd /Users/jessdelgadoperez/projects/mac-setup
git add dotfiles/.claude/scripts/install-codegraph-hooks.sh
git commit -m "feat: add codegraph hook installer"
```

---

## Task 4: Sync dotfiles and run the installer

**Files:**
- Modify/verify: `~/.claude/scripts/codegraph-post-merge-hook.sh`, `~/.claude/scripts/install-codegraph-hooks.sh` (sync targets).
- No new files.

**Interfaces:**
- Consumes: the two scripts from Tasks 2 & 3.
- Produces: all 14 repos have a working `post-merge` symlink; a real merge into main re-indexes without affecting the merge.

- [ ] **Step 1: Confirm the scripts are present at the synced path**

Run: `ls -l /Users/jessdelgadoperez/.claude/scripts/codegraph-post-merge-hook.sh /Users/jessdelgadoperez/.claude/scripts/install-codegraph-hooks.sh`

Expected: both files exist and are executable. If `~/.claude/scripts/` is a symlink to `mac-setup/dotfiles/.claude/scripts/` (check with `ls -ld ~/.claude/scripts`), they appear automatically. If the dotfiles use a copy-based sync, run that sync mechanism now (inspect `mac-setup` for a `sync`/`stow`/`install` script and use it). Do not hand-copy as a substitute for the real sync mechanism.

- [ ] **Step 2: Run the installer**

Run: `bash /Users/jessdelgadoperez/.claude/scripts/install-codegraph-hooks.sh`

Expected: `installed/updated: N, skipped: M` summary with N+M = 14. Note any `SKIP (existing non-symlink hook)` lines — those repos keep their existing hook by design.

- [ ] **Step 3: Verify one repo's hook is a correct symlink**

Run: `ls -l /Users/jessdelgadoperez/projects/job-hunter/.git/hooks/post-merge`
Expected: a symlink pointing to `~/.claude/scripts/codegraph-post-merge-hook.sh`.

- [ ] **Step 4: End-to-end merge test in one repo (real gate)**

Use `mac-setup` (already indexed). Capture the pre-merge index timestamp, make a trivial change on a branch, merge to main, confirm the index advanced and the merge succeeded:

```bash
cd /Users/jessdelgadoperez/projects/mac-setup
before=$(codegraph status --json . | python3 -c "import sys,json;print(json.load(sys.stdin)['lastIndexed'])")
echo "before: $before"
git checkout -b codegraph-merge-test 2>&1 | tail -1
date > .codegraph-hook-test-marker
git add .codegraph-hook-test-marker
git commit -m "test: codegraph hook merge marker" 2>&1 | tail -1
git checkout main 2>&1 | tail -1
git merge --no-ff codegraph-merge-test -m "test: merge codegraph hook marker" 2>&1 | tail -3
after=$(codegraph status --json . | python3 -c "import sys,json;print(json.load(sys.stdin)['lastIndexed'])")
echo "after:  $after"
```

Expected: the merge completes successfully, and `after` is a later timestamp than `before` (the hook fired `codegraph sync`). If they're equal, the hook did not run — inspect the symlink and re-run Step 2.

- [ ] **Step 5: Clean up the merge test**

```bash
cd /Users/jessdelgadoperez/projects/mac-setup
git rm .codegraph-hook-test-marker 2>&1 | tail -1
git commit -m "test: remove codegraph hook merge marker" 2>&1 | tail -1
git branch -D codegraph-merge-test 2>&1 | tail -1
```

Then verify a clean working tree relevant to our files: `git status --short | grep codegraph` should be empty.

- [ ] **Step 6: No additional commit**

The test commits above are self-contained cleanup. Report the before/after timestamps as the deliverable proving the hook works.

---

## Task 5: The `/codegraph-feature-scope` command

**Files:**
- Create: `/Users/jessdelgadoperez/projects/mac-setup/dotfiles/.claude/commands/codegraph/feature-scope.md`
- Test: dry-run invocation against a known-overlapping feature.

**Interfaces:**
- Consumes: all 14 repos indexed (Task 1), kept fresh (Tasks 2–4); the `codegraph` MCP `codegraph_explore` tool and/or `codegraph explore -p <repo>` CLI.
- Produces: a slash command that, given a feature description, returns inline: terminology found, reusable components (with `file:line`), a proposed integration point, and the four conflict flags.

- [ ] **Step 1: Confirm command namespace conventions**

Run: `ls /Users/jessdelgadoperez/projects/mac-setup/dotfiles/.claude/commands/`
Expected: existing namespace dirs (`manage/`, `memory/`, `review/`, `work/`). Create `codegraph/` alongside them.

- [ ] **Step 2: Write the command file**

Create `/Users/jessdelgadoperez/projects/mac-setup/dotfiles/.claude/commands/codegraph/feature-scope.md`:

```markdown
---
name: codegraph-feature-scope
description: Query CodeGraph across all indexed projects to ground a new feature in existing terminology, reusable components, and integration points — and flag convention conflicts before planning.
arguments:
  - name: feature_description
    description: Free-text description of the feature to scope (e.g. "add rate limiting to job-hunter's API").
    required: true
allowed-tools: Bash, mcp__codegraph__codegraph_explore, Read, Grep, Glob
---

# /codegraph-feature-scope

Ground a new feature in what already exists across all indexed `~/projects`
repos **before** any implementation plan is written. Answer entirely inline —
do not write a report file.

## Target repos

The 14 indexed repos under `~/projects`:
cvforge, dp.github.io, home-lab, jdelgadoperez.github.io, job-hunt, job-hunter,
job-hunter.wiki, memory-bank, mac-setup, paperboy, sandbox, spotify-exit,
status-monitor, substacker.

## Flow

### 1. Derive search terms
From `$feature_description`, extract the core concept plus likely symbol names,
domain nouns, and verbs (e.g. "rate limiting" → `rateLimit`, `throttle`,
`RateLimiter`, `limiter`, `429`). List the terms you'll search before querying.

### 2. Fan out across projects
For each target repo, call `codegraph_explore` with that repo's path as
`projectPath` and the derived terms as the query. (CLI equivalent for any repo
the MCP call can't reach: `codegraph explore -p <repo-path> "<terms>"`.)
Query each project independently — do not infer one project's result from
another's.

Report coverage up front: which projects returned relevant hits, which returned
nothing, and any project you could not query (stale/missing index). Never
present a partial sweep as complete.

### 3. Synthesize existing knowledge (inline)
- **Terminology found** — what the codebase already calls this concept, so new
  code matches existing vocabulary. Cite the repo and `file:line`.
- **Reusable components** — ScanScope-style fits: existing symbols/patterns to
  reuse or extend rather than rebuild. Cite `file:line` for each.
- **Proposed integration point** — the single cleanest place to add the feature,
  grounded in the code above (not greenfield). Name the file and the symbol it
  attaches to.

### 4. Convention conflict checks (all four)
- **Naming / terminology drift** — same concept named differently across
  projects, or the same name meaning different things.
- **Duplicate / near-duplicate implementations** — the same utility/pattern
  built independently in ≥2 projects (a reuse opportunity).
- **Structural / pattern conflicts** — incompatible architectural approaches to
  the same problem class that would make a shared abstraction awkward.
- **Dependency / version conflicts** — the same library at different major
  versions across projects (matters if extracting shared code).

Report each conflict type explicitly, even if the finding is "none".

### 5. Handback
End with: terminology to adopt, the recommended integration point, conflicts to
resolve first, and an offer to proceed into `writing-plans` grounded in these
findings. Do not start planning inside this command.

## Anti-patterns

| Anti-pattern | Correct pattern |
|--------------|-----------------|
| Answer from one repo's grep | Fan out across all 14 indexed repos via codegraph_explore |
| Present a partial sweep as complete | Report per-project coverage; flag any repo you couldn't query |
| Propose a greenfield integration point | Anchor to an existing file:symbol from the query results |
| Skip a conflict category because nothing obvious | Report all four categories explicitly, "none" included |
| Write a report file | Answer inline — this feeds writing-plans directly |
| Fabricate file:line citations | Only cite locations returned by codegraph_explore |
```

- [ ] **Step 3: Verify the command file parses (frontmatter present, well-formed)**

Run: `head -12 /Users/jessdelgadoperez/projects/mac-setup/dotfiles/.claude/commands/codegraph/feature-scope.md`
Expected: valid YAML frontmatter with `name`, `description`, `arguments`, `allowed-tools`.

- [ ] **Step 4: Verify the underlying cross-project query mechanism works**

Prove `codegraph explore -p` returns real citations for a known concept, so the command has a working substrate:

```bash
codegraph explore -p /Users/jessdelgadoperez/projects/job-hunter "job application status" 2>&1 | head -30
```

Expected: output includes real symbol names and `file:line`-style references from `job-hunter`. If empty, the index for that repo is stale — re-run `codegraph sync` (Task 1).

- [ ] **Step 5: Commit**

```bash
cd /Users/jessdelgadoperez/projects/mac-setup
git add dotfiles/.claude/commands/codegraph/feature-scope.md
git commit -m "feat: add /codegraph-feature-scope command"
```

- [ ] **Step 6: Sync and smoke-test the live command**

Confirm the command is available at the synced path:

Run: `ls -l /Users/jessdelgadoperez/.claude/commands/codegraph/feature-scope.md`
Expected: file present (via the same sync mechanism confirmed in Task 4 Step 1).

Then, in a Claude Code session, invoke `/codegraph-feature-scope "add job application status filtering"` and confirm the response: lists search terms, reports per-project coverage, cites real `file:line` locations, proposes an integration point anchored to an existing symbol, and reports all four conflict categories. This is the real gate for Unit 3.

---

## Self-Review

**Spec coverage:**
- Index all 14 repos → Task 1. ✓
- Re-index on merge to main (post-merge hook) → Tasks 2–4. ✓
- Shared script + installer distribution → Tasks 2, 3, 4. ✓
- Non-blocking hook (always exit 0) → Task 2 Steps 4–5 test both guard paths. ✓
- `/codegraph-feature-scope` with terminology + reusable components + integration point → Task 5. ✓
- All four conflict checks → Task 5 command body Step 4 + anti-patterns. ✓
- Inline output, no report file → Task 5 command body + anti-pattern row. ✓
- `.codegraph/` gitignored → Task 1 Step 5. ✓
- Scripts/commands in mac-setup, synced → Global Constraints + Tasks 4, 5. ✓
- Coverage reporting (flag skipped projects) → Task 5 Step 2 + anti-pattern. ✓
- Pre-existing hook preserved → Task 3 Step 1 installer logic. ✓

**Discrepancy resolved:** The spec's prose said "8 unindexed" but its inventory table lists 7 (dp.github.io, home-lab, jdelgadoperez.github.io, job-hunt, job-hunter.wiki, sandbox, status-monitor). Task 1 indexes those 7 and re-syncs the 7 already-indexed (cvforge, job-hunter, mac-setup, memory-bank, paperboy, spotify-exit, substacker) = 14 total. Verification loop (Step 4) is the backstop: it asserts all 14, catching any miscount.

**Placeholder scan:** No TBD/TODO/"handle edge cases". Error handling is concrete (branch guard, PATH guard, sync-fail guard all shown as code). ✓

**Type/name consistency:** `codegraph-post-merge-hook.sh` and `install-codegraph-hooks.sh` referenced identically across Tasks 2–4. `$hook_src` path (`~/.claude/scripts/codegraph-post-merge-hook.sh`) consistent between installer and sync verification. Command name `codegraph-feature-scope` consistent between frontmatter and invocation. ✓
