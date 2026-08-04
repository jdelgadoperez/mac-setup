# config-audit — Known Issues

Running log of bugs in the `config-audit` skill itself (collector, template, or
analysis heuristics) — **not** findings about the audited configuration.

Each entry records how the bug was *observed*, its *root cause*, and the
*fix sketch*, so it can be picked up later without re-deriving the diagnosis.

Status legend: `open` · `fixed` · `wontfix`

---

## 1. Multi-line YAML frontmatter values parse as empty → false "missing description"

- **Status:** open
- **Found:** 2026-08-03, first `/config-audit` run
- **Severity:** medium — produces false findings that erode trust in the report

**Observed.** The report flagged `staff-eng-pre-flight` as having no
`description`, but the skill loads correctly in Claude Code and the harness
lists its full description. The frontmatter is valid YAML using a multi-line
block value:

```yaml
name: staff-eng-pre-flight
description:
  Use before opening a PR, requesting reviews, marking a draft ready, or
  pushing a substantive code change to a feature branch — ...
```

**Root cause.** `parse_frontmatter()` (`scripts/collect.py:106`) matches each
line independently with:

```python
re.match(r"^([A-Za-z_-]+):\s*(.*)$", line)
```

For `description:` the capture group is empty, and the continuation lines match
nothing, so they are silently dropped. Confirmed by direct reproduction — the
parsed value is `''`.

**Blast radius.** Not a one-off. Scanning `~/.claude` for frontmatter keys whose
value begins on a following line:

| Directory | Affected files |
|-----------|----------------|
| `skills/` | 3 |
| `commands/` | 6 |
| `agents/` | 0 |

So ~9 entries can be mislabeled "missing description" in any given run.

**Fix sketch.** Handle block scalars in `parse_frontmatter()`: when the value
capture is empty, consume subsequent lines that are more-indented than the key
and join them (collapsing whitespace). Also accept the explicit `|` and `>`
block indicators. A tiny hand-rolled pass is enough — no need to add a YAML
dependency for this.

**Regression test.** A skill whose `description:` spans three indented lines
must report `has_description: true` and the joined text.

---

## 2. Skill `name` falls back to `<dir>/SKILL` instead of the skill directory name

- **Status:** open
- **Found:** 2026-08-03
- **Severity:** low — cosmetic, but noisy in report tables

**Observed.** In the first run, 19 skills were named `ship/SKILL`,
`pr/SKILL`, `writing-voice/SKILL`, … rather than `ship`, `pr`, `writing-voice`.

**Root cause.** Two interacting causes. Those skills were unreadable (broken
symlinks), so no frontmatter `name` was available and the code fell back to a
path-derived name. In `broken_link_entry()` the fallback is
`path.relative_to(directory).with_suffix("")`, which for `ship/SKILL.md`
yields `ship/SKILL`. `inventory_skills()` uses the correct
`skill_dir.name` fallback, but only on the path where the file parses.

**Fix sketch.** In `broken_link_entry()`, accept the intended display name from
the caller rather than always deriving it from the file path — skills should
pass `skill_dir.name`, commands/agents keep the current path-derived form.

---

## 3. Collector crashed outright on a dangling symlink

- **Status:** fixed (2026-08-03)
- **Severity:** high — the audit could not run at all

**Observed.** First invocation died with
`FileNotFoundError: .../agents/research-analyst.md` before writing any output.

**Root cause.** `inventory_markdown_dir()` called `md.stat()` on every path
returned by `rglob("*.md")`. `rglob` yields dangling symlinks, and `stat()`
follows the link and raises.

**Fix applied.** Added a `broken_link_entry()` helper and an `md.exists()`
guard in `inventory_markdown_dir()`, plus the same guard on `SKILL.md` in
`inventory_skills()`. Broken links are now *recorded as inventory* with
`broken_symlink: true` — which is what surfaced the 19-broken-skills finding —
rather than aborting the run.

**Note.** `inventory_skills()`'s byte-sum uses `p.is_file()`, which already
returns `False` for dangling links, so that path needed no change.

---

## 4. Project scope silently mirrors user scope when run from `$HOME`

- **Status:** open
- **Severity:** low — confusing output, not incorrect

**Observed.** Run with no `--project`, the cwd was `$HOME`, so "project scope"
resolved to `~/CLAUDE.md` and `~/.claude/`, duplicating user scope. The report
then shows two scopes that are largely the same files, and
`is_git_repo: false` for a "project".

**Fix sketch.** When the resolved project root equals `$HOME` or is not a git
repo, either skip project scope or mark it clearly as "not a distinct project"
in the JSON, so the report can collapse the duplicate rather than presenting it
as a second scope.

---

## 5. Report asserted a dangling symlink was unrecoverable without checking history

- **Status:** open
- **Found:** 2026-08-04
- **Severity:** medium — a wrong factual claim that drives a destructive recommendation

**Observed.** The generated report stated that
`agents/research-analyst.md` was "**not** tracked in git — unlike the skills
breakage, there is nothing to restore," and recommended recreate-or-delete.
That was false. The file was added in `3e2d163` and deleted in `40e872e`; its
full content was recoverable the whole time via
`git show 40e872e^:dotfiles/.claude/agents/research-analyst.md`.

**Root cause.** The check used to support the claim was
`git log --diff-filter=A -- '*research-analyst*'`, whose output was misread as
empty. A single `--diff-filter=A` query on a glob does not establish that a
path was never tracked, and nothing verified the negative before it was
written into the report as fact.

**Why it matters.** The claim pointed toward deleting a file presented as
unrecoverable. If the user had accepted the framing without the follow-up
history check, the reasoning for the decision would have been wrong even
though the file was in fact restorable.

**Fix sketch.** Never assert "not in git" from a single log query. Before any
finding claims a file is unrecoverable, run
`git log --all --oneline --follow -- <path>` **and**
`git log --all --diff-filter=D -- <path>`; if either returns commits, report
the file as recoverable and name the restoring commit. When history is
genuinely empty, say "no commit found for this path" rather than asserting
the stronger claim.

---

## 6. Report blamed the wrong tool for the self-referential symlinks

- **Status:** open (diagnosis corrected; underlying install bug not yet fixed)
- **Found:** 2026-08-04
- **Severity:** medium — a fix aimed at the wrong file fixes nothing

**Observed.** The report recommended "fix the installer step that created
self-referential symlinks." Reading `install-claude.sh` shows it symlinks whole
skill *directories*:

```bash
symlink_claude_entry "$CLAUDE_DOTFILES/skills/$skill" "$CLAUDE_DIR/skills/$skill"
```

That cannot produce a file-level loop like `ship/SKILL.md -> ship/SKILL.md`,
and it already guards against dangling links with an `[ ! -e "$source" ]` check.
The installer was not the culprit.

**Actual mechanism.** Two linking styles coexist under `~/.claude/skills/`:

| Style | Example | Shape |
|-------|---------|-------|
| Installer (dir-level) | `ship`, `pr`, `writing-voice` | `~/.claude/skills/X` → dotfiles `skills/X` |
| Per-file | `config-audit` | real dir; `SKILL.md` → dotfiles `skills/X/SKILL.md` |

A per-file linking pass run against a skill whose directory is *already* a
dir-symlink resolves `~/.claude/skills/X/SKILL.md` through the link back to the
dotfiles source, then creates a link from that source onto itself — the exact
self-loop observed, and it lands in the dotfiles repo rather than in
`~/.claude`.

**Fix sketch.** Pick one style and make it exclusive. Before creating a
per-file link, refuse when the parent directory is a symlink (or resolve the
target with `realpath` and skip when source and target are the same inode).
The audit should also flag *mixed* linking styles under `skills/` as its own
finding — it is the precondition for this class of corruption.

---

## Non-issues (checked, working as intended)

- **Quote stripping in frontmatter.** `.strip("\"'")` was suspected of mangling
  values containing internal quotes. It does not — `str.strip` only removes
  leading/trailing characters, so `Use "ship" to deploy` survives intact.
  Verified by direct reproduction.
