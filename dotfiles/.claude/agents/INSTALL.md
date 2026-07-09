# Claude Code Agents — Install Note

The agents in `~/.claude/agents/` are **not tracked in this repo**. They come from an
external pack and are installed separately, so this note records where they come from and
how to (re)install them on a new machine.

## Source

[VoltAgent / awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
— a curated collection of specialized Claude Code subagents (MIT licensed).

Identifying signature (so you can confirm a given agent file is from this pack):

- Frontmatter shape: `name`, `description`, `tools`, `model: sonnet|opus`
- Body contains a `## Communication Protocol` section with a "context-manager" context-gathering step
- Upstream category taxonomy: `01-core-development`, `02-language-specialists`,
  `03-infrastructure`, `04-quality-security`, `05-data-ai`, `06-developer-experience`,
  `07-specialized-domains`, `08-business-product`, `09-meta-orchestration`, `10-research-analysis`

## Install

Any of the following (per upstream README):

```bash
# Option A — plugin marketplace (preferred; keeps them updatable)
claude plugin install voltagent-lang

# Option B — standalone installer (no clone)
#   see upstream README for the current curl-to-installer one-liner

# Option C — manual
git clone https://github.com/VoltAgent/awesome-claude-code-subagents.git
# copy the agent .md files you want from categories/**/ into ~/.claude/agents/
```

Verify with `/manage:status` (lists agents/skills/commands and their enabled state).

## Local deviations from stock (worth reproducing by hand)

These are *choices*, not content, and won't survive a fresh pack install:

- `electron-pro.md` is **disabled** (`.disabled` suffix) — re-disable after reinstalling,
  or use `/manage:disable electron-pro`.

## Why not vendor the files here?

The pack is ~180 KB of generic, upstream-maintained content with no personal customization
(grep for `mac-setup` / project names / `dorothy` / `fnm` returns nothing). Tracking it would
re-vendor content that drifts from upstream. This repo tracks *how to install*, matching the
rest of the setup (install scripts, not copied files). If you ever customize an agent
meaningfully, track that individual file — not the whole pack.
