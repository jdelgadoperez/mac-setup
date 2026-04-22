---
name: bug-swarm
description: Use when you have a bug report and want to investigate it across multiple local repos in parallel, with isolated git worktrees per repo and a unified commit plan at the end.
---

## Step 1 — Read the registry

```bash
cat ~/.config/bug-swarm/repos.yaml
```

Parse the repos list. Expand `~` in all `path` values to absolute paths before use.

## Step 2 — Derive a slug

From the bug report, derive a short kebab-case slug (max 30 chars) for the branch name.

Examples:
- "memory-bank ingest fails when Qdrant is unreachable" → `qdrant-unreachable-ingest`
- "PreCompact hook not installed by setup install" → `missing-precompact-hook`

## Step 3 — Select relevant repos

Read the bug report and each repo's `description`. Select repos that are plausibly related to the bug. **Err toward inclusion** — subagents self-report `RELEVANT: no` if nothing is found in their repo.

Never spawn more than one subagent per repo.

## Step 4 — Create worktrees for git repos

For each selected repo where `type` is `code` or `config`:

```bash
git -C <absolute-path> worktree add -b bug/<slug> \
  ~/.config/superpowers/worktrees/<name>/bug/<slug>
```

For `type: data` repos: no worktree. Pass the `path` directly to the subagent.

## Step 5 — Spawn subagents in parallel

Use the Agent tool to spawn one subagent per selected repo **simultaneously** (all in the same message, not sequentially).

Use this prompt template for each subagent, substituting the bracketed values:

---

````
You are investigating a bug in the [NAME] repo.

Working path: [WORKTREE_PATH or direct PATH]
Repo type: [TYPE]
Language: [LANG]
Test command: [TEST_CMD or "N/A"]

Bug report:
[FULL BUG REPORT TEXT]

---

Follow these steps exactly based on the repo type:

IF type is "code":
1. Grep the working path for function names, error strings, and symbols mentioned in the bug report.
2. Run the exact failing command from the bug report. Capture full output.
3. Write out your root cause hypothesis IN FULL before touching any file.
4. Draft a fix directly in the working path.
5. Run: [TEST_CMD]. Capture the full pass/fail output.

IF type is "config":
1. Grep the working path for patterns related to the bug report.
2. Identify all affected files.
3. Write out your root cause hypothesis IN FULL before touching any file.
4. Produce a unified diff of your proposed changes.

IF type is "data":
1. Grep [PATH] for content related to the bug report.
2. Identify all affected files.
3. Write out your root cause hypothesis IN FULL before touching any file.
4. Describe your proposed edits inline (no diff format needed).

Hard rules — no exceptions:
- Write your hypothesis BEFORE touching any file. This is required.
- Do NOT import, call, or reference any other registered repos (memory-bank, mac-setup, claude-agents, home-lab).
- If you cannot reproduce or find related code, say so explicitly. Do not fabricate findings.
- Do NOT run git commit or git push under any circumstances.

Return this exact structure with no extra commentary before or after:

REPO: [name]
TYPE: [type]
RELEVANT: [yes|no — if no, state why and fill remaining fields as "N/A"]
ROOT_CAUSE: [one paragraph, or "Unable to reproduce: <reason>"]
FILES: [comma-separated list of changed/proposed files, or "none"]
DIFF: [unified diff, inline edits, or "N/A"]
TEST_RESULT: ["pass" | "fail: <truncated output>" | "N/A"]
PROPOSED_COMMIT: [conventional commit message, or "N/A"]
CROSS_REPO_DEPS: ["none" | comma-separated list of external repo references introduced]
````

---

## Step 6 — Collect findings

Wait for all subagents to complete. Parse each structured report.

Filter out repos where `RELEVANT: no` — note them as "not involved" in the final plan.

## Step 7 — Check cross-repo dependencies

Scan all `CROSS_REPO_DEPS` fields. For any that are not "none":
1. Add a ⚠️ warning to the plan output
2. Do NOT include that change in the commit plan without explicit user approval
3. Describe an alternative approach that avoids the coupling

## Step 8 — Present the plan

```
## Bug Triage: <slug>

### Root Cause Summary
<one paragraph synthesizing findings across all relevant repos>

### Not Involved
<repo names that reported RELEVANT: no, or "(all repos involved)">

### Cross-repo Dependency Warnings
<⚠️ warnings, or "(none)">

### Per-repo Plan

#### <name>  branch: bug/<slug>
Hypothesis: <ROOT_CAUSE>
Files: <FILES>
Test: <TEST_RESULT>
Proposed commit: `<PROPOSED_COMMIT>`
<DIFF>

#### <name>  [direct edits — no worktree]
Hypothesis: <ROOT_CAUSE>
Files: <FILES>
Proposed edits: <DIFF or inline description>

---
Approve this plan? Reply "yes" to commit and push via /multi-commit.
Reply "no, discard" to clean up all worktrees.
Reply "no, keep" to leave worktrees open for manual inspection (paths listed below).
```

List all open worktree paths at the bottom for reference.

## Step 9 — On approval ("yes")

Invoke `/multi-commit` with:
- The worktree paths as the repo paths
- The confirmed commit messages from the plan

After `/multi-commit` completes, clean up every worktree created in Step 4:

```bash
git -C <absolute-repo-path> worktree remove \
  ~/.config/superpowers/worktrees/<name>/bug/<slug>
git -C <absolute-repo-path> worktree prune
```

## Step 10 — On rejection

If "no, discard": run the cleanup commands above for all worktrees, then stop.

If "no, keep": print all worktree paths and stop. The user will clean up manually when done.
