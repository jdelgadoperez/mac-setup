---
description: Audit whether Claude Code permission rules still form a real security boundary — blanket execution grants, deny/ask coverage, scope hygiene
argument-hint: "[--user-only|--project-only]"
---

# Permissions Audit

Audit whether this machine's Claude Code permission rules still constitute a
real boundary. The failure mode this hunts: **one accumulated `allow` rule for
an interpreter or runner silently nullifies every deny rule** — `deny:
["Read(**/.env*)"]` means nothing next to `allow: ["Bash(python3:*)"]`,
because `python3 -c 'print(open(".env").read())'` sails through.

This audit is strictly **read-only**: never modify settings files, never run
`claude config` or `/permissions`, and never *execute* a bypass — construct
bypass strings on paper only, as evidence in findings.

## Phase 0 — Inventory

Read and parse (respecting `$ARGUMENTS` scope flags):
- `~/.claude/settings.json` and `~/.claude/settings.local.json`
- `.claude/settings.json` and `.claude/settings.local.json`
- managed settings if present (e.g. `/Library/Application Support/ClaudeCode/managed-settings.json`)

For each file record: allow/deny/ask counts, `defaultMode`, sandbox and hooks
presence, and whether the file is git-tracked. Unparseable JSON (comments,
trailing commas) is itself a P0 finding — the file may be silently ignored.

## Phase 1 — Blanket execution grants (the P0 check)

Scan every `allow` array for rules whose command head is an interpreter or
runner: `bash sh zsh fish dash python python3 perl ruby node deno bun npm pnpm
yarn npx bunx make just env xargs eval uv poetry docker` (for docker: `run` /
`exec`). Classify each hit:

- **Arbitrary** — direct interpreter grant (`Bash(python3:*)`, bare `Bash`).
- **Arbitrary via subcommand** — `npm:*` / `pnpm *` / `make *` style grants
  that reach lifecycle/scripts and therefore arbitrary code.
- **Scoped acceptable** — a pinned, non-generic invocation (`Bash(npm run build:*)`).

For every Arbitrary finding, write out (do not run) one concrete command
proving the strictest deny rule in the same config is defeated. No finding
without a reproduction string.

## Phase 2 — Deny & ask coverage

Check whether deny or ask rules cover:
- **Secret reads**: `.env*`, `*.pem`, `*.key`, `credentials*`, `~/.ssh`, `~/.aws`, `~/.gnupg`
- **Destructive git**: `git push --force` / `-f`, `git reset --hard`,
  `git clean -fd`, branch/remote deletion
- **Irreversible publishing**: `npm publish`, `gh pr merge`, `gh repo delete`, deploys

An empty `ask` array means there is **no human checkpoint anywhere** — state
that explicitly, and name at least one project-specific ask rule worth adding,
justified from this repo's actual code or CI.

Also flag dead weight: allow rules for commands Claude Code never prompts for
anyway (plain `ls`, `cat`, `grep`, read-only git, …), exact-match rules that
are approval residue, and rule clusters that could consolidate into one
scoped pattern.

## Phase 3 — Scope hygiene

- Credential/secret denies belong in **user** settings (they protect the
  machine, not one repo).
- Project toolchain rules belong in tracked `.claude/settings.json`.
- Personal habits belong in `settings.local.json` — verify it's gitignored.
- Machine-specific absolute paths inside git-tracked settings are findings.

## Report

Produce, in chat (no file output):

1. **Posture score /100**: no blanket execution grant 30 · deny coverage 20 ·
   sandbox/hook posture 20 · ≥1 meaningful ask rule 10 · scope hygiene 10 ·
   rule population health 10. Any arbitrary-execution grant zeroes its 30
   points outright.
2. **Ranked findings** — severity, file + exact rule, consequence, the
   constructed reproduction string, and the fix.
3. **A ready-to-apply JSON patch per file** (shown, never applied).
4. **Not verified** — matcher-semantics assumptions that depend on the
   installed Claude Code version. Where a finding hinges on exact wildcard or
   compound-command matching behavior, say so rather than asserting it.
5. One sentence naming the single highest risk-removed-per-effort change.

Never recommend `bypassPermissions` or `--dangerously-skip-permissions` as a
fix for prompt fatigue; `/fewer-permission-prompts` plus scoped allows is the
right tool for that.

---

*Adapted from `permissions-audit-prompt.md` in
[claude-code-ultimate-guide](https://github.com/FlorianBruniaux/claude-code-ultimate-guide)
by Florian Bruniaux (CC BY-SA 4.0).*
