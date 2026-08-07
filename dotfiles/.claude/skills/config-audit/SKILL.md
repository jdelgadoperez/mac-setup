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

Run the bundled collector from this skill's directory, always passing
`--project` explicitly:

```bash
python3 <skill-dir>/scripts/collect.py --project <dir> --out <scratchpad>/config-inventory.json
```

**Always pass `--project <dir>` explicitly, on every invocation, including
re-runs and verification runs.** Never rely on cwd — a stray `cd` earlier in
the shell session silently changes what gets audited.

The collector prints the resolved project root and user root to stderr, and
emits a warning when the root's basename looks wrong (`.claude`, `skills`,
`commands`, `agents`, `hooks`, `rules`) or when the directory has no
CLAUDE.md / `.claude/` / `.mcp.json`. **Check the resolved root before
analysing anything.** Surface any such warning as a **critical** finding — an
audit of the wrong directory is worse than no audit, because it reports a
clean bill of health for a scope that was never examined.

When re-running to verify a fix, **assert both runs resolved the same
project root before diffing counts.** A count that drops to zero is more
likely a wrong root than a successful cleanup — treat implausible zeros
(`allow=0, skills=0`, etc.) as suspected misconfiguration, not success, until
the resolved root is confirmed identical.

If the project scope comes back with `mirrors_user_scope: true`, it resolved to
`$HOME` and is the *same files* as the user scope. Audit it as a single scope:
say so once in the report meta, drop the duplicate scope from the scorecard and
inventory, and never report the same file twice as though two scopes disagreed.
Suggest re-running from inside a real project for a true two-scope audit. (This
is distinct from the wrong-root warning above: `mirrors_user_scope` means the
root resolved correctly to `$HOME`, not that it resolved to the wrong directory.)
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

**Cause/effect severity rule.** When one finding is the **structural enabler**
of another, its severity is **at least** that of the finding it enables — a
cause is never rated below its effect. The two findings must cross-reference
each other explicitly: the enabler names what it enables, the effect names the
enabler. Example: a permission file at a container directory (e.g. `~/projects`)
governing many unrelated repos is the enabler; an over-broad interpreter grant
inside it inherits that blast radius across every repo, so the container-scope
finding inherits the grant's severity — it cannot be rated `warning` while the
grant it enables is rated `critical`.

**Overlaps & conflicts**
- Same-name commands/skills/agents at user and project scope (project shadows user).
- **A name collision (skill vs. command vs. agent) is reportable as an overlap
  or trigger conflict only when BOTH artifacts actually load.** Before writing
  such a finding, confirm `loads: true` for each skill (and on-disk existence
  for commands/agents) — a directory whose frontmatter lives in a file other
  than `SKILL.md` never loads and cannot conflict with anything. If one side
  doesn't load, this is a **dead-weight finding** (see Hygiene, below), not a
  conflict: different severity (`warning`, not `serious`), different fix
  (delete or repair the non-loading artifact, not rename/merge the colliding
  one), different wording. Naming the wrong mechanism can still land on the
  right fix by luck — that is not good enough; the finding must name the
  actual cause.
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
  every deny rule. Point to `/audit:permissions` for the full boundary analysis.
- **Deny rules that name a mechanism when they meant to protect an asset.** A
  deny only holds if the capability it names cannot be reached another way *on
  this machine*. The collector emits a `permission_reachability` block for this;
  treat it as evidence, not as prose to paste. Two finding shapes:
  - `cross_surface` — **informational only. Never report it as a finding.**
    The collector emits `status: "informational"` and `reportable: false` on
    this block; honour both. It lists allowed, installed, file-reading Bash
    binaries that coexist with a path deny — useful context, *not* evidence of
    a gap.

    **Why it is not evidence.** Empirical testing on Claude Code 2.1.224 (with
    project `deny: ["Read(**/.env)"]`) shows the deny extension is **not** a
    fixed set of recognised reader binaries. Claude Code parses the command,
    resolves which paths each argument actually operates on, and applies the
    `Read`/`Edit` deny to any Bash command touching that path, whatever the
    binary. Verified denied: `cat`, `strings`, `od`, `cut`, `rg`, `jq`, `sort`,
    `uniq`, `perl -ne`, and also `ls -la .env` and `file .env` — neither of
    which reads file *contents*. Meanwhile `echo skipping .env` **ran**, so it
    is not naive string matching either. Controls (`strings plain.txt`,
    `jq -r .a plain.json`) ran clean, confirming the path deny is what fires.

    **Therefore: never infer "binary X is not on a recognised-reader list,
    so it bypasses the deny."** That inference is invalid and previously
    produced false positives on this very machine (`jq`, `rg`, `sort`, `uniq`
    were reported as gaps, then verified denied).

    The genuinely uncovered class is **arbitrary subprocesses that open files
    themselves** — `python3 -c "print(open('.env').read())"` only *prompts*,
    it is not denied. That, and only that, is the residue worth writing about.

    **Do not recommend more `Bash(...)` deny patterns as the fix.** Bash rule
    matching is command-string-based, so `Bash(cat *.env*)` is defeated by
    command substitution (`cat $(echo …)`), variable indirection, extra spaces,
    and recursive traversal (`grep -r` never puts the path in the command
    string). The official docs call such argument-constraining patterns fragile.
    Recommending them ships security theater. The real fixes, in order:
    1. `sandbox.credentials.files` with `"mode": "deny"` — OS-enforced (Seatbelt
       on macOS), no pattern matching to evade. Requires Claude Code ≥ 2.1.187.
       Flag the tradeoff: enabling `sandbox` turns on filesystem *and* network
       isolation for Bash and its children, which can break tooling that writes
       outside the working directory.
    2. A `PreToolUse` hook on `Bash` — wider net than rules, but still
       command-string-based and evadable by the same tricks. Position it as the
       fallback when sandboxing is too disruptive, not as a second layer.
    3. Say plainly that the residue is best-effort by design, if neither fits.
  - `flag_scoped` — a binary denied only for certain flags (`gpg -d`) while the
    same installed binary stays reachable via others (`gpg --output`). Usually
    **warning**; raise to serious when the binary decrypts or exfiltrates.
    Note that path-scoped denies (`Bash(cat *.env)`) are the *correct* shape and
    are deliberately not reported.

    **Before reporting a `flag_scoped` finding as a gap, cross-reference the
    same binary against broader `ask` and `deny` rules at ANY scope.** A narrow
    flag-scoped deny (`Bash(curl *attacker*)`) can be entirely redundant when a
    broader rule already covers the binary — e.g. `Bash(curl *)` in `ask`, or
    `Bash(rm -rf *)` in `ask` making a narrower `rm` deny moot. An `ask` rule is
    a **strictly stronger** control than a narrow flag-scoped deny: it forces a
    human checkpoint on *every* invocation of that binary, not just one
    argument shape. The collector now marks this per entry: `redundant: true`
    with `covered_by` / `covered_by_list` naming the broader rule, or
    `redundant: false` for a genuine gap. `redundant: true` must **never** be
    presented as a coverage gap — report it, if at all, as "redundant rule,
    safe to drop" at **minor/informational** severity. Only `redundant: false`
    entries are genuine gaps and keep the warning/serious severity above.

  Read `permission_reachability.findings` before writing anything about the
  permission model, and respect each finding's `reportable` flag — only
  `flag_scoped` is reportable today. It is machine-specific by design: a work
  laptop with `aws` and `vault` installed yields findings a personal machine
  cannot. Never carry a finding across machines from a previous run, and never
  extend the list by reasoning about tools that "probably" exist — if a binary
  is not in the collector's output, it was not on this host's PATH. Any claim
  reaching beyond the collector must be verified with `command -v` **and**, for
  anything touching deny coverage, by an actual test against this Claude Code
  version — the reader-binary model looked right on paper for months and was
  wrong. Prefer `/audit:permissions` for the full boundary analysis; it carries
  the verified matcher, sandbox, and mode semantics.
- No hooks where the user's workflow implies them (formatting, tests, secret scanning).
- Commands/skills/agents without descriptions (won't trigger reliably); commands
  that use `$ARGUMENTS` but declare no `argument-hint`.
- `settings.local.json` or `.mcp.json` not gitignored in a repo.

**Hygiene & security**
- **Skills that do not load.** The collector emits, per skill: `loads` (true
  only when `SKILL.md` exists at the skill root), `stray_frontmatter_files`
  (`*.md` files carrying skill frontmatter but not named `SKILL.md`), and
  `self_duplicate_files` (groups of byte-identical `*.md` files inside one
  skill dir). A directory under `skills/` with no root `SKILL.md` never loads —
  it's absent from the available-skills list entirely — and is dead weight.
  Severity **warning**. Fix: rename the stray frontmatter file to `SKILL.md` if
  the skill is wanted, or delete the directory if not. Byte-identical
  self-duplication (e.g. `X/X.md` and `X/X/X.md` identical) is a strong signal
  of a bad install/link pass — call it out explicitly.
- **Check `parse_error` first, before any other analysis.** Any settings file,
  `~/.claude.json`, or `.mcp.json` carrying a `parse_error` is a **critical**
  finding: malformed JSON silently disables *every* setting in that file —
  permissions, hooks, model, plugins. Name the file and quote the parser
  message in the fix. Two traps: (a) on a parse error the collector
  early-returns, so `permissions` and `hooks` are *absent* rather than empty —
  never report "no permission rules configured" for a file that failed to
  parse, the rules exist and are simply inert; (b) a scope in this state must
  not be graded as healthy — cap the overall grade at **F** while any config
  file fails to parse, since nothing else you measure about that scope is
  actually in effect.
- Anything the collector marked `redacted` living in a *committed* file (secrets
  belong in `.env` / `settings.local.json`, never in tracked config).
- Stale references: commands pointing at paths that no longer exist, MCP servers
  whose command isn't installed, expired-cookie patterns; broken `@import` lines
  in CLAUDE.md (an `@path` line whose target doesn't exist).
- Broken symlinks (`broken_symlink: true`). Before recommending deletion, check
  whether the content is recoverable — a dangling link usually means the target
  moved, not that the content is gone. Run `git log --all --oneline --follow --
  <target>` **and** `git log --all --diff-filter=D -- <target>` in the repo the
  link points into. If either returns commits, the fix is `git restore` or
  `git checkout <sha>^ -- <path>`, and the finding must name that commit.
  Never assert a file is untracked or unrecoverable from a single `git log`
  query — that claim drives a destructive recommendation, so it needs the
  stronger check. If history really is empty, say "no commit found for this
  path", not "it was never tracked".
- *Mixed* symlink styles under `skills/` — some entries linked at the directory
  level (`skills/X` → source `skills/X`) and others per-file (`skills/X/SKILL.md`
  → source). Flag as **serious** even when nothing is broken yet: a per-file
  linking pass run against an already-dir-symlinked skill resolves back through
  the link and links the source onto itself, corrupting the *source repo*
  rather than the install. This is a precondition for silent, repo-side data
  loss, not a cosmetic inconsistency.
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
  by severity. If any config file failed to parse (see `parse_error` above),
  the grade is **F** regardless of the dimension scores, and the scorecard says
  why — a scope whose settings don't load has no working configuration to grade.
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
