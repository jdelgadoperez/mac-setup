---
name: config-audit
description: Audit Claude Code configuration and tooling — inventory CLAUDE.md files, settings, permissions, hooks, commands, skills, agents, plugins, and MCP servers across user and project scope; find overlaps, gaps, and hygiene/efficiency problems; and generate a self-contained HTML report (default output ~/projects/_reports). Use when the user invokes /config-audit or asks to audit, review, or health-check their Claude Code setup.
---

# Claude Config Audit

Generate a user-friendly HTML report (like `/insights`) that audits the user's
Claude Code configuration and available tooling: what exists, what overlaps,
what's missing, and what should be improved.

## Arguments

`/config-audit [output-dir] [--user-only|--project-only] [--no-open]`

- `output-dir` — where to write the report. Default: `~/projects/_reports`
  (create it with `mkdir -p` if missing).
- `--user-only` / `--project-only` — restrict scope. Default: audit both
  user scope (`~/.claude`, `~/.claude.json`) and project scope (the current
  working directory's `CLAUDE.md`, `.claude/`, `.mcp.json`).
- `--no-open` — skip auto-opening the report in a browser.

## Workflow

### 1. Collect (deterministic)

Run the bundled collector from this skill's directory:

```bash
python3 <skill-dir>/scripts/collect.py --out <scratchpad>/config-inventory.json
```

Pass `--project <dir>` if the user is auditing a project other than the cwd.
The collector inventories both scopes and **redacts secrets** (tokens, cookies,
API keys, high-entropy strings) — never bypass it by reading raw settings values
into the report. Read the resulting JSON as the source of truth for *what
exists*.

### 2. Deep-read selectively

The inventory gives names, sizes, and descriptions. Additionally read (with
Read, not shell cat):

- Every `CLAUDE.md` / `CLAUDE.local.md` found — full text, to judge quality,
  staleness, and conflicts between scopes.
- Command/skill/agent frontmatter the collector flagged as missing or empty.
- Hook definitions from the inventory (already parsed from settings).

Do NOT read `.env` files or paste any config value the collector redacted.

### 3. Analyze — four dimensions

Score each dimension 0–100 and collect findings. Every finding needs:
severity (`critical` / `serious` / `warning` / `good`), scope, a one-line
**what**, a short **why it matters**, and a concrete **fix** (the exact file to
edit, command to run, or setting to change).

**Overlaps & conflicts**
- Same-name commands/skills/agents at user and project scope (project shadows user).
- Multiple tools doing the same job (e.g. two scraping commands, a skill and a
  plugin with the same purpose, redundant MCP servers with overlapping capabilities).
- Instructions in project CLAUDE.md that contradict user CLAUDE.md or settings.
- Contradictions *within* a memory file: an "always X" statement alongside a
  "never X" statement about the same topic.
- Permission rules shadowed by broader rules, or allow rules contradicted by deny rules.

**Gaps**
- No CLAUDE.md at a scope that clearly needs one; documented projects missing setup info.
- No permission allowlist for obviously-safe repeated commands (prompt fatigue).
- Deny list doesn't cover secret-bearing paths (`.env*`, `*.pem`, `*.key`,
  `credentials*`) — and an empty `ask` list means no human checkpoint exists
  anywhere.
- Any allow rule granting an interpreter or runner (`bash`, `python`, `node`,
  `npx`, `npm`, `make`, `docker exec`, …) — flag as **critical**: it nullifies
  every deny rule. Point to `/permissions-audit` for the full boundary analysis.
- No hooks where the user's workflow implies them (formatting, tests, secret scanning).
- Commands/skills/agents without descriptions (won't trigger reliably); commands
  that use `$ARGUMENTS` but declare no `argument-hint`.
- `settings.local.json` or `.mcp.json` not gitignored in a repo.

**Hygiene & security**
- Anything the collector marked `redacted` living in a *committed* file (secrets
  belong in `.env` / `settings.local.json`, never in tracked config).
- Stale references: commands pointing at paths that no longer exist, MCP servers
  whose command isn't installed, expired-cookie patterns; broken `@import` lines
  in CLAUDE.md (an `@path` line whose target doesn't exist).
- Deprecated or unknown settings keys; references to deprecated model names
  (e.g. `claude-2`, `claude-3-haiku`, `claude-instant`, `gpt-3.5`).

**Efficiency (context cost)**
- Oversized CLAUDE.md files (flag > ~1,500 words; they load into every session).
  Also estimate always-on context in tokens (chars ÷ 4 across all memory files
  + resolved imports); flag when the total exceeds ~10K tokens.
- Vague instructions that burn context without changing behavior ("be careful",
  "use your judgment", "as needed", "appropriately") — suggest concrete rewrites.
- MCP servers that are configured but plausibly unused (each adds tool-schema
  overhead to every session).
- Large numbers of always-on skills/plugins with overlapping triggers.

Be specific and honest: if the setup is healthy, say so — don't invent findings
to fill sections. Cap the report at the findings that matter; fold trivia into
one "minor notes" list.

### 4. Generate the report

Use `<skill-dir>/templates/report.html` as the base — copy it, then replace the
`<!-- @SECTION:... -->` placeholder blocks with real content, keeping its CSS,
classes, and light/dark theming intact. The template is self-contained (no CDN,
no external requests) and its palette is pre-validated; don't introduce new
colors. Status severity always renders as **icon + label + color**, never color
alone.

Fill in:
- **Scorecard** — overall grade (A–F from the four dimension scores) plus stat
  tiles: counts of commands, skills, agents, MCP servers, hooks, and findings
  by severity.
- **Findings** — one card per finding, grouped by dimension, ordered most
  severe first, each with its concrete fix.
- **Inventory** — tables of commands/skills/agents/MCP servers with scope and
  description; the context-cost bars for memory files.
- **Quick wins** — a short checklist of the highest-value fixes (aim for ≤ 7).

Write it to `<output-dir>/claude-config-audit-YYYY-MM-DD-HHMM.html`.

### 5. Deliver

- Auto-open the report unless `--no-open`: `open <file>` (macOS) or
  `xdg-open <file>` (Linux), best-effort — a failure to open is not a failure
  of the audit.
- In chat, give a 3–6 line summary: the grade, the top findings, and the
  report path. Don't duplicate the whole report in chat.

## Guardrails

- Never write secrets, tokens, cookies, or their prefixes/suffixes into the
  report or chat — the collector's redaction is the boundary.
- The report file must be fully self-contained and render offline.
- Read-only with respect to the user's config: this command audits and
  recommends; it never edits settings, memory files, or tooling itself.

## Credits

Several analysis heuristics (context token budgeting, broken-import detection,
contradiction/vagueness checks, deny-coverage and interpreter-grant checks)
are adapted from the audit prompts in
[claude-code-ultimate-guide](https://github.com/FlorianBruniaux/claude-code-ultimate-guide)
by Florian Bruniaux (CC BY-SA 4.0).
