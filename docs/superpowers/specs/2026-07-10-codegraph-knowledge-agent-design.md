# Self-Maintaining CodeGraph Knowledge Agent — Design

**Date:** 2026-07-10
**Status:** Approved (design), pending implementation plan

## Objective

Stand up a self-maintaining code knowledge agent backed by CodeGraph that:

1. Indexes all active projects under `~/projects`.
2. Automatically re-indexes each project when work merges to `main`.
3. Provides a `/codegraph-feature-scope` command that, given a new feature
   description, queries the graph across all projects to surface existing
   terminology, reusable components (ScanScope-style fits), and the cleanest
   integration point — flagging convention conflicts before any implementation
   plan is written.

## Current State

- `codegraph` CLI v1.2.0 is installed at `~/.local/bin/codegraph`.
- The `codegraph` MCP server is available and works per-project via a
  `projectPath` argument (no default project is set in this environment).
- 14 git repos live under `~/projects`. As of design time:
  - **Already indexed (6):** `cvforge`, `job-hunter`, `mac-setup`,
    `memory-bank`, `paperboy`, `spotify-exit`, `substacker` — several stale.
  - **Not indexed (8):** `dp.github.io`, `home-lab`, `jdelgadoperez.github.io`,
    `job-hunt`, `job-hunter.wiki`, `sandbox`, `status-monitor`.
- Command/script conventions: slash commands live in
  `~/.claude/commands/<namespace>/`, scripts in `~/.claude/scripts/`, both
  synced from `mac-setup/dotfiles/.claude/`.

## Scope Decisions

| Decision | Choice |
|----------|--------|
| Which projects to index | **All 14 git repos** under `~/projects`, including dormant ones. |
| Re-index trigger | **Local git `post-merge` hook** per repo (no CI dependency, works offline). |
| Hook distribution | **Shared script + install command** stored in `mac-setup/dotfiles`. |
| Feature query trigger | **Explicit slash command** `/codegraph-feature-scope`. Not auto-triggered. |
| Query output | **Inline conversational answer** — no report artifact. Feeds `writing-plans`. |
| Conflict checks | All four: naming/terminology drift, duplicate implementations, structural/pattern conflicts, dependency version conflicts. |

## Architecture

Three independent, well-bounded units.

### Unit 1 — Initial Indexing (one-time)

- **What it does:** Ensures every one of the 14 repos has a current
  `.codegraph/` index.
- **How:** Run `codegraph init <repo>` on each of the 8 unindexed repos; run
  `codegraph sync <repo>` (or `index` if stale enough to warrant a full rebuild)
  on the 6 already-indexed repos to refresh them.
- **Depends on:** `codegraph` CLI, read access to each repo.
- **Note:** `.codegraph/` directories are **not** committed to the target
  repos — they are local index state. Confirm each repo's `.gitignore` excludes
  `.codegraph/` (add it if missing) so the index never lands in a commit.

### Unit 2 — Re-index on Merge to Main

Two scripts, both stored in `mac-setup/dotfiles/.claude/scripts/` and synced to
`~/.claude/scripts/`.

**`codegraph-post-merge-hook.sh`** — the hook body, installed as each repo's
`.git/hooks/post-merge`:

- Runs after a successful `git merge` / `git pull` that updated the working tree.
- Determines the current branch; if not `main`, exits 0 silently (only re-index
  on merges into main).
- Runs `codegraph sync` for the repo root (`sync`, not full `index`, for speed;
  falls back is out of scope — sync is sufficient for incremental changes).
- **Never blocks or fails the merge:** all output goes to stderr, and the script
  always exits 0. On `codegraph sync` failure it logs a one-line warning and
  moves on. A broken index must never break the user's git workflow.
- Guards against re-entrancy / missing binary: if `codegraph` is not on PATH,
  exit 0 with a warning.

**`install-codegraph-hooks.sh`** — the installer:

- Iterates the 14 target repos under `~/projects` (repo list derived by scanning
  for `.git` directories, or a maintained explicit list — see Open Question).
- For each repo, symlinks `.git/hooks/post-merge` →
  `~/.claude/scripts/codegraph-post-merge-hook.sh`.
- If an existing non-symlink `post-merge` hook is present, it is **not**
  overwritten — the script warns and skips so pre-existing hooks are preserved.
- Idempotent: safe to re-run after adding a new repo.
- **Depends on:** the hook script existing at the synced path.

Because the hook is a **symlink** to the single shared script, updating hook
behavior means editing one file — no per-repo re-propagation needed (re-running
the installer is only required to add newly-created repos).

### Unit 3 — `/codegraph-feature-scope` Command

A project-namespaced slash command at
`mac-setup/dotfiles/.claude/commands/codegraph/feature-scope.md`, synced to
`~/.claude/commands/codegraph/feature-scope.md`.

**Input:** a free-text feature description (e.g., `"add rate limiting to
job-hunter's API"`).

**Flow:**

1. **Query.** For each indexed project, call `codegraph_explore` (MCP) or
   `codegraph explore` (CLI) with `projectPath` set to that repo, using search
   terms derived from the feature description (the concept, likely symbol names,
   the domain nouns/verbs). Cross-project fan-out; each project queried
   independently.
2. **Synthesize existing knowledge (inline):**
   - **Terminology found** — what the codebase already calls this concept
     (so new code matches existing vocabulary).
   - **Reusable components** — ScanScope-style fits: existing symbols/patterns
     that could be reused or extended rather than rebuilt, with `file:line`
     citations.
   - **Proposed integration point** — the cleanest place to add the feature,
     grounded in what already exists, not greenfield.
3. **Conflict checks (all four):**
   - **Naming/terminology drift** — same concept named differently across
     projects, or same name meaning different things.
   - **Duplicate/near-duplicate implementations** — the same utility/pattern
     built independently in ≥2 projects (reuse opportunity).
   - **Structural/pattern conflicts** — incompatible architectural approaches to
     the same problem class across projects that would make shared abstraction
     awkward.
   - **Dependency/version conflicts** — the same library at different major
     versions across projects (matters when extracting shared code).
4. **Output:** everything inline in the conversation. No file artifact. The
   result directly informs the subsequent `writing-plans` step.

**Depends on:** all 14 repos being indexed (Unit 1) and reasonably fresh
(Unit 2).

## Data Flow

```
describe feature
      │
      ▼
/codegraph-feature-scope "<desc>"
      │
      ├─► fan-out: codegraph_explore(projectPath=repo_i) for each of 14 repos
      │
      ▼
synthesize ── terminology ── reusable components ── integration point
      │
      ▼
conflict checks (naming / duplication / structural / dependency)
      │
      ▼
inline answer  ──►  writing-plans (implementation plan, grounded)
```

Re-index path (independent, continuous):

```
git merge → main  ──►  .git/hooks/post-merge (symlink)
                              │
                              ▼
                  codegraph-post-merge-hook.sh  ──►  codegraph sync (non-blocking)
```

## Error Handling

- **Hook failures never block git.** Script always exits 0; failures log to
  stderr only.
- **Missing `codegraph` binary:** hook and command degrade gracefully with a
  clear warning.
- **Unindexed / stale project during a query:** the command reports which
  projects it could and could not query (per the "flag skipped files up front"
  convention) rather than silently answering from a partial set.
- **Pre-existing `post-merge` hook:** installer preserves it and warns; no
  silent overwrite.

## Testing Strategy

- **Unit 1:** After indexing, `codegraph status <repo>` reports a non-empty
  index for all 14 repos.
- **Unit 2:** Install hooks, make a trivial change on a branch, merge to `main`
  in one test repo, confirm the index timestamp/stats advance and the merge
  itself is unaffected. Confirm a forced `codegraph sync` failure still exits 0
  and does not abort the merge.
- **Unit 3:** Run `/codegraph-feature-scope` with a feature known to overlap an
  existing pattern (e.g., something touching an existing utility) and confirm
  the command surfaces the real `file:line`, proposes a plausible integration
  point, and that a deliberately duplicated concept across two repos is flagged.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `.codegraph/` accidentally committed to a target repo | Unit 1 verifies/adds `.codegraph/` to each `.gitignore`. |
| Hook slows down every merge | `sync` is incremental; runs post-merge (non-blocking) and always exits 0. |
| Cross-project query is noisy / low-signal | Command derives targeted search terms and cites `file:line`; reports coverage so low-signal results are visible, not hidden. |
| Stale index gives wrong integration advice | Unit 2 keeps main fresh; command reports staleness/coverage per project. |
| Installer clobbers a user's existing hook | Installer skips non-symlink existing hooks and warns. |

## Success Criteria

- All 14 repos have a current CodeGraph index.
- Merging to `main` in any indexed repo refreshes its index automatically,
  without ever blocking or failing the merge.
- `/codegraph-feature-scope "<desc>"` returns, inline: existing terminology,
  reusable components with citations, a proposed integration point, and any of
  the four conflict types found across projects.
- All new scripts/commands live in `mac-setup/dotfiles/.claude/` and are synced,
  so the setup survives across machines/sessions.

## Open Questions (to resolve in planning)

- **Repo list source for the installer:** scan `~/projects` for `.git` dirs
  dynamically, or maintain an explicit allowlist? Dynamic is simpler and
  auto-includes new repos; explicit is more controlled. Leaning dynamic with the
  `.git`-scan approach.

## Out of Scope

- Automatic (non-command) triggering of the feature query on every mention of a
  feature in conversation — explicitly rejected as unreliable.
- CI-based (GitHub Actions) re-indexing — local hook only.
- Committing `.codegraph/` indexes to repos or sharing them across machines —
  each machine builds its own local index.
- Report-file artifacts from `/codegraph-feature-scope`.
