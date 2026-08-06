# config-audit — Design Notes

Why the analysis heuristics in `SKILL.md` and the collector in
`scripts/collect.py` are shaped the way they are.

Most rules here exist because an earlier run of this audit produced a *wrong
report* — a false finding, a missed critical failure, or a confident claim that
turned out to be false. The rule is the fix; this file is the reason. Read the
relevant section before changing a heuristic, or you will re-derive the bug.

Scope: the audit tool itself. Nothing here is a finding about any audited
configuration.

---

## Parse errors gate everything

**Rule:** `SKILL.md` lines 130–140 — check `parse_error` before any other
analysis; emit `critical`; cap the overall grade at **F**.

A `settings.json` containing `not json{{{` was collected correctly:

```json
"settings": { "exists": true, "keys": null,
              "parse_error": "Expecting value: line 1 column 1 (char 0)" }
```

...and then never mentioned in the report, because no analysis dimension
referenced `parse_error`. The scope was graded as present-and-fine.

Malformed JSON silently disables *every* setting in the file — permissions,
hooks, model, plugins. It is strictly worse than any other finding the audit
reports, and it is precisely the state someone runs an audit to discover. A
report that grades it healthy is actively misleading, which is why the grade
cap is unconditional rather than a dimension score adjustment.

**Trap.** `summarize_settings()` early-returns on a parse error, so
`permissions` and `hooks` are **absent** from the JSON rather than empty. Do not
read that as "no permission rules configured" — the rules exist and are inert.
Confirmed against real collector output.

---

## Never assert a negative from a single git query

**Rule:** `SKILL.md` lines 146–155 — before recommending deletion of a broken
symlink, run both `git log --all --oneline --follow -- <target>` and
`git log --all --diff-filter=D -- <target>`. Empty history reports as "no commit
found for this path", never "it was never tracked".

A report stated that `agents/research-analyst.md` was "**not** tracked in git —
unlike the skills breakage, there is nothing to restore," and recommended
recreate-or-delete. False. The file was added in `3e2d163`, deleted in
`40e872e`, and recoverable the whole time via
`git show 40e872e^:dotfiles/.claude/agents/research-analyst.md`.

The supporting check was `git log --diff-filter=A -- '*research-analyst*'`,
whose output was misread as empty. One `--diff-filter=A` query on a glob cannot
establish that a path was never tracked, and nothing verified the negative
before it was written down as fact.

The severity comes from the direction of the error: the claim pointed toward
deleting a file presented as unrecoverable. A wrong "it's fine" is cheap; a
wrong "it's gone" destroys something.

**Generalization worth making.** This rule hardens exactly one instance —
broken symlinks — of a broader failure: asserting an unverified negative as
fact. The same shape is available in every other dimension ("no hook covers
this", "this permission is unreachable", "this MCP server is unused"). Only the
symlink case has a guardrail. Treat any negative claim in a report as needing
the same standard of evidence.

---

## Mixed symlink styles are a data-loss precondition

**Rule:** `SKILL.md` lines 156–162 — flag mixed dir-level and per-file symlink
styles under `skills/` as **serious**, even when nothing is broken yet.

An earlier report recommended "fix the installer step that created
self-referential symlinks," pointing at `install-claude.sh`. That installer
symlinks whole skill *directories* and already guards with `[ ! -e "$source" ]`.
It cannot produce a file-level loop like `ship/SKILL.md -> ship/SKILL.md`. The
fix was aimed at the wrong file and would have fixed nothing.

The actual culprit is `install-claude-config.sh`, a *second* installer that
walks `dotfiles/.claude/` and links every file individually. Run after
`install-claude.sh` has dir-symlinked the skills, its target path resolves
*through* that link back to the source, and its conflict branch `rm -rf`s the
source and links it to itself. The corruption lands in the dotfiles repo, not
in `~/.claude`.

Reproduced end to end in a sandbox: `Too many levels of symbolic links`, source
destroyed. It explains the blast pattern exactly — all 14 skills in
`install-claude.sh`'s `CLAUDE_SKILLS` plus 6 other dir-symlinked skills were
hit, while `config-audit` (a real directory with per-file links inside) was
untouched.

The original guard tested the *target*: `[ -e "$target" ]` is false for an
already-corrupted dangling self-link, so a rerun bypassed it. It now compares
resolved *parent* directories, which holds in both clean and corrupted states.

Two linking styles still coexist, which is why the audit flags the mix rather
than any specific breakage:

| Style | Example | Shape |
|-------|---------|-------|
| Installer (dir-level) | `ship`, `pr`, `writing-voice` | `~/.claude/skills/X` → dotfiles `skills/X` |
| Per-file | `config-audit` | real dir; `SKILL.md` → dotfiles `skills/X/SKILL.md` |

Ruled out: no `ln -s` exists anywhere in `custom-zsh/` or the live oh-my-zsh
custom files. This was never a zsh helper.

---

## Permission reachability

**Rule:** `SKILL.md` lines 83–123 — the `permission_reachability` block, its two
finding shapes, and the ordered fix list.

A deny rule only holds if the capability it names cannot be reached another way
*on the machine being audited*. Naming a mechanism is not protecting an asset.
The collector reports two gap shapes:

- **`cross_surface`** — secret paths denied on one tool surface while allowed
  binaries on another read the same bytes. `Read(**/.env)` blocks the Read tool
  while an allowed `Bash(cat:*)` reads the file unprompted.
- **`flag_scoped`** — a binary denied only for certain flags (`gpg -d`) while
  the same installed binary stays reachable via others (`gpg --output`).

Path-scoped denies (`Bash(cat *.env)`) are the *correct* shape and are
deliberately not reported, so the check never punishes the fix it recommends.

### Why `reachable_via` and `already_covered` are separate

The first version treated every allowed Bash reader as a way around a
`Read(**/.env)` deny. Wrong for four of them: Claude Code extends `Read`/`Edit`
denies to file commands it recognizes in Bash — `cat`, `head`, `tail`, `sed`
are named explicitly in the permissions docs — so those are already protected.

Splitting the lists turned a 13-reader finding into 9 real gaps plus 4
suppressed false positives on the reference machine. A config whose only allowed
readers are the covered four now correctly produces no finding at all.

**Read `reachable_via` only.** Reporting `already_covered` entries as gaps is a
false positive by construction.

### Why the fix list rejects more Bash denies

The original guidance was to add `Bash(cat *.env*)`-style denies. That is
security theater. Bash rule matching is command-string-based, so it is defeated
by command substitution (`cat $(echo …)`), variable indirection, extra spaces,
and recursive traversal (`grep -r` never puts the path in the command string).
The official docs call argument-constraining patterns fragile.

The ordered alternatives, and their costs:

1. `sandbox.credentials.files` with `"mode": "deny"` — OS-enforced (Seatbelt on
   macOS), no pattern matching to evade. Requires Claude Code ≥ 2.1.187. State
   the tradeoff: enabling `sandbox` turns on filesystem *and* network isolation
   for Bash and its children, which can break tooling that writes outside the
   working directory.
2. A `PreToolUse` hook on `Bash` — wider net than rules, but still
   command-string-based and evadable by the same tricks. It is the fallback when
   sandboxing is too disruptive, **not** a second layer.
3. Say plainly that the residue is best-effort by design.

### Machine-specificity is intentional

Only binaries resolvable on the host's `PATH` are reported, so the same skill
yields correct and *different* findings on a personal versus a work machine.
Never carry a finding across machines from a previous run.

Probing is `shutil.which` PATH resolution only. `collect.py` still executes
nothing — the property that matters for a script auditing security config.

### Sibling-binary detection: built, then removed

Flagging `scp`/`sftp` because `ssh` is denied was implemented and deliberately
reverted. Every execution-free signal available either floods the output with
coincidences (`su` → `sum`, `superclaude`) or reports the wrong family members
(`ssh-keygen`, not `scp`) while missing the real ones.

The only approach that works is a hand-written equivalence table — exactly the
thing that breaks across machines. Equivalent-capability reasoning is therefore
left to the model, gated on `command -v` verification before any such claim
enters a report. Do not re-attempt this without a new signal.

---

## Scope resolution

**Rule:** `SKILL.md` lines 35–39 — when `mirrors_user_scope` is true, audit as a
single scope.

Run with no `--project` from `$HOME`, "project scope" resolved to `~/CLAUDE.md`
and `~/.claude/` — the same files as user scope. The report then showed two
scopes that were largely identical, with `is_git_repo: false` for a "project",
and risked reporting the same file twice as though two scopes disagreed.

`scan_project_scope()` emits `mirrors_user_scope`, keyed on the resolved root
being `$HOME` rather than on "not a git repo" — a legitimate non-git project
directory is still a distinct scope worth auditing separately.

---

## Collector correctness

### Dangling symlinks must never reach `.stat()`

`rglob("*.md")` yields dangling symlinks, and `stat()` follows the link and
raises. An unguarded call in `inventory_markdown_dir()` killed the first run
outright with `FileNotFoundError` before any output was written.

Broken links are now *recorded as inventory* with `broken_symlink: true` —
which is what surfaced the 19-broken-skills finding — rather than aborting the
run. Guards live in `inventory_markdown_dir()` and on `SKILL.md` in
`inventory_skills()`.

Preserve this invariant when adding any new filesystem walk.

### Frontmatter parsing is block-aware, without a YAML dependency

`parse_frontmatter()` walks the block with an index rather than matching each
line independently. When a key's inline value is empty or an explicit block
indicator (`|`, `>`, `|-`, `>-`, `|+`, `>+`), it consumes the following
more-indented lines and joins them with single spaces.

The line-by-line regex it replaced silently dropped multi-line values, producing
false "missing description" findings for ~9 entries across `skills/` and
`commands/` — valid YAML the regex simply could not read.

### Checked and working as intended

Three things that look like bugs and are not. Verified by direct reproduction;
do not re-investigate.

- **`file_stats()` unguarded `.stat()` (collect.py:100).** Looks like the
  dangling-symlink crash class above, but the function early-returns on
  `if not path.exists()`, and `Path.exists()` is False for dangling links.
  Not reachable.
- **Malformed frontmatter degrades gracefully.** An empty file, a file with no
  frontmatter, and frontmatter with an unterminated `---` block each yield
  `has_description: false` and an empty description rather than raising.
- **Quote stripping does not mangle internal quotes.** `.strip("\"'")` only
  removes leading/trailing characters, so `Use "ship" to deploy` survives
  intact.

### Known true positive

`review/code-review-core` reports as having no frontmatter. That is correct —
it is a shared include, not a standalone command, and has none.
