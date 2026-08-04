# /config-audit — Claude Code configuration audit

A Claude Code skill (invoked as a slash command) that audits your Claude
configuration and tooling, then generates a self-contained HTML report —
similar in spirit to `/insights`.

## What it audits

| Scope | Sources |
|---|---|
| User | `~/.claude/CLAUDE.md`, `settings.json`, `settings.local.json`, `keybindings.json`, `commands/`, `skills/`, `agents/`, `plugins/`, MCP servers in `~/.claude.json` |
| Project | `CLAUDE.md`, `CLAUDE.local.md`, `.claude/settings*.json`, `.claude/commands|skills|agents`, `.mcp.json`, `.gitignore` coverage |

Across four dimensions:

- **Overlaps & conflicts** — duplicate/shadowing commands, redundant MCP
  servers, contradictory instructions between scopes, shadowed permission rules
- **Gaps** — missing memory files, no permission allowlist (prompt fatigue),
  missing hooks, tools without descriptions, ungitignored local settings
- **Hygiene & security** — secrets in tracked config, stale references,
  deprecated settings keys
- **Efficiency** — context cost of oversized CLAUDE.md files and unused
  MCP servers

## Usage

```
/config-audit                       # audit both scopes, report → ~/projects/_reports
/config-audit ~/Desktop             # custom output directory
/config-audit --project-only        # just this repo's config
/config-audit --no-open             # don't auto-open the report
```

The report lands at `~/projects/_reports/claude-config-audit-<date>.html`
by default and opens in your browser.

## Install

This copy lives in mac-setup's `dotfiles/.claude/` tree, so it's installed
the same way as everything else there — per-file symlinks into `~/.claude/`:

```bash
./install-claude-config.sh
```

The skill is fully self-contained and location-independent; it resolves its
script and template relative to its own directory and audits whichever
project you run it from.

## How it works

1. `scripts/collect.py` (Python 3, stdlib only) deterministically inventories
   both scopes into JSON, **redacting** anything secret-shaped (tokens,
   cookies, keys, high-entropy strings) before it leaves the machine's config
   files.
2. Claude deep-reads the memory files and flagged configs, analyzes along the
   four dimensions, and scores each 0–100.
3. `templates/report.html` is filled in — scorecard, severity-tagged findings
   with concrete fixes, inventory tables, context-cost bars, and a quick-wins
   checklist. The report is fully self-contained (no CDN, renders offline)
   and theme-aware (light/dark).

The audit is **read-only**: it never edits your settings or tooling, only
recommends.

## Known issues

Bugs in this skill itself — collector parsing quirks, false positives, and
their fix sketches — are tracked in [KNOWN-ISSUES.md](KNOWN-ISSUES.md). Add an
entry there whenever a run produces a finding that turns out to be wrong, so
the report's own accuracy stays auditable.

## Related commands

Two companion deep-dives live in `dotfiles/.claude/commands/` (installed by
the same `install-claude-config.sh` run):

- **/audit:permissions** — focused security audit of whether permission rules
  still form a boundary (blanket interpreter grants, deny/ask coverage, scope
  hygiene). `/config-audit` flags the headline problems; this digs in.
- **/audit:spec** — audits how completely a project is specified for safe
  agent delegation, and predicts where an agent would silently fill gaps.

Both are adapted (trimmed and de-vendored) from
[claude-code-ultimate-guide](https://github.com/FlorianBruniaux/claude-code-ultimate-guide)
(CC BY-SA 4.0), as are several of this skill's analysis heuristics.
