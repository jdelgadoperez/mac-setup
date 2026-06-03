# Staff-Eng Pre-Flight — portable install guide

A layered forcing function so substantive code passes a staff-engineer lens **early and often**, not just at the PR boundary — and so AI-generated changes that allow patterns you'd reject get caught at the source. This is the generic, portable mechanism; seed the project-specific parts (anti-pattern catalog, deeper-gate routing) per machine.

## What's in this repo

| Path | Role |
|------|------|
| `skills/staff-eng-pre-flight/SKILL.md` | The lens + Definition of Done |
| `skills/staff-eng-pre-flight/{check,record}-preflight.sh` | Sentinel read/write (`~/.claude/.staff-preflight/<HEAD-sha>.done`) |
| `staff-eng-antipatterns.template.md` | Empty catalog template — copy to `~/.claude/staff-eng-antipatterns.md` and seed |
| `hooks/dod-commit-nudge.sh` | Soft Definition-of-Done reminder; self-gates on `git commit` |
| `hooks/pre-push-checks/scripts/staff-eng-preflight-gate.sh` | Hard-block PR-open/review-request, soft-nudge push, until a sentinel exists |
| `hooks/pre-push-checks/scripts/staff-eng-preflight-gate.test.sh` | 16-case test matrix (run with no sentinel) |
| `hooks/load-skill-anti-sycophancy.sh` | `SessionStart`: auto-loads the anti-sycophancy skill as context (no-op if that skill isn't installed) |

These deploy to `~/.claude/...` via your usual dotfiles symlink/copy step.

## Wiring (settings.json)

Add these hook entries to `~/.claude/settings.json` (`chmod +x` the scripts first):

```jsonc
"hooks": {
  "SessionStart": [
    { "hooks": [ { "type": "command", "command": "bash ~/.claude/hooks/load-skill-anti-sycophancy.sh" } ] }
  ],
  "PreToolUse": [
    { "matcher": "Bash", "hooks": [
      { "type": "command", "command": "bash ~/.claude/hooks/dod-commit-nudge.sh", "if": "Bash(git commit:*)", "timeout": 5 } ] },
    { "matcher": "Bash", "hooks": [
      { "type": "command", "command": "bash ~/.claude/hooks/pre-push-checks/scripts/staff-eng-preflight-gate.sh", "timeout": 5 } ] }
  ]
}
```

(Merge into existing arrays — don't replace them.)

Optional `permissions.allow` entries so recording the sentinel doesn't prompt each time:

```
"Bash(~/.claude/skills/staff-eng-pre-flight/record-preflight.sh:*)"
"Bash(~/.claude/skills/staff-eng-pre-flight/check-preflight.sh:*)"
```

No model or `allowed-tools` config is needed — the skill runs inline in the main session and defines no subagent.

## Wiring (CLAUDE.md)

Add two standing rules to `~/.claude/CLAUDE.md`:

1. **Generation-time** (Best Practices): *"On any turn that produced substantive code, before using completion language ('done', 'ready', 'passing'), run the `staff-eng-pre-flight` Definition of Done (evidence → lens + `~/.claude/staff-eng-antipatterns.md` → diff-shape gate routing) and state the verdict. Skip for doc/trivial/non-code turns."*
2. **Intent-time** (Command Routing): route "open a PR / ready for review / ship it / I'm done / push this feature" to run the `staff-eng-pre-flight` skill first, then hand off to the normal PR flow. Carve out doc/work-log/WIP commits.

## How it composes

- **Generation-time** (CLAUDE.md rule) → catches AI drift when code is produced.
- **Intent-time** (routing) → runs the lens when you signal you're about to expose work.
- **Commit chokepoint** (`dod-commit-nudge`) → soft reminder at `git commit`.
- **PR boundary** (`staff-eng-preflight-gate`) → deterministic hard backstop.

Bypass any gate with `STAFF_PREFLIGHT_SKIP=1`. The gate fails open on error.

## Per-machine project specifics (NOT in this repo)

Keep these local to each machine — they're project/employer-specific:
- The seeded **anti-pattern catalog** (`~/.claude/staff-eng-antipatterns.md`).
- Project-specific **deeper-gate routing** rows in SKILL.md's DoD table (e.g. domain review commands).
- Any repo-specific base-branch or invariant notes.
