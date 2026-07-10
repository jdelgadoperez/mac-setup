# Personal Claude Code Configuration

This file contains my personal preferences and guidelines for Claude Code across all projects.

## Who I Am

I am a Senior Software Engineer with backgrounds in API and web development, NestJS, SQL, PostgreSQL, MySQL,
Temporal, React, Angular, AWS, Terraform, Docker, and Bash. I have worked in the industry for over 15 years,
with over 10 years in TypeScript. Always answer me with responses that align with my knowledge level.

## Personal Coding Preferences

- Take your time to come up with the best answer vs rushing to the fastest response
- Prefer easy to read code that aligns with best practice over clever code
- Prefer code that is named with clarity and doesn't use abbreviations
- Prefer not to add unnecessary dependencies - use existing dependencies or custom functions where reasonable
- Always have strong typing
- Do not hard code values in expect statements while writing tests
- Prefer JavaScript Date objects over Moment. Use date-fns if available
- Give me an outline of your approach and changes before making them
- Do not add unnecessary comments. Comments should only clarify non-obvious things and add context, not
  restate what the code is already doing
- Use Context7 to understand latest dependency and SDK documentation
- **[Important]** Avoid type assertions as much as possible, with the exception of writing tests. NEVER use
  the `!` assertion
- Prefer smaller, themed commits over large grouped commits
- **[Important]** Do NOT add the Claude co-authored footer to commits or PR descriptions

## Git

@rules/git.md

## PR Reviews

- [Important] When reviewing PRs, always use the multi-agent workflow with the agent selection step. Never skip agent selection — let the user confirm which agents to use before proceeding.
- Post all review findings as **inline comments on specific lines** — never as a single summary block
- **Distinguish initial vs re-review**: before dispatching agents, check prior review threads; if a prior review from you exists, scope agents to the diff-of-diff only (not the full PR)
- **After pushing fixes** in response to review feedback, always re-request reviews from the original reviewers
- Check **all four comment surfaces** before reviewing or declaring feedback addressed: inline comments, review submissions, conversation-level comments, and GraphQL `reviewThreads` (surfaces RESOLVED + OUTDATED threads)
- **Tone**: fewer nitpicks on staff/principal engineer PRs; frame structural suggestions as questions; never post unverified factual claims

## Git & Repo Hygiene

- Before any `git push`, verify the git root matches the intended repo for the branch being pushed
- Never stash an in-progress merge — complete it (`git commit`) or abort it (`git merge --abort`)
- Persist shell/config fixes to this machine-setup repo, not to local files — local writes don't survive across machines or sessions

## Bash Command Preferences

- Keep bash commands simple - run one at a time when possible
- Avoid chaining commands with `&&` - it causes hangs and failures
- Use normal `git` commands instead of absolute paths like `/usr/bin/git`
- [Important] Before any destructive shell operation (`sed -i`, `rm`, bulk file rewrites), snapshot to a `.backup/` dir or preview the change on a single file first. Never run `sed` across multiple files without first verifying the pattern produces the correct output on one file.

## Documentation Lookups

@rules/context7.md

## Debugging

@rules/debugging.md

## Content Generation

- When editing HTML/PDF presentations, never regenerate from scratch — always preserve existing slides/content and only modify what was requested. Confirm orientation (landscape vs portrait) before generating.

## Output Formats

- [Important] Before generating output files (JSON, text, markdown) for consumption by scripts or skills, read the consuming script/skill first to understand the expected file format. Don't assume structure.

## Node Version Management

- I do not use `nvm`. All repos use `fnm` instead: https://github.com/Schniz/fnm
- Run `fnm use` to switch to project-specific Node version

## Best Practices

- [Important] Parallelize work where applicable or reasonable

## Agent Model Routing

- [Important] When invoking built-in agents (`Explore`, `Plan`, `general-purpose`, or `Agent` with no `subagent_type`), pass `model: "sonnet"` unless the task genuinely needs Opus-level reasoning (novel architecture, complex multi-file debugging, deep synthesis). Routine exploration, file search, and research should run on Sonnet.
- Named subagents define their own model in frontmatter — do not override unless asked.

## Execution Mode Default

- [Important] Whenever a workflow, skill, or plan-execution flow (e.g. deep-implement,
  superpowers executing-plans / subagent-driven-development) would offer a choice between
  subagent-driven and inline execution, always choose subagent-driven WITHOUT asking.
  Do not surface the execution-mode menu. Only fall back to inline if subagent dispatch
  is genuinely impossible, and say so explicitly when you do.
- This does NOT override the PR-review agent-selection step (see "PR Reviews"), which must
  always let me confirm the agents.

## Orchestrated Commands

When writing or modifying any multi-agent orchestrated command in `~/.claude/commands/`, consult `@rules/orchestrated-commands.md` first. Covers the 6-step flow, artifact conventions, approval gate rules, parallel dispatch, and shared anti-patterns.

## Context Efficiency

- Do not re-read files already read in the current session — reference the earlier read instead
- Use `offset`/`limit` when reading large files rather than loading the whole thing

## Python

@rules/python.md

## File Conventions

- Summaries and weekly logs go in `_summaries/` (leading underscore), not `summaries/`.

## Architecture Decisions

- [Important] Do not introduce cross-project dependencies (e.g., making one tool depend on another tool's internals) without explicit approval. Propose and confirm the coupling first — these decisions are irreversible without a refactor.

## Check Mode Before Mutating

Before ANY externally-visible mutation (`gh pr review`, `gh api POST/PATCH`, Slack post, wiki write, issue tracker create/transition, `git push`, deploy, PR merge) — and before any file write/edit while in plan mode — STOP and verify:

1. What mode am I in right now? (plan / auto / normal)
2. Did the user explicitly approve THIS action in THIS turn?
3. Have I shown the exact dry-run / payload / target?

`ExitPlanMode` approval ≠ authorization to post. Auto mode ≠ blanket mutation rights. Authorization stands for the scope specified, never beyond. When in doubt, ask.

@rules/check-mode-before-mutating.md

## AI Memory Tools

@rules/memory-tools.md

## LLM Wiki Pattern

@rules/llm-wiki.md

@RTK.md

## gstack

@rules/gstack.md

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.

**Scoping a new feature:** before proposing an implementation for a new feature, run `/codegraph-feature-scope "<feature description>"`. It fans out across all indexed `~/projects` repos to surface existing terminology, reusable components (ScanScope-style fits), and the cleanest integration point — and flags convention conflicts (naming drift, duplicate implementations, structural/pattern mismatches, dependency-version conflicts) across projects. Use its findings to ground the plan in what already exists before writing any new code. All `~/projects` repos re-index automatically on merge to their default branch via a `post-merge` git hook.
<!-- CODEGRAPH_END -->
