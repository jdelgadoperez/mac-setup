---
description: Audit whether Claude Code permission rules still form a real security boundary — blanket execution grants, deny/ask coverage, scope hygiene
argument-hint: "[--user-only|--project-only]"
---

# Permissions Audit

Audit whether this machine's Claude Code permission rules still constitute a
real boundary. The failure mode this hunts: **one accumulated `allow` rule for
an interpreter or runner silently nullifies every deny rule** — `deny:
["Read(**/.env*)"]` means nothing next to `allow: ["Bash(python3:*)"]`,
because `python3 -c 'print(open(".env").read())'` sails through (deny rules on
file-tool patterns do not extend to arbitrary subprocesses — see below).

This audit is strictly **read-only**: never modify settings files, never run
`claude config` or `/permissions`, and never *execute* a bypass — construct
bypass strings on paper only, as evidence in findings.

Record `claude --version` at the top of the report. Facts below are verified
against `code.claude.com/docs` (the old `docs.claude.com/en/docs/claude-code/*`
paths now redirect there) for Claude Code 2.1.224 — behavior on other
installed versions may differ; flag that explicitly where it matters.

## Matcher semantics you must use

Apply these precisely — most false "this rule is safe" findings come from
misreading the matcher, not the config.

- Rules are `Tool` or `Tool(specifier)`. Bare `Bash` and `Bash(*)` both match
  **every** command — treat them identically as arbitrary-execution grants.
- Wildcards match at any position: `Bash(git * main)` matches `git push origin main`.
- A trailing `" *"` enforces a word boundary: `Bash(ls *)` matches `ls -la`
  but **not** `lsof`; `Bash(ls*)` matches both.
- `:*` equals a trailing `" *"` but is **only** recognized at the end of a
  pattern. Mid-pattern the colon is literal: `Bash(git:* push)` won't match
  git commands — don't read `foo:*` as always "prefix wildcard."
- Compound separators split into independent match targets: `&&`, `||`, `;`,
  `|`, `|&`, `&`, newlines. **Each subcommand must match independently.**
  `Bash(safe *)` does not authorize `safe && rm -rf .`.
- **Stripped wrappers** (matching proceeds against what's inside): `timeout`,
  `time`, `nice`, `nohup`, `stdbuf`, `command`, `builtin`, `noglob`, bare `xargs`.
- **NOT stripped** — opaque to the matcher, so a rule scoped to the wrapper
  actually authorizes whatever it runs: `direnv exec`, `devbox run`,
  `mise exec`, `npx`, `docker exec`. Docs example: `Bash(devbox run *)`
  matches `devbox run rm -rf .`. Treat any allow rule built around one of
  these five as an arbitrary-execution candidate in Phase 1. (Interpreters via
  `-c`/`-e`, e.g. `python3 -c`, are not documented as stripped or not — don't
  assert behavior there; flag "not verified" if a finding depends on it.)
- **Env-var prefixes**: an `allow` rule does not match past a leading
  variable assignment outside a small known-safe set — `FOO=1 npm test` may
  not be authorized by `Bash(npm test)`. `deny`/`ask` rules match past any
  leading assignment, so they aren't weakened this way.
- **Always-prompt exec wrappers**: `watch`, `setsid`, `ionice`, `flock`, and
  `find` with `-exec`/`-delete`. Can't be auto-approved by a *prefix* allow
  rule — an *exact-match* rule for the full command string still can. Don't
  overstate this as "never approvable."
- **Built-in read-only set** (not configurable): `ls`, `cat`, `echo`, `pwd`,
  `head`, `tail`, `grep`, `find`, `wc`, `which`, `diff`, `stat`, `du`, `cd`,
  and read-only `git`. Never prompted regardless of config; forcing a prompt
  requires an explicit `ask`/`deny` rule — no toggle exists. Any `allow` rule
  for one of these is dead weight (flag in Phase 2).
- **Six documented exceptions** where a read-only command still prompts:
  1. Unquoted globs on commands with write/exec-capable flags (`find`, `sort`,
     `sed`, `git`) — glob could expand to e.g. `-delete`.
  2. `docker` with a flag pointing at a different daemon (`-H`, `--context`;
     also `podman --url`/`--connection`).
  3. `file` with `-m`/`--magic-file` or `-f`/`--files-from` (opens paths).
  4. Windows UNC network paths (`\\server\share\file`) — credential leak risk;
     also applies to PowerShell.
  5. Unparseable commands, and any command over 10,000 characters.
  6. `cd` + `git` (new dir's git hooks could run), and `cd` + output redirect
     whose target dir can't be resolved. `cd pkg && ls` is fine.
- **Protected paths**: `allow` rules never pre-approve writes to them.
  Directories: `.git`, `.config/git`, `.vscode`, `.idea`, `.husky`, `.cargo`,
  `.devcontainer`, `.yarn`, `.mvn`, `.claude` (except `.claude/worktrees`).
  Files (broader than commonly cited): shell rc files, `.npmrc`, `.gitconfig`,
  `.mcp.json`, `.claude.json`, `.gitmodules`, `.yarnrc`/`.yarnrc.yml`,
  `.pnp.cjs`, `.bazelrc`/`.bazelversion`/`.bazeliskrc`,
  `.pre-commit-config.yaml`, lefthook configs, `gradle-wrapper.properties`,
  `maven-wrapper.properties`, `.devcontainer.json`, `.ripgreprc`,
  `pyrightconfig.json`.
- **Scope precedence**: rules **merge** across scopes (not "deduplicated").
  Deny wins on conflict — a user-level deny blocks a project-level allow,
  since deny is evaluated before allow from any scope. Chain: Managed >
  Command line arguments > Local > Project > User.
- **Deny extension to Bash is path-resolution-based, not a fixed reader-binary
  list.** Docs verbatim: "Read and Edit deny rules apply to Claude's built-in
  file tools and to file commands Claude Code recognizes in Bash, such as
  `cat`, `head`, `tail`, and `sed`. They don't apply to arbitrary subprocesses
  that read or write files indirectly, like a Python or Node script that opens
  files itself. For OS-level enforcement that blocks all processes from
  accessing a path, enable the sandbox." Read literally the "such as" looks
  like a short named list — empirical testing on 2.1.224 shows the actual
  coverage is much broader and works by **parsing the command and resolving
  which paths each argument touches**, not by matching against a fixed set of
  binaries and not by naive string matching on the command text. With project
  `deny: ["Read(**/.env)"]`: `ls -la .env`, `file .env`, `rg . .env`,
  `jq -r . .env`, `sort .env`, `uniq .env`, `perl -ne "print" .env`,
  `strings .env`, `od -c .env`, and `cut -d= -f2 .env` were all **denied** —
  including `ls -la .env` and `file .env`, neither of which reads file
  *contents*, showing the rule keys off the path argument, not content access.
  Meanwhile `echo skipping .env` **ran**, even though `.env` appears verbatim
  in the command string — ruling out naive string matching. Controls
  (`jq -r .a plain.json`, `strings plain.txt`) ran fine, confirming it's the
  path rule firing on `.env`, not a blanket binary block.
  **Practical consequence: do not report "binary X isn't in the recognized-
  reader list, therefore it bypasses the deny" — that inference is invalid.**
  The genuinely uncovered class is arbitrary subprocesses that open the file
  themselves — `python3 -c "print(open('.env').read())"` only **prompted**,
  not denied, confirming that carve-out is real. The documented fix for that
  residue is the sandbox (`sandbox.credentials.files` with a deny mode — see
  Phase 3), not additional Bash deny patterns.

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
`exec`), plus the not-stripped wrapper commands from the matcher-semantics
section (`direnv exec`, `devbox run`, `mise exec`). Classify each hit:

- **Arbitrary** — direct interpreter grant (`Bash(python3:*)`, bare `Bash`,
  `Bash(*)`, or a not-stripped wrapper with a wildcard tail).
- **Arbitrary via subcommand** — `npm:*` / `pnpm *` / `make *` style grants
  that reach lifecycle/scripts and therefore arbitrary code.
- **Scoped acceptable** — a pinned, non-generic invocation (`Bash(npm run build:*)`)
  that also respects compound-separator matching (no bare `&&`/`;` escape).

For every Arbitrary finding, write out (do not run) one concrete command
proving the strictest deny rule in the same config is defeated. No finding
without a reproduction string.

## Phase 2 — Deny & ask coverage

Check whether deny or ask rules cover:
- **Secret reads**: `.env*`, `*.pem`, `*.key`, `credentials*`, `~/.ssh`, `~/.aws`, `~/.gnupg`
- **Destructive git**: `git push --force` / `-f`, `git reset --hard`,
  `git clean -fd`, branch/remote deletion
- **Irreversible publishing**: `npm publish`, `gh pr merge`, `gh repo delete`, deploys

An empty `ask` array means there is **no human checkpoint anywhere** in
`default`/`acceptEdits`/`auto`/`plan` modes — state that explicitly, and name
at least one project-specific ask rule worth adding, justified from this
repo's actual code or CI. (Whether that checkpoint actually fires depends on
mode — see Phase 5.)

Also flag dead weight: allow rules for commands in the built-in read-only set
(plain `ls`, `cat`, `grep`, `pwd`, `head`, `tail`, `find`, `wc`, `which`,
`diff`, `stat`, `du`, `cd`, read-only `git` — see matcher semantics), exact-match
rules that are approval residue, and rule clusters that could consolidate into
one scoped pattern. Remember the deny-extension gap from matcher semantics:
a deny on `.env*` reads stops `cat`/`sed`-style access but not an arbitrary
interpreter one-liner — cross-reference against Phase 1 findings rather than
treating deny coverage as sufficient on its own.

## Phase 3 — Sandbox posture

Sandbox is **off by default** (`sandbox.enabled` default: `false`). If off,
score this phase 0 honestly — that is not a bug in the audit, it's an accurate
reflection of no OS-level boundary existing. Don't pad a zero with caveats.

If enabled, check:
- **Two independent layers**: filesystem and network — evaluate separately.
- **Default filesystem write** scope: cwd + session temp only.
- **Default filesystem read** scope: the entire computer except denied
  directories — this still includes credential files like `~/.aws/credentials`
  and `~/.ssh/` unless explicitly denied. There is no built-in credential deny
  list; only what's explicitly configured is protected.
- **`sandbox.credentials`** (requires Claude Code v2.1.187+) should enumerate
  credential files/env vars to protect, enforced on macOS via Seatbelt. Sandbox
  on with no `sandbox.credentials` entries is a finding — the read-everything
  default is live and unmitigated.
- **`autoAllowBashIfSandboxed`** (default `true`) auto-approves sandboxed
  commands without a matching allow rule. This is the intended replacement for
  a long allow list — note where it's relied on instead of explicit rules,
  since it changes what "no allow rule" means for this config.
- **`allowUnsandboxedCommands: false`** disables the `dangerouslyDisableSandbox`
  escape hatch, but does **not** close `excludedCommands` — entries there still
  run fully unsandboxed regardless of this setting, and there is no
  managed-only lockdown for `excludedCommands` (a developer can always append
  to it). Treat every `excludedCommands` entry as a full OS-boundary bypass and
  ask what it can reach: `docker` (volume mounts, daemon socket), `kubectl`,
  `ssh`, `make` are the usual offenders.
- **Network layer**: no domains pre-allowed by default; first use of a new
  domain prompts. The built-in proxy enforces the allowlist by requested
  hostname and, by default, does not terminate or inspect TLS — a broad entry
  like `github.com` can create exfiltration paths via domain fronting or
  similar techniques. Flag any wildcard or umbrella domain entry.
- **`sandbox.filesystem.allowWrite`**: cross-check against what this
  project's scripts/CI actually write — an under-scoped list just gets the
  sandbox disabled out of frustration.
- **Settings-scope gotchas** — silently ignored from **project/local**
  settings (must be user, managed, or CLI `--settings`): `permissions.defaultMode:
  "auto"`, `sandbox.filesystem.disabled`, `sandbox.credentials` mask entries,
  `network.tlsTerminate`, `network.strictAllowlist` (also needs v2.1.219+),
  `allowAppleEvents`. Flag any of these in a project/local file as inert.

## Phase 4 — Scope hygiene

- Credential/secret denies belong in **user** settings (they protect the
  machine, not one repo).
- Project toolchain rules belong in tracked `.claude/settings.json`.
- Personal habits belong in `settings.local.json` — verify it's gitignored.
- Machine-specific absolute paths inside git-tracked settings are findings.

## Phase 5 — Mode interaction

- Valid `permissions.defaultMode` values: `default`, `acceptEdits`, `plan`,
  `auto`, `dontAsk`, `bypassPermissions`. `manual` is an alias for `default`
  (v2.1.200+). A session starts in `defaultMode`, which is Manual (`default`)
  unless overridden.
- **Decision order** — the first matching step wins: actions matching an
  allow/ask/deny rule resolve immediately, *except* two documented cases that
  still route to the full classifier: (1) writes to protected paths, even
  when an allow rule matches; (2) content-scoped ask rules can still fall back
  to a permission prompt rather than resolving immediately.
- **Auto mode drops broad grants on entry** — does not honor, even if
  present: blanket `Bash(*)`/`PowerShell(*)`; wildcarded interpreters like
  `Bash(python*)`; package-manager run commands; `Agent` allow rules. Narrow
  rules carry over — documented example: `Bash(npm test)`. A surviving narrow
  allow rule in auto mode subtracts classifier oversight for that exact
  command — treat survival as reducing, not adding, protection. (A rule like
  `Bash(git push:*)` as an illustrative survivor would be my inference, not a
  documented example — flag as such if used.)
- **Correction — ask rules are not a universal checkpoint.** In `dontAsk`
  mode, Claude Code **denies** any call matching an explicit `ask` rule
  instead of prompting. An ask rule that reads as a safety net in
  `default`/`auto`/`plan` becomes a silent denial in `dontAsk` — check the
  configured mode before crediting an ask rule as a working checkpoint.
- Content-scoped ask rules (e.g. `Bash(git push *)`) still force a prompt even
  for sandboxed commands, in every mode except `dontAsk` (where they deny, per
  above). A bare `Bash` ask rule (or `Bash(*)` as ask) is *skipped* for
  sandboxed commands — except in **plan mode**, where it is not skipped and
  still prompts even for read-only sandboxed commands (v2.1.212+).
- `defaultMode: "auto"` set from project or local settings is ignored
  (v2.1.142+) — it must be set in `~/.claude/settings.json` to take effect.
  Flag any project/local file that sets it as dead configuration.
- If hooks are configured, check whether a `PreToolUse` hook exits non-zero to
  block anything, and whether its matcher actually catches the stripped/
  not-stripped wrapper forms from the matcher-semantics section — a hook
  written against the literal command string can be defeated the same way an
  allow rule can.

## Report

Produce, in chat (no file output):

1. **`claude --version`** used for this audit, stated up front.
2. **Posture score /100**: no blanket execution grant 30 (Phase 1; any
   arbitrary-execution grant zeroes this outright regardless of everything
   else) · deny & ask coverage 20 (Phase 2) · sandbox posture 20 (Phase 3 — a
   config with sandbox off scores 0 here, and that is an honest zero, not a
   penalty for missing information) · ≥1 meaningful ask rule 10 (Phase 2,
   cross-checked against Phase 5's mode behavior — an ask rule that resolves
   to a silent deny under `dontAsk` does not count as a working checkpoint) ·
   scope hygiene 10 (Phase 4) · rule population health 10 (Phase 2 dead-weight
   and consolidation findings).
3. **Ranked findings** — severity, file + exact rule, consequence, the
   constructed reproduction string, and the fix.
4. **A ready-to-apply JSON patch per file** (shown, never applied).
5. **Not verified** — list, plainly:
   - Any finding whose matcher behavior depends on the installed Claude Code
     version differing from 2.1.224.
   - Any field whose exact syntax couldn't be confirmed from this config alone.
   - Anything that would need the `/sandbox` or `/permissions` interactive
     panel to confirm (e.g. live-resolved effective rules after merge) rather
     than static file inspection.
   - The `-c`/`-e` interpreter-flag stripping question noted in matcher
     semantics, if it came up in any finding.
   Where a finding hinges on exact wildcard, compound-command, or mode-gating
   behavior that this list doesn't cover, say so rather than asserting it.
6. One sentence naming the single highest risk-removed-per-effort change.

If a phase finds nothing, one line saying so is the correct output for that
phase — never pad to make a phase look substantive.

Never recommend `bypassPermissions` or `--dangerously-skip-permissions` as a
fix for prompt fatigue; `/fewer-permission-prompts` plus scoped allows (and,
where appropriate, sandbox + `autoAllowBashIfSandboxed`) is the right tool for
that.

---

*This audit's structure was originally adapted from
`permissions-audit-prompt.md` in
[claude-code-ultimate-guide](https://github.com/FlorianBruniaux/claude-code-ultimate-guide)
by Florian Bruniaux (CC BY-SA 4.0). The matcher-semantics, sandbox, and mode
facts above have since been re-derived and independently verified against
official Claude Code documentation at `code.claude.com/docs` for v2.1.224,
including empirical testing of the deny-rule subprocess carve-out — they are
not copied from the original source.*
