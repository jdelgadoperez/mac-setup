# Orchestrated Command Conventions

Conventions for building and maintaining orchestrated commands in `~/.claude/commands/`. The pattern works well for multi-agent fan-out flows where independent collectors feed a single synthesizer.

Reference this file when writing or modifying any command that dispatches multiple agents in parallel.

## The core shape

Every orchestrated command follows this 6-step flow:

1. **Parse & prepare** — resolve inputs, create artifact dir
2. **Prereq check** — silent, fail-fast; no prompts if preconditions missing
3. **Parallel collection** — dispatch N agents simultaneously, each with a fixed output schema
4. **Narrowing (optional, always sequential)** — follow-up dispatch that depends on Step 3 outputs (e.g., Explore with hints). If included, Step 4 is *always sequential* — it can't exist without Step 3's artifacts.
5. **Synthesis** — one agent call consumes all artifacts, produces the final report
6. **Review & publish** — single approval gate, execute external actions only on explicit opt-in
7. **Summary (optional, conventional)** — terse post-flow report with artifact paths and links. Having a Step 7 summary is an accepted convention, not a violation of the "6-step flow" rule.

### The collector-synthesizer contract

Step 3 (collection) and Step 5 (synthesis) have distinct jobs:
- **Collectors capture facts.** Fixed schemas, no speculation, no cross-source inference. Each collector sees only its own inputs.
- **Synthesis produces judgment.** Cross-references artifacts, applies MoSCoW/triage categories, proposes actions.

This is the collector-synthesizer contract. Violating it (e.g., letting a collector infer root cause from PR titles) couples collectors to each other's outputs and breaks parallelism.

## Artifact conventions

### Directory
- Temp artifacts: `/tmp/{namespace}/{topic}/`
  - `namespace` = the command's preface (e.g., `review`, `triage`, `audit`)
  - `topic` = slug derived from the input (ticket key, PR number, symptom one-liner)
- Create with `mkdir -p`; never prompt for directory creation

### File schema
Each collector produces **one markdown file** with a fixed template the command specifies verbatim in its agent prompt. Examples:
- `symptom.md`, `github.md`, `prior.md`, `code.md` (triage commands)
- `spec.md`, `evidence.md`, `audit.md` (spec-audit commands)
- `threads.md`, `ticket.md`, `head-files.md`, `triage.md`, `plan.md` (feedback commands)

### Schema discipline
- Every collector prompt MUST include the exact markdown structure expected, with code block `|` tables and section headers
- Parseable > prose. Tables over paragraphs.
- Validation is mechanical (check for header presence, check table columns) — not semantic

## Report export

### Fixed paths
When publishing a report to the current repo, use this convention:

```
_reports/{namespace}/{topic}-{YYYY-MM-DD}.md
```

- Auto-create the directory if missing
- On collision (same topic + date), append `-2`, `-3`, etc.
- Predictable > organized. Don't ask the user where to save.

### Artifact preservation
Temp artifacts at `/tmp/{namespace}/{topic}/` are never auto-cleaned. They serve three purposes:
1. Debugging (if synthesis is wrong, inspect sources)
2. Resumability (re-run synthesis without re-collecting)
3. Audit trail

## Parallel dispatch rules

- **Never** send N separate agent calls when one agent can internally parallelize. Example: one agent handling a list of PRs — one call with the full list, not N calls.
- Parallel dispatch requires no shared state between agents. If agent B needs agent A's output, step them sequentially in Step 4.
- Speculative dispatch is acceptable when over-fetching is cheaper than waiting (e.g., Explore on the full PR file list rather than waiting for a collector to narrow it).
- **Ticket/context fetches are non-blocking.** A missing or failing ticket lookup must not stop the command. Write a sentinel (e.g., `# No linked ticket`) and proceed.

### The `# No linked ticket` sentinel

When a ticket fetch fails or is unavailable, write:

```markdown
# No linked ticket
```

Optionally with a comment:

```markdown
# No linked ticket
<!-- Lookup unavailable: {reason} -->
```

Synthesis treats this as a valid state, not an error. Do not fabricate acceptance criteria from the PR description — if there's no ticket, there are no ACs.

## Approval gate rules

### Default to view-only
Every command's final gate defaults to "view only" / "report only". External mutations (chat posts, PR comments, git pushes, tickets, work log edits) require explicit opt-in each run.

### Canonical gate vocabulary

Use the same verbs across commands so users don't have to learn per-command grammar:

| Term | Meaning |
|------|---------|
| **View only** (default) | Generate the report, write artifacts, don't touch external systems |
| **Preview** | Synonym of View only — OK in user-facing prompts |
| **Accept** / **Proceed** | Execute external actions (post, push, create, PATCH) |
| **Edit** | User describes a tweak; re-run synthesis with the edit guidance, re-present the same gate |
| **Cancel** | Exit without changes |

Do not invent new terms ("confirm", "submit", "go") — those work too but cost the user a translation step. Stay in this vocabulary.

### Single gate
After approval, the command runs to completion without additional prompts. If the command needs another decision mid-execution, the triage/synthesis step was under-specified — fix that, not paper it over with runtime prompts.

### Batch approvals for batch actions
When creating N tickets or posting N replies, one batch approval covers all. The user can edit individual items inside that prompt ("skip #3", "edit #5"). Never prompt per-item.

## Model routing

- Orchestrator (the command itself): main session, inherits user's model
- Search / Explore / general-purpose calls: pass `model: "sonnet"` unless deep reasoning is required
- Named subagents: use their frontmatter-declared model; do not override
- Synthesis calls: main session model — synthesis benefits from Opus when available

## Voice & tone

- Lead with the conclusion/verdict, not social framing
- Terse, first-person, direct
- End external messages with a handback or confirmation prompt; don't leave threads dangling

## External action safety

### Reversible vs irreversible
- **Reversible** (queries, Explore, artifact writes): parallel, unconstrained within scope budget
- **Irreversible** (chat posts, tickets, git pushes, verdict statements): gated, evidence-backed, explicit opt-in

### Ticket creation
- Use dry-run preview before creating
- Batch approval for N tickets
- Link created tickets back to the parent incident/epic

### Git push
- Always run pre-push checks first
- Never bypass hooks
- Never add `Co-Authored-By: Claude` footer

### Chat post
- Reply to the originating thread (never start a new one unless the command explicitly says to)
- Post the draft verbatim — don't re-edit between approval and post
- Log the posted message URL in the summary

## Frontmatter conventions

```yaml
---
name: {namespace}-{action}                    # kebab-case, must match file path
description: {one-line, starts with a verb}   # surfaces in skill lists
arguments:
  - name: {arg_name}
    description: {what it is, example format}
    required: true|false
allowed-tools: {comma-separated list}         # explicit; no wildcards unless MCP
---
```

`allowed-tools` must list every tool the command calls, including sub-agent names and skills. This enforces auditability — a reader can tell at a glance what the command can touch.

## Anti-patterns

Every command MUST include an Anti-Patterns table. Shared entries across commands:

| Anti-pattern | Correct pattern |
|--------------|-----------------|
| Re-ask the user after the main approval gate | One gate. If ambiguity arises mid-flow, triage was under-specified |
| Sequential dispatch of independent collectors | Parallel fan-out; use `run_in_background: true` for independent agents |
| Dump raw data (logs, diffs) into artifacts | Aggregate first; cite specific lines, don't paste whole bodies |
| Speculate in collector output | Collectors capture facts. Synthesis produces judgment. |
| Post/mutate without explicit opt-in | Default view-only; external actions are gated |
| Bare `repo#number` in tables | Always `[repo#number](url)` markdown links |
| Synthesize without citing artifacts | Every claim in the report cites its source artifact |

Command-specific anti-patterns go in the command's own file.

## Troubleshooting section

Every command MUST include a Troubleshooting section covering:
- Input-parsing failures (malformed URL, missing ticket)
- Collector-returns-empty (no data found, needs clarification)
- External action failures (post rejected, API error)
- Stale state (HEAD moved, CI re-running)

## When NOT to build an orchestrated command

- **One-off tasks** — the overhead of the spec isn't worth it
- **No repeated pattern** — if you've done it twice, maybe codify. Once, just do it.
- **Existing command fits with small changes** — extend rather than fork.
- **Pure data fetches with no synthesis** — a shell script or MCP capability fits better

## Skills vs commands

These conventions target **commands** — slash-invoked orchestration entry points with a single flow from parse to summary. Skills are different: they're invocable utilities, often composed into commands or dispatched ad-hoc. Not all conventions apply equally.

**Conventions that apply to both commands and skills:**

| Convention | Applies | Why |
|------------|---------|-----|
| Artifact dir convention (`/tmp/{namespace}/{topic}/`) | Both | Downstream tools parse these paths |
| Parallel dispatch when collectors are independent | Both | Performance + predictability |
| Schema discipline (fixed markdown templates) | Both | Synthesis depends on structure |
| Writing voice for external messages | Both | User-facing output |
| `model: sonnet` on built-in agents | Both | Cost control |

**Conventions that apply only when the skill orchestrates agents/tools:**

| Convention | Applies to skills when... |
|------------|---------------------------|
| Single approval gate with view-only default | Skill has external-mutation steps (post reviews, push code, create tickets) |
| Anti-Patterns section | Skill has non-obvious failure modes worth codifying |
| Troubleshooting section | Skill has external dependencies that can fail (API rate limits, stale indexes, missing config) |
| CLAUDE.md routing block | Skill is invoked by keyword triggers, not just by other commands |

**Conventions that don't apply to skills:**

- 6-step flow — skills often have 1-3 phases; don't force the shape.
- Fixed `_reports/{namespace}/` export path — skills rarely produce publishable reports directly; they feed synthesis in commands that own the export.

**Rule of thumb:** If a reader could invoke the skill directly (via slash command or agent dispatch) and it touches external state, it needs Anti-Patterns + Troubleshooting. If it's a pure utility library (string formatters, config readers) invoked only from other orchestration code, it doesn't.

## Maintenance

When adding a new command, review this doc and confirm:
- [ ] 6-step flow followed
- [ ] Artifact dir convention
- [ ] Fixed report path
- [ ] Parallel dispatch where possible
- [ ] Single approval gate with view-only default
- [ ] `model: sonnet` on Explore/search calls
- [ ] Anti-patterns table with relevant entries
- [ ] Troubleshooting section
- [ ] CLAUDE.md routing block added with trigger keywords

When updating an existing command, check if the change should propagate to siblings (if changing an approval-gate pattern, for example).
