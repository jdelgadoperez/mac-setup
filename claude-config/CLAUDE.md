# Global Claude Code Configuration

This file provides guidance to all Claude Code instances across all projects.

## [CRITICAL] Check Mode Before Mutating

Before ANY externally-visible mutation (`gh pr review`, `gh api POST/PATCH`, Slack post, wiki write, issue tracker create/transition, `git push`, deploy, PR merge) — and before any file write/edit while in plan mode — STOP and verify:

1. What mode am I in right now? (plan / auto / normal)
2. Did the user explicitly approve THIS action in THIS turn?
3. Have I shown the exact dry-run / payload / target?

`ExitPlanMode` approval ≠ authorization to post. Auto mode ≠ blanket mutation rights. Authorization stands for the scope specified, never beyond. When in doubt, ask.

Full rule: `~/.claude/rules/check-mode-before-mutating.md`

## Tool Routing

One canonical path per operation. No fallbacks, no alternatives.

- Use structured MCP tools or CLI helpers for writes (branch creation, PR descriptions, ticket creation, deploys)
- Use direct CLI (`gh`, issue tracker CLI) for reads and simple writes
- Route domain-specific operations through specialized agents (Snowflake, GitHub Actions, session history, etc.)

## Git Safety Rules

- **NEVER push to default protected branches from local machine** (e.g., `main`, `release`)
- Always create feature branches for work
- If no ticket exists, use `feat/` prefix instead of making up a ticket number

## PR Preferences

- All PR descriptions should ease the review experience — focus on clarity, context, and making it easy for reviewers to understand what changed and why

## Bash Command Preferences

- Keep bash commands simple — run one at a time when possible
- Avoid chaining commands with `&&` — it causes hangs and failures
- Use normal `git` commands instead of absolute paths like `/usr/bin/git`

## Documentation Lookups

- [Important] **Always use Context7 (`ctx7`) for library/framework documentation** — even for well-known libraries. Training data may be outdated. Prefer ctx7 over web search for docs.
- See `~/.claude/rules/context7.md` for the full ctx7 workflow (resolve library → fetch docs → answer).

## PR Reviews

- [Important] When reviewing PRs, always use the multi-agent workflow with the agent selection step. Never skip agent selection — let the user confirm which agents to use before proceeding.
- Post all review findings as **inline comments on specific lines** — never as a single summary block
- **Distinguish initial vs re-review**: before dispatching agents, check prior review threads; if a prior review from you exists, scope agents to the diff-of-diff only (not the full PR)
- **After pushing fixes** in response to review feedback, always re-request reviews from the original reviewers
- Check **all four comment surfaces** before reviewing or declaring feedback addressed: inline comments, review submissions, conversation-level comments, and GraphQL `reviewThreads` (surfaces RESOLVED + OUTDATED threads)
- **Tone**: fewer nitpicks on staff/principal engineer PRs; frame structural suggestions as questions; never post unverified factual claims

## Debugging

- [Important] When debugging deployment/runtime issues, enumerate the top 3-5 most likely root causes ranked by probability BEFORE making any changes. Verify the simplest causes first (missing imports, typos, wrong env vars) before assuming library-level incompatibilities or making widespread config changes.

## Content Generation

- When editing HTML/PDF presentations, never regenerate from scratch — always preserve existing slides/content and only modify what was requested. Confirm orientation (landscape vs portrait) before generating.

## Output Formats

- [Important] Before generating output files (JSON, text, markdown) for consumption by scripts or skills, read the consuming script/skill first to understand the expected file format. Don't assume structure.

## Best Practices

- [Important] Parallelize work where applicable or reasonable
- Check session history before claiming "this is the first time we've done X"

## Agent Model Routing

- [Important] When invoking built-in agents (`Explore`, `Plan`, `general-purpose`, or `Agent` with no `subagent_type`), pass `model: "sonnet"` unless the task genuinely needs Opus-level reasoning (novel architecture, complex multi-file debugging, deep synthesis). Routine exploration, file search, and research should run on Sonnet.
- Named subagents define their own model in frontmatter — do not override unless asked.

## Orchestrated Commands

When writing or modifying any multi-agent orchestrated command in `~/.claude/commands/`, consult `~/.claude/rules/orchestrated-commands.md` first. Covers the 6-step flow, artifact conventions, approval gate rules, parallel dispatch, and shared anti-patterns.

## Git & Repo Hygiene

- Before any `git push`, verify the git root matches the intended repo for the branch being pushed
- Never stash an in-progress merge — complete it (`git commit`) or abort it (`git merge --abort`)
- Persist shell/config fixes to your machine-setup repo, not to local files — local writes don't survive across machines or sessions
