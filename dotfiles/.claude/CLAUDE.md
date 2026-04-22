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

## Git Safety Rules

- For collaborative or work repos, always create feature branches — never push directly to main
- For solo personal projects, push directly to `main` — no PR or feature branch needed
- If no ticket exists, use `feat/` prefix instead of making up a ticket number
- Use `git -C <path>` instead of `cd`-ing into directories to avoid shell hook issues
- If `gh pr create` fails for any reason, immediately fall back to providing the manual GitHub URL
  for PR creation — do not retry. Fail fast and let the user complete it manually.

## Git Worktree Workflow

When working on multiple things in a single repo, use git worktrees instead of switching branches.

Preferred worktree location: `~/.config/superpowers/worktrees/<project>/<branch>/`

```bash
# List existing worktrees
git worktree list

# Create worktree for NEW branch
git worktree add -b <branch-name> ~/.config/superpowers/worktrees/<project>/<branch-name>

# Create worktree for EXISTING branch
git worktree add ~/.config/superpowers/worktrees/<project>/<branch-name> <branch-name>

# Remove worktree when done
git worktree remove ~/.config/superpowers/worktrees/<project>/<branch-name>

# Clean up stale references
git worktree prune
```

## Shell & Environment Cleanup

When removing or replacing shell tools, CLIs, or aliases, always verify and clean up:
- Symlinks in `~/.oh-my-zsh/custom/`, `~/bin/`, `~/.local/bin/`
- Shell aliases in `.zshrc`, `.bashrc`, or oh-my-zsh custom plugin files
- Wrapper scripts or cached references pointing to the old tool name

Do not consider a removal or migration task complete until these are verified clean.

## Merging & PRs

- For solo personal projects, push directly to `main` — no PR needed
- For collaborative repos, all PR descriptions should ease the review experience — focus on clarity,
  context, and making it easy for reviewers to understand what changed and why

## Bash Command Preferences

- Keep bash commands simple - run one at a time when possible
- Avoid chaining commands with `&&` - it causes hangs and failures
- Use normal `git` commands instead of absolute paths like `/usr/bin/git`
- [Important] Before any destructive shell operation (`sed -i`, `rm`, bulk file rewrites), snapshot to a `.backup/` dir or preview the change on a single file first. Never run `sed` across multiple files without first verifying the pattern produces the correct output on one file.

## Documentation Lookups

- [Important] **Always use Context7 (`ctx7`) for library/framework documentation** — even for well-known libraries. Training data may be outdated. Prefer ctx7 over web search for docs.
- See `~/.claude/rules/context7.md` for the full ctx7 workflow (resolve library → fetch docs → answer).

## Debugging

- [Important] When debugging deployment/runtime issues, enumerate the top 3-5 most likely root causes ranked by probability BEFORE making any changes. Verify the simplest causes first (missing imports, typos, wrong env vars) before assuming library-level incompatibilities or making widespread config changes.
- [Important] Fix the root cause in source code — never apply workarounds to symptoms (e.g., manually editing a config file that a broken installer should have written). If a tool or installer failed, fix the tool.

## Content Generation

- When editing HTML/PDF presentations, never regenerate from scratch — always preserve existing slides/content and only modify what was requested. Confirm orientation (landscape vs portrait) before generating.

## Output Formats

- [Important] Before generating output files (JSON, text, markdown) for consumption by scripts or skills, read the consuming script/skill first to understand the expected file format. Don't assume structure.

## Node Version Management

- I do not use `nvm`. All repos use `fnm` instead: https://github.com/Schniz/fnm
- Run `fnm use` to switch to project-specific Node version

## Best Practices

- [Important] Parallelize work where applicable or reasonable

## Context Efficiency

- Do not re-read files already read in the current session — reference the earlier read instead
- Use `offset`/`limit` when reading large files rather than loading the whole thing

## Python

- Always use `uv` instead of `pip` for package management
- When running `ruff check --fix`, always follow up immediately with `ruff check` (no `--fix`) to
  verify no imports were broken by auto-fixes. Do not commit until the second check is clean.

## File Conventions

- Summaries and weekly logs go in `_summaries/` (leading underscore), not `summaries/`.

## Architecture Decisions

- [Important] Do not introduce cross-project dependencies (e.g., making one tool depend on another tool's internals) without explicit approval. Propose and confirm the coupling first — these decisions are irreversible without a refactor.

## AI Memory Tools

Two complementary memory systems are available:

- **Memory Bank** (`memory-bank search`) — retrospective search over the full Claude Code conversation history. Use when you need to find something from a past session (prior decisions, earlier bug fixes, past approaches). Use the `memory-search` skill for semantic search or `memory-recall` for full session context retrieval.
- **ICM** (MCP tools) — structured forward-looking memory with knowledge graphs and temporal decay. ICM manages its own recall/store lifecycle via its MCP instructions. Prefer ICM for storing decisions, preferences, and patterns going forward.

**Division of labor:** "What did we discuss about X before?" → Memory Bank. "What do I know about X right now?" → ICM.

### Memory Bank — when to search explicitly

Auto-recall (UserPromptSubmit hook) handles passive context injection before each prompt. Reach for the `memory-search` or `memory-recall` skill explicitly when:

- The user references past work ("remember when we...", "we fixed this before", "what was that approach")
- Starting a significant task in a project with deep history — search for prior decisions and context before proposing anything
- Debugging a recurring issue — search for prior resolution attempts before diagnosing from scratch
- Auto-injected context seems incomplete or missing for the current task

@RTK.md
