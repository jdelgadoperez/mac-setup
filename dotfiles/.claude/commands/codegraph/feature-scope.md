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
