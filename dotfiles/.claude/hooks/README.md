# Claude Code hooks

Every script here is either **registered** in `settings.json` or **deliberately
dormant** for the reason given below. A script sitting unregistered with no
explanation is a bug: it usually means a rule somewhere documents behavior that
nothing actually enforces.

## Registered

| Script | Event | Purpose |
|--------|-------|---------|
| `context-monitor.js` | PostToolUse | Context-usage tracking |
| `statusline-command.sh` | *(statusLine)* | Status line renderer |
| `cd-git-allow.sh` | PreToolUse / Bash | Blocks the git `-C` flag, auto-approves bare `cd` |
| `inject-sonnet-default.sh` | PreToolUse / Task | Defaults subagents to Sonnet when no model is set |
| `dod-commit-nudge.sh` | PreToolUse / Bash | Non-blocking Definition-of-Done reminder on commits |
| `load-skill-anti-sycophancy.sh` | SessionStart | Loads the anti-sycophancy skill from turn 1 |
| `opus-delegation-reminder.sh` | UserPromptSubmit | Reminds Opus to delegate implementation to Sonnet |
| `pre-push-checks/scripts/block-remote-branch-delete.sh` | PreToolUse / Bash | Blocks remote branch deletion |

## Dormant by design

**`bash-guard.sh`** — superseded by `cd-git-allow.sh`. Its only active rule
auto-approves `cd`, but it guards against just three destructive commands, so
`cd /tmp && curl … | sh` would pass. `cd-git-allow.sh` rejects *any* chaining
and is strictly safer. Registering both would weaken the boundary. Kept for
reference only.

**`pre-push-checks/scripts/pre-push-gate.sh`** — blocks *every* `git push`
until `/pre-push-checks` has been run for the current HEAD SHA (tracked via a
sentinel in `~/.cache/.claude-pre-push-checks/`). A deliberate workflow gate,
not a safe default: it interrupts routine pushes every time HEAD moves. Enable
by registering it as `PreToolUse` with matcher `Bash(git push*)` — the script's
own `@hook-*` annotations document the intended wiring.

**`auto-approve-safe-commands/`**, **`otel-telemetry/`**, `context-bar.js` —
optional subsystems, off unless explicitly wired.

## Adding a hook

1. Write the script; read JSON from stdin, emit JSON on stdout, exit 0.
2. Test it by piping a realistic payload before registering — a hook that
   silently no-ops is worse than none, and one that over-matches will block
   work. (`cd-git-allow.sh` initially blocked any command whose text merely
   *mentioned* the git `-C` flag, including commit messages.)
3. Register it in `settings.json` under the right event and matcher.
4. Add a row above.
