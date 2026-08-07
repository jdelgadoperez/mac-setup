# Audit Tooling Capability Spec

**Date:** 2026-08-07
**Status:** Spec only — nothing implemented, nothing changed.
**Purpose:** Exhaustive catalogue of every beneficial capability across four audit
tools, grouped by value and impact, to decide what to adopt into our own tooling.

---

## Sources surveyed

| # | Tool | License | Reuse posture |
|---|---|---|---|
| **A** | **Ours** — `/config-audit` skill + `/audit:permissions` + `/audit:spec` | private | baseline |
| **B** | `FlorianBruniaux/claude-code-ultimate-guide` (the original foundation) | **CC BY-SA 4.0** | ⚠️ attribution **and** share-alike; derivatives must carry the same license |
| **C** | `MJWNA/claude-config-audit` (v2.3.2, Ronnie Meagher) | MIT | ✅ copy freely w/ attribution |
| **D** | `paolodalprato/claude-config-audit` (v2.2.2, Paolo Dalprato) | MIT | ✅ copy freely w/ attribution |

**Licence note that shapes everything below.** B is the only CC BY-SA source. Our
`SKILL.md` already credits it; the two commands do not. Anything further we lift
from B propagates share-alike into our dotfiles. C and D are MIT and carry no such
constraint. **Where a capability exists in both B and C/D, prefer the C/D
formulation** — same value, no licence entanglement.

### What each tool actually is (they are not four of the same thing)

- **A (ours)** — static-correctness auditor. Deterministic Python collector +
  permission *reachability* analysis. Strongest formal model of whether a deny
  rule actually holds. Read-only.
- **B (Florian)** — a *guide* with a family of paste-in audit prompts:
  8-dimension setup audit (707 ln), permissions (306 ln), context/token (544 ln),
  spec-completeness (365 ln), plus `/security-check` + a curated threat DB.
  Broadest checklist coverage; mostly bash+grep heuristics.
- **C (MJWNA)** — *evidence-based cleanup* tool. Its thesis: decide keep/delete
  from real session-history usage, not inference. Mutating, with quarantine.
- **D (Paolo)** — *cross-environment cost & coherence* auditor for Claude
  **Desktop** (Chat/Cowork/Code). Its thesis: measure context cost honestly and
  reconcile instruction stacks across environments.

---

## TIER 0 — Verification gate (applies to every tier below)
> Read this before adopting anything. It is a precondition, not a task.

**No imported check ships until its underlying behavioural claim is verified
against current official Anthropic docs, or reproduced locally against the
installed `claude --version`. Claims that cannot be verified either way do not
become silent assumptions — they go into that check's own "Not verified"
handling (§6.6).**

**VERIFICATION COMPLETE — 2026-08-07.** Every claim below was checked against
official docs at code.claude.com (`docs.claude.com/en/docs/claude-code/*` now
301-redirects there — that split no longer exists) and against the installed
Claude Code **2.1.224** binary, plus one empirical permission test. **The gate
did exactly the job it was built for**: it confirmed the bulk of the matcher/
sandbox/scope semantics verbatim, but it also caught two fabricated-or-
misattributed claims (§3.5) and one over-generalized claim (§3.1) before they
shipped as checks — and, in the same pass, it caught a false-positive bug in
our *own* reachability analysis (see "Capabilities we already have," item 1).
That is the gate paying for itself in both directions. Detailed verdicts below
and inline at each tier.

| Claim | Source | Tier | **Verdict** |
|---|---|---|---|
| Matcher semantics — wrapper strip/no-strip lists, `:*` end-only, protected paths, scope merge | B | 1.1 | **CONFIRMED** |
| Auto-mode resolves allow/ask/deny **before** the classifier; which grants are dropped on entry | B | 1.3 | **CONFIRMED**, with 2 documented exceptions found (§1.1 additions) |
| Sandbox key semantics — `excludedCommands` bypass, `allowUnsandboxedCommands` scope, ignored-from-project keys | B | 1.2 | **CONFIRMED** |
| `MEMORY.md` load cutoff = first 200 lines / 25 KB | D | 3.1 | **CORRECTED SCOPE** — real, but `MEMORY.md`-only; CLAUDE.md loads in full regardless of length |
| Cache bug #40524 — `--resume` costs 87–118K tokens; `disableSkillShellExecution` mitigates | B | 3.5 | **CONTRADICTED** — misattributed; #40524 is a different, closed bug |
| `CLAUDE_HOOK_PROFILE` added v3.38.0 | B | 3.5 | **CONTRADICTED** — does not exist; fabricated |
| CC extends `Read`/`Edit` denies to `cat`/`head`/`tail`/`sed` in Bash | A (ours) | existing | **MODEL WRONG** — coverage is path-resolution-based, not a reader-binary list (`ls`/`file` denied, `echo` allowed). Made our `cross_surface` check unsound; see "Capabilities we already have" |

**Freshness reality:** C's last commit is 2026-04-26; B is CC BY-SA prose with no
version pinning; D targets Claude Desktop across three environments, not
Claude Code alone. Several of these claims were in fact already stale, as the
verdicts above show.

**The failure mode this prevents is the one that motivated this whole exercise.**
Tier 1 exists because our rubric scores phases that don't run — a check asserted
but not performed. Transcribing B's semantics block without verification rebuilds
that same failure inverted: instead of missing coverage, we'd ship **confident
false positives**, which is strictly worse because they generate action. A stale
"wrappers not stripped" list would flag safe configs as holes, or worse, clear
real ones. **This is precisely what happened with #40524 and `CLAUDE_HOOK_PROFILE`
below — the gate caught both before they shipped.**

Applies to Tiers 1, 3, and 6 equally — 1.1 names re-derivation explicitly, but
3.1/3.5 and the 6.x reporting claims carry the same risk and the same gate.

---

## TIER 1 — Correctness debts in what we already ship
> Highest impact. These are not new features; our tools currently **claim**
> coverage they do not have. Fixing them is a bug fix.

### 1.1 Restore the permission-matcher "ground truth" block *(from B)*
**Gap:** Our `/audit:permissions` is 94 lines vs the original's 306. The deleted
30-line semantics section is the load-bearing part — without it the audit reasons
from rule text alone, which B explicitly names as the cause of most bad audits.

**VERIFIED 2026-08-07 against code.claude.com docs + Claude Code 2.1.224 — every
item below is CONFIRMED.** This is the single largest block of the spec, and it
held up in full: rule shapes, wildcard positions, trailing ` *` word boundary,
`:*` end-only, compound-separator independence, both wrapper lists (including
`devbox run` — the docs literally give `devbox run rm -rf .` as their own
example of an unstripped wrapper), the env-var prefix asymmetry, and the
always-prompt wrapper list. The built-in read-only set matches our 14-item list
**verbatim**, and docs state outright: "The set is not configurable." Protected
paths and the deny-wins cross-scope merge are also confirmed as written.

Specific semantics we no longer tell the auditor:
- `:*` is recognised **only at the end** of a pattern. `Bash(git:* push)` matches
  **nothing** — the colon is literal.
- Trailing ` *` enforces a word boundary: `Bash(ls *)` matches `ls -la` but not
  `lsof`; `Bash(ls*)` matches both.
- Compound separators — `&&`, `||`, `;`, `|`, `|&`, `&`, newline — each subcommand
  must match independently. `Bash(safe *)` does **not** authorise `safe && rm -rf .`.
- **Wrappers stripped** before matching: `timeout`, `time`, `nice`, `nohup`,
  `stdbuf`, `command`, `builtin`, `noglob`, bare `xargs`.
- **Wrappers NOT stripped** (this is where holes come from): `npx`,
  `docker exec`, `devbox run`, `mise exec`, `direnv exec`, and any interpreter
  with `-c`/`-e`. `Bash(devbox run *)` authorises `devbox run rm -rf .`.
- Env-var prefixes: an **allow** rule does not match past an unknown assignment;
  a **deny**/**ask** rule does. Explains why near-identical allow entries that
  differ only by an env prefix never consolidate (matcher quirk, not user error).
- Exec wrappers that **always** prompt and cannot be prefix-approved: `watch`,
  `setsid`, `ionice`, `flock`, `find -exec`/`-delete`.
- Built-in read-only set (never prompted, not configurable): `ls cat echo pwd
  head tail grep find wc which diff stat du cd` + read-only git. An allow rule
  for these is **dead weight, not risk** — prevents false-positive findings.
- Protected paths, never auto-approved and **not** pre-approvable by an allow
  rule: `.git`, `.config/git`, `.vscode`, `.idea`, `.husky`, `.cargo`,
  `.devcontainer`, `.yarn`, `.mvn`, `.claude` (except `.claude/worktrees`), shell
  rc files, `.npmrc`, `.gitconfig`, `.mcp.json`, `.claude.json`.
- Scope precedence: managed → project local → project → user, arrays **merged and
  deduplicated** across scopes, not replaced. A deny anywhere applies everywhere.
- Keys silently **ignored** from project settings: `defaultMode: "auto"`,
  `sandbox.filesystem.disabled`, `sandbox.credentials` mask entries,
  `network.tlsTerminate`, `network.strictAllowlist`, `allowAppleEvents`.

⚠️ Licence: this is B's prose. Either rewrite in our own words from the official
docs, or carry the CC BY-SA attribution. **Recommend: re-derive from Anthropic
docs and verify against installed version**, which also fixes staleness.

**NEWLY DISCOVERED during verification — add these, none of the four source
tools had them:**
- **Six documented exception classes** where a built-in read-only command still
  prompts, despite being on the "never prompted" list above: (1) unquoted globs
  passed to a command with write/exec-capable flags (`find`, `sort`, `sed`,
  `git`); (2) `docker` invoked with a daemon-selecting flag (`-H`, `--context`,
  or Podman's `--url`/`--connection`); (3) `file` with `-m`/`--magic-file` or
  `-f`/`--files-from`; (4) Windows UNC network paths (also applies to the
  PowerShell tool); (5) commands the permission analysis can't parse, and any
  command over 10,000 characters; (6) `cd` followed by `git` (hooks live in the
  new directory) and `cd` followed by an output redirect that can't be resolved.
  Worth its own sub-check — these are exactly the shape of thing a naive
  "command head is in the read-only set → safe" audit would miss.
- **Command-line arguments are a distinct rank in the precedence chain**, not
  folded into an existing scope: Managed > Command line arguments > Local >
  Project > User.
- **Bare `Bash` ask rules are skipped for sandboxed commands — except in plan
  mode (v2.1.212+), where they prompt even for read-only sandboxed commands.**
  Worth flagging separately in mode-interaction checks (1.3), since it inverts
  the usual "sandboxed = fewer prompts" assumption specifically in plan mode.
- **The docs' own "always-prompt" wrappers (`watch`, `setsid`, `ionice`,
  `flock`, `find -exec`/`-delete`) CAN still be approved** — by an exact-match
  rule for the full literal command string. The correct framing for that bullet
  above is "cannot be auto-approved by a **prefix** rule," not "cannot be
  auto-approved," full stop.

### 1.2 Restore Phase 4 — Sandbox posture *(from B)*
**Gap:** deleted entirely, yet our rubric still awards **20/100 for "sandbox/hook
posture."** A fifth of the score has no phase behind it.

**VERIFIED 2026-08-07 — CONFIRMED.** All six sandbox keys check out against
docs and the 2.1.224 binary: `sandbox.enabled` (default `false`),
`autoAllowBashIfSandboxed` (default `true`), `allowUnsandboxedCommands`,
`excludedCommands`, `strictAllowlist` (v2.1.219+), `allowAppleEvents`,
`tlsTerminate`, `dangerouslyDisableSandbox`, `sandbox.credentials` (v2.1.187+),
`sandbox.filesystem.allowWrite`.

Checks: `sandbox.enabled` off by default · `excludedCommands` is a **full OS
bypass** and `allowUnsandboxedCommands: false` does **not** constrain it ·
`network.allowedDomains` is hostname-claimed with no TLS termination, so a broad
entry (`github.com`) is an egress path · `credentials` absent while sandbox on =
finding, because default read policy covers the whole machine incl. `~/.ssh`,
`~/.aws` · `filesystem.allowWrite` checked against what the project's own scripts
and CI actually write, or the sandbox gets disabled out of frustration.

### 1.3 Restore Phase 6 — Mode interaction *(from B)*
**Gap:** deleted entirely. Directly relevant — we run auto mode.

**VERIFIED 2026-08-07 — CONFIRMED, with additions.** The core mechanism (allow/
ask/deny resolve before the classifier; auto mode drops only broad grants on
entry) checks out. Verification surfaced material the auditor needs on top of
it:

- **Two documented exceptions to "resolves before the classifier":** writes to
  a protected path route to the classifier **even when an allow rule matches**
  it, and content-scoped ask rules fall back to a plain permission prompt
  rather than the classifier. Both need their own branch in any scoring logic
  that assumes "allow rule matched → classifier never runs."
- **`dontAsk` mode auto-DENIES ask-rule matches instead of prompting.** This
  directly falsifies a claim repeated in source B — that "ask rules are the
  only human checkpoint that survives every other setting." In `dontAsk` mode
  they don't survive; they silently deny. **Record this prominently**: any
  scoring logic that treats "empty ask array = no checkpoint anywhere" (or its
  converse — "non-empty ask array = a checkpoint exists regardless of mode")
  needs `defaultMode` folded in before it can trust that inference.
- **Full `defaultMode` value list**: `default`, `acceptEdits`, `plan`, `auto`,
  `dontAsk`, `bypassPermissions` — plus `manual` as a documented alias for
  `default` (v2.1.200+). Prior phrasing implicitly treated the mode list as
  just default/acceptEdits/plan/auto/bypassPermissions; `dontAsk` and the
  `manual` alias were missing.

Key insight: in auto mode, allow/ask/deny resolve **before the classifier runs**,
so an allow rule *subtracts oversight*. `Bash(git push:*)` disables exactly the
check the classifier is best at. On entering auto mode CC drops only *broad*
grants (blanket `Bash(*)`, wildcarded interpreters, package-manager runs, `Agent`
allows); narrow rules survive and keep suppressing review. Also: `defaultMode:
"auto"` is ignored from project settings.

### 1.4 Restore rule-population health as a real phase *(from B)*
Currently one compressed paragraph. Full version: count exact-match Bash rules
(approval residue that will never fire again) · cluster by command head to find
consolidation candidates · detect **dead rules** — covered by the built-in
read-only set, shadowed by a broader rule in any scope, or malformed (`:*` not at
end) · the env-prefix consolidation quirk from 1.1.

### 1.5 Honest scoring
Whatever we restore or don't, the rubric must not award points for phases that
don't run. Either restore the phase or remove its weight.

---

## TIER 2 — Evidence instead of inference
> The single biggest *capability* gap. Our tool guesses at usage; C measures it.

### 2.1 Deterministic session-history usage counting *(from C — MIT)*
`scripts/analyze-session-history.py` walks `~/.claude/projects/**/*.jsonl` and
counts, **without an LLM**:
1. `Skill` tool_use blocks where `input.skill == <name>` — canonical "it ran".
2. Slash-command usage via `<command-name>…</command-name>` tags, de-duped per session.
3. Bash pattern matches (`label=regex`) against `Bash` tool_use `input.command`,
   to attribute raw CLI usage to an owning plugin.

Emits per item: `count`, `firstSeen`, `lastSeen`, `byDay` histogram. Time-windowed
(default 90d, 0 = unlimited).

**Two design decisions worth copying verbatim:**
- **Excludes** skill-registry mentions inside `<system-reminder>` blocks — those
  appear every session for every installed skill regardless of use. Without this
  exclusion every skill looks used.
- Agents are told the JSON is **authoritative** and are **forbidden** from
  re-grepping or inventing counts. Closes off hallucinated usage statistics.

**Why it matters here:** replaces our "plausibly unused MCP servers" and
"overlapping always-on skills" — both currently model guesswork. We already have
`memory-bank` ingesting these same transcripts.

### 2.2 Usage-derived verdict vocabulary *(from C)*
Frequency bands Never / Rarely(1–3) / Occasionally(4–10) / Often(10+) / Constant;
`verdict: keep|delete|maybe`; confidence high/medium/low; machine `reasonCodes`
(e.g. `zero-usage-90d`); warn tags `overlap` / `duplicate` / `one-shot`. Also
"ramped then dropped" and "used again after a long gap" patterns.

### 2.3 Cost-provenance labelling *(from D — MIT)*
Every cost figure carries one of three labels and the report never blurs them:
- **measured** — schema/description actually visible in this session
- **deferred** — platform shows tool name only until on-demand load; only the
  name-entry cost is always-paid
- **assumed** — component not loaded this session; a declared range is used and
  **explicitly labelled an assumption**

Principle: *"measure, don't multiply"* — cost from actual characters, not generic
per-tool averages. **Directly relevant: we run ~50 deferred tools**, so a flat
per-tool estimate is simply wrong. Our current model is chars÷4 with no
provenance (as is B's — same weakness, D is the better source).

---

## TIER 3 — Checks we lack that map onto systems we actually run

### 3.1 Memory-file hygiene *(from D — MIT)*
We run the memory system and never audit it:
- Stale memories — mtime > 3 months in `~/.claude/projects/*/memory/`
- Referential staleness — memory cites files/functions/APIs that no longer exist
- Orphan files present but absent from `MEMORY.md`
- Broken index entries — `MEMORY.md` points at missing files
- Duplicate index entries pointing at the same file
- Dead project memory dirs for projects no longer on disk
- **`MEMORY.md` load cutoff — first 200 lines / 25 KB, whichever comes first.**
  Content past that never reaches context. We have no check for this.

**VERIFIED 2026-08-07 — CORRECTED SCOPE.** The cutoff itself is real: docs
state verbatim "The first 200 lines of `MEMORY.md`, or the first 25KB, whichever
comes first, are loaded at the start of every conversation." But this spec's
prior framing generalized the claim to "memory index files" in a way that
implied it also bounds CLAUDE.md — it does not. Docs are explicit on this
point: **"This limit applies only to `MEMORY.md`. CLAUDE.md files are loaded in
full regardless of length, though shorter files produce better adherence."**
The check above must scope its cutoff logic to `MEMORY.md` specifically and
must NOT apply the same 200-line/25KB truncation warning to CLAUDE.md or rules
files — those have no hard cutoff, only a soft adherence-quality argument for
staying short.

**Separately newly discovered: CLAUDE.md `@path` imports have a max depth of 4
hops.** This spec previously had no figure for this at all (it was an
unstated/unknown limit); it's now confirmed. This is a distinct mechanism from
the length cutoff above — it bounds import-chain depth (A imports B imports C
imports D imports E), not file size. What happens to content beyond hop 4 —
whether it's dropped silently or surfaced as a warning — is **not verified**;
don't assert a mechanism. Worth its own check regardless: walk `@path` import
chains from every loaded CLAUDE.md/rules file and flag any chain at or beyond
4 hops as "depth limit reached — behavior beyond this point not verified,"
per the §6.6 convention, alongside the `MEMORY.md` cutoff check above.

### 3.2 Hook content security *(from C + D)*
We inventory hooks and redact them; we never analyse them.
- **Network-calling hooks** (C): `curl`/`wget`/`nc`/`ssh`/URL in `hooks.*.command`
  — highest-risk class because `PreToolUse`/`UserPromptSubmit` fire constantly.
- **Shell injection** (C): unquoted `$ARG`/`${ARG}`, `eval`, `bash -c "$ARG"`.
- **Reverse shell / credential access** (B `/security-check`): `nc`, `/dev/tcp`,
  `/dev/udp` → critical; `id_rsa`, `.env`, `credentials`, `token` → critical.
- **Duplicate / contradictory hooks** (D): two hooks on one event doing redundant
  work, or one formatting and another reverting it.
- **Performance risk** (D): network calls or large scans with no timeout — hooks
  block tool execution.
- **Unmanaged background processes** (D): hooks spawning without cleanup.
- **Env-specific hardcoding** (D): absolute paths that break on another machine.
- **Registered-vs-present** (B): hooks on disk but not wired into settings.

### 3.3 MCP health checks — read-only, never launches a server *(from D)*
5-way classification **OK / Degraded / Broken / Misconfigured / Unverifiable**,
each with a recommended action. Checks run in cost order (file → PATH → process/
port → network last):
- script path missing after a move/rename; runtime (`node`/`python`/`uv`) not on PATH
- relative-path args that break under a different CWD
- npx/uvx package still published (`npm view`); version pinned vs `@latest`
- Docker daemon down / image absent; Ollama (`localhost:11434`); local DB port
- env var missing, empty, or a **placeholder** (`YOUR_API_KEY`, `xxx`, `changeme`)
- expired credentials → explicitly **Unverifiable**, ask the user, never guess

We currently check only "is the command installed."

### 3.4 DB-MCP risk *(from B)*
Flag MCP servers whose name matches `postgres|neon|supabase|mysql|database|mongo`
and require confirmation they're not pointed at production. **We run Supabase MCP
with write-capable tools.** (B's own version can only substring-match names; the
prod-vs-dev judgement is left to the reader — worth implementing better than B did.)

### 3.5 Known-bug / version-drift checks *(from B)*
**VERIFIED 2026-08-07 — BOTH bullets below are CONTRADICTED and must not be
adopted as written.** Corrected versions:

- ~~**Cache bug #40524** — `--resume` causes an 87–118K token
  re-announcement; mitigation flag `disableSkillShellExecution`.~~
  **MISATTRIBUTED.** Only the *bug pairing* is wrong here —
  `disableSkillShellExecution` itself is a real, documented setting, verified
  independently of this bug report; don't let it fall with #40524. Issue
  #40524 is real but is titled "[BUG] Conversation
  history invalidated on subsequent turns," is **CLOSED**, and describes
  prompt-cache invalidation causing repeated cache **writes** on ordinary
  subsequent turns — not `--resume` specifically, and with no 87–118K token
  figure anywhere in it. Docs do describe something adjacent and genuinely
  worth a check: resuming a large session after a break may offer resume-
  from-summary, and cache-miss costs after a break are real — but with no bug
  number and no specific token figure attached to that behavior. If this
  becomes a check, cite the cache-miss-after-a-break behavior from docs
  directly and drop the issue number and the token figure entirely.
- ~~`CLAUDE_HOOK_PROFILE` / `HOOK_PROFILE` env-driven hook profiles
  (v3.38.0+).~~ **DOES NOT EXIST.** Zero occurrences anywhere in the installed
  2.1.224 binary; absent from official docs. The cited "v3.38.0" is not a real
  Claude Code version number (CC's versioning is 2.1.x at time of writing).
  This claim appears fabricated. **Removed as a check to adopt.** See "what to
  NOT copy" below — it's recorded there as a fabricated-feature example, not
  carried forward here even as an aspiration.
- Record `claude --version` and mark version-dependent claims "Not verified"
  rather than asserting them. **This bullet is exactly the discipline that
  would have caught the two fabricated/misattributed items above before they
  were written into this spec — keep it, and apply it retroactively to any
  future claim sourced from a third-party guide.**

### 3.6 Prompt-injection / trust-boundary scanning *(from B `/security-check`)*
Neither C nor D nor we do this. Scans skill/agent/memory files for:
- zero-width & invisible unicode (`\u200B-\u200D`, `\uFEFF`, `\u00AD`)
- RTL/bidi override deception (`\u202E`, `\u202D`, `\u200F`)
- instructions hidden in HTML comments (`ignore|system|admin|override|forget`)
- base64 blobs > 40 chars outside hash/checksum context
- **trigger shadowing** — a skill claiming generic words (help, run, go, ok, the)
- scripts with `curl|bash`, `wget|bash`, remote eval → critical
- scripts writing to crontab/launchctl/systemctl/shell rc → critical
- scripts reading env vars **and** making network calls → critical
- **memory poisoning** — `ignore|forget|override|disregard|you are now|new role|
  system prompt` in `CLAUDE.md`/`MEMORY.md`

### 3.7 Threat-DB-backed config scanning *(from B)*
`threat-db.yaml`: malicious authors/skills + wildcard patterns, MCP CVEs,
minimum safe versions, IOCs, campaigns, attack techniques.
**Caveat to record:** it is a static checked-in snapshot refreshed only when
someone manually runs `/update-threat-db` (web-search driven). Freshness is
entirely manual — adopt the *shape*, don't inherit a stale file and trust it.

---

## TIER 4 — Quality rubrics for our own tooling
> We inventory skills/commands/agents but barely grade them. We author a lot of these.

### 4.1 The 16-criterion agent/skill/command rubric *(from B `/audit-agents-skills`)*
Weighted, letter-graded A–F, production threshold **80% (B+)**.

**Agents — 32 pts.** *Identity ×3:* descriptive `name` · `description` containing
triggers ("when"/"use") · `model` specified · `tools` restricted or justified.
*Prompt quality ×2:* role defined ("You are") · output format section · scope /
when-NOT-to-use · anti-hallucination language ("verify", "cite", "evidence").
*Validation ×1:* 3+ usage examples · edge cases · integration with other agents ·
error handling/fallback. *Design ×2:* single responsibility (<5000 tok, not
"general purpose") · no >50% keyword overlap with another agent (Jaccard >0.5) ·
composable · token budget <8000.

**Skills — 32 pts.** *Structure ×3:* valid frontmatter · `name` lowercase
`[a-z0-9-]{1,64}` · `description` >20 chars · `allowed-tools` present.
*Content ×2:* methodology/numbered steps · output format · examples · checklist
syntax. *Technical ×1:* bundled scripts use `set -e`/`trap`/`|| exit` · no
hardcoded `/Users/`/`/home/`/`C:\` paths · no plaintext secret keywords ·
dependencies documented. *Design ×2:* single responsibility · explicit
"When to use"/"Triggers" · no >50% overlap · portable.

**VERIFIED 2026-08-07 — `argument-hint`, `description`, `allowed-tools`, and
`model` are all CONFIRMED real command/skill frontmatter fields.** One field
was missing from this rubric entirely: **`effort:` is also a real SKILL.md
frontmatter field** (options: `low`/`medium`/`high`/`xhigh`/`max`) — it's a
Claude-Code-only extension, not part of the general Anthropic skill spec, so
its absence isn't itself a defect, but its presence should be graded (e.g.
under skills' *Structure* or *Design* criteria) when a skill sets it
incorrectly or omits it despite clearly being effort-sensitive.

**Commands — 20 pts.** *Structure ×3:* `name`+`description` · `argument-hint`
when `$ARGUMENTS` used · numbered/phase steps · usage examples.
*Quality ×2:* error/fallback handling · output format · validation gates ·
`$ARGUMENTS` parsing/defaults/validation.

Supporting mechanics: `--fix` emits concrete per-criterion patches; `--verbose`
reports passes as well as failures; Jaccard similarity for duplicate detection.

### 4.2 Rules-hygiene checks *(from B)*
Frontmatter present · `paths:` present and its glob **actually matches something
on disk** · no rule file > 150 lines · share of path-scoped vs always-on rules.
*(Note: B's implementation only tests the first glob of a single-line YAML list —
worth implementing properly if adopted.)*

**VERIFIED 2026-08-07 — CONFIRMED, plus a fact this spec didn't have before.**
`.claude/rules/` is an officially documented mechanism, not a community
convention we're relying on unstated support for, and `paths:` frontmatter for
glob-scoping a rule is documented. It also carries a **documented budget**:
1,000 expanded patterns / 4 MiB per rule file. What happens when a rule's
`paths:` glob exceeds that budget is **not documented and not verified** — do
not assert a failure mode. The actionable check is: expand the glob, count
matches and total bytes, and flag any rule file at or over either limit as
"budget exceeded — behavior on overflow not verified," per the §6.6 "Not
verified" convention, rather than checking only that the glob matches
*something* as today.

### 4.3 Rule/CLAUDE.md content quality *(from B context-audit + C)*
- **positive:negative instruction ratio ≥ 2:1** — count `always|prefer|use|should|
  must` vs `never|do not|avoid|forbidden`
- **vague-instruction detection** — `be careful|good practice|appropriately|as
  needed|when necessary|use your judgment|be smart` (we have this; B's regex is
  more complete)
- **duplicate section headers** — `grep -E "^#{1,3} " | sort | uniq -d`
- **contradiction detection by term intersection** — extract terms after
  "always "/"never ", sort, `comm -12`. Mechanical, better than eyeballing.
- **structure**: overview/purpose h2 · architecture h2 · anti-patterns section ·
  ≥3 h2 sections · no file > 400 lines
- **freshness**: `git log` recency on CLAUDE.md (6-month threshold)
- **stale skill references** in rules (C) — rules naming skills that no longer exist
- **decorative frontmatter** (C) — `description:` on a rules file is silently
  ignored by the rules loader
- **CLAUDE.md ↔ rules-dir alignment** (C) — index table vs actual files;
  loading-mode label vs actual frontmatter

### 4.4 Cross-project rule promotion *(from C)*
Scan project `.claude/rules/` across repos for repeated content that should be
promoted to user scope. Gated: requires **3+ projects**, non-varying content,
non-obvious value — otherwise emits an explicit *anti-recommendation*. The gate
is the valuable part.

### 4.5 Session-history rule mining *(from C)*
Scan transcripts for repeated corrections, repeated re-explanations, and explicit
endorsements ("yes exactly", "spot on") → candidate new rules. Gated: 3+ distinct
sessions **or** one high-cost mistake, stable content, not already inferable.

---

## TIER 5 — Workflow & lifecycle mechanisms
> Real value, but these change our tool's architecture. Per our own rules, the
> read-only → mutating change needs explicit approval before any work starts.

### 5.1 Quarantine-based reversible deletion *(from C — MIT)*
Every "delete" is `mv` into `~/.claude/.audit-quarantine/<timestamp>/`, **never
`rm -rf`**; refuses to operate outside `~/.claude/`; `.meta.json` sidecar per item
(original path, mode, timestamp) so restore is exact even under path-flattening
collisions; `--copy` mode for pre-edit snapshots; 7-day TTL + `purge`;
`restore.sh` reverses and surfaces `CONFLICT` when the destination exists.

### 5.2 Cross-run decision memory *(from C)*
Persist the user's keep/delete decisions per audit; `diff` classifies items as
**new / gone / changed** vs the previous run. Schema-versioned; refuses to diff
against an incompatible envelope; 180-day TTL. **Without this, every audit
re-litigates the same items** — which is our current state.

### 5.3 Interactive HTML decision UI *(from C)*
Rejects doing 50 keep/delete decisions inline in chat (scroll loss, no progress
visibility, verdicts scrolling off-screen). Self-contained HTML with localStorage
persistence, collapsible cards, live counters, undecided/mismatch filters, and a
"Generate Markdown" export ending in a machine-readable JSON envelope the session
parses back **without re-asking**. We already emit HTML — this is the round-trip.

### 5.4 Ordering & staging rules *(from C + D)*
- Run the **skills half before the rules half** — deleting a plugin orphans rules
  that reference it.
- Apply changes **one category at a time**, backup before each, re-validate JSON
  after each edit (D).
- Batch user decisions **3–4 at a time**, never all at once (D).
- Plugin cache: edit the manifest **before** moving the cache dir, else dangling
  cache with no manifest entry → confusing load errors (C).

### 5.5 Safe template injection *(from C)*
Balanced-bracket placeholder scanner that is JS-aware (tracks string literals,
`//` and `/* */` comments) rather than string-replace; re-serialise via
`json.dumps`; escape `<`, `>`, `/`, U+2028, U+2029 to prevent `</script>`
breakout. Plus `escapeHtml()` at render time as a redundant second layer. We
hand-fill `<!-- @SECTION -->` placeholders today — this is the hardened version.

### 5.6 Defence-in-depth secret redaction on the injection path *(from C)*
Independent of any agent check: recursive regex scrub before content reaches
HTML, markdown export, or history. Prefixes: OpenAI `sk-`/`sk-proj-`, GitHub
`ghp_|gho_|ghu_|ghs_|ghr_`, Slack `xox[bpao]-`, Google `AIza`, Anthropic
`sk-ant-`, Stripe `sk_live_|rk_live_|sk_test_`, AWS `AKIA|ASIA`, plus generic
`KEY=value`. Our collector redacts at *collection*; C also redacts at *render*.

### 5.7 Prerequisite gating & graceful degradation *(from C)*
Hard-stop if `~/.claude/` absent · stop if no auditable surface exists ·
require `python3` · require writable CWD · **warn when session history < 50
files** because verdicts will skew toward "looks underused" · warn if a prior
quarantine is still pending.

### 5.8 Parallel purpose-clustered agents *(from C)*
4–6 *differently-purposed* agents (not clones) in one dispatch: purpose-clustered
bucket agents + a dedicated security-pass agent. Rationale: avoids long-context
attention decay, keeps categories unmixed for overlap analysis, ~10× faster than
sequential review of 50 items. Plus the "never tail an agent's raw output file"
discipline.

### 5.9 Trigger-drift evals in CI *(from C)*
`evals/evals.json` holds should-trigger / should-not-trigger natural-language
queries kept in sync with the skill `description`, run in CI. Catches the failure
where a description edit silently stops the skill from triggering.

---

## TIER 6 — Reporting & framing
> Cheap, and they change how much the report can be trusted.

### 6.1 Cross-environment instruction hierarchy *(from D)*
D's most novel mechanism. Reconstructs the effective instruction stack per
environment and classifies every difference into five outcomes:
1. **Misplacement** (finding) — rule sits at a broader level than its real scope;
   pays tokens every session, fires almost never.
2. **Presumed specialization** (not a finding) → override map.
3. **Declared compensation** (not a finding) — e.g. Code never receives User
   Preferences, so CLAUDE.md legitimately restates it. Recommends a "shared core
   + marked compensation block" layout so audits can tell core from compensation.
4. **Drift** (finding) — divergence in the shared core *after subtracting
   declared compensations*.
5. **Coverage gap** (finding/question) — rule in one stack, absent from another
   where it should apply, with no compensation.

**The Rewrite Test** — the discriminator: take the general rule and the specific
rule and try *"In general X, but in this context Y."* Coherent → specialization.
Incoherent → genuine contradiction, always a finding. Better than our flat
"intra-file contradictions" check.

**Override map** — informational table: general rule | overridden where | by what
| declared? A *declared* override is called the healthiest pattern in the whole
hierarchy.

*(Note: D's environments are Chat/Cowork/Code. Our analogue is user vs project
vs local scope — the classification transfers, the environment axis doesn't.)*

### 6.2 System-prompt footprint split *(from D)*
Open every report with total system-prompt size split into **system-managed**
(fixed, reported for proportion only, never an optimisation target) vs
**user-managed** (instructions + installed components — the actionable surface).
Rule: the system-managed part of *other* environments is **not observable** and
must be stated as such, never estimated.

### 6.3 RAM vs token budgets kept separate *(from D)*
Per-runtime RAM bands (Node ~40–60 MB, Python ~25–45 MB, Docker ~200–500 MB,
Python+ML ~100–300 MB) and startup latency (npx 2–10 s, Docker 5–30 s), tracked
**separately** from token cost — different scarce resources. **Non-double-counting
rule:** shared server processes are marked shared and never summed across
environment columns.

### 6.4 Verification discipline as a hard rule *(from D)*
Before labelling anything "leftover/orphan", the tool **must open and read** the
file and **cite the exact file/JSON key** it read. Anti-hallucination guard baked
into the workflow. Complements the `git log --follow` + `--diff-filter=D`
double-check we already require before calling a symlink target unrecoverable.

### 6.5 Intervention plan as a single cross-layer table *(from D)*
One consolidated action table, quick-wins first: intervention | where | why |
**difficulty** (low = single reversible edit / medium = coordinated multi-file /
high = investigation or migration) | **expected impact**, quantified from the
audit's own measurements where possible — and **explicitly forbidden from
presenting an assumed figure as measured**. Plus a separate **"Questions for You"**
list for unresolved decisions, kept out of findings.

### 6.6 "Not verified" section *(from B)*
Every report ends with what could **not** be confirmed: version-dependent
behaviour, fields whose syntax couldn't be checked, anything needing the
`/sandbox` or `/permissions` panel. B's framing: being explicit here is worth more
than a complete-looking report.

**Environment record — add this as a standing convention, not just for this
spec.** Every report that asserts version-dependent behavior should record what
it was checked against, the same way this spec now does: *verified against
Claude Code 2.1.224 on 2026-08-07, docs at code.claude.com.* A claim with no
version/date/source triple attached is exactly the failure mode Tier 0 exists
to catch — see the #40524 and `CLAUDE_HOOK_PROFILE` corrections in 3.5, both of
which shipped in a source guide with no such record attached.

### 6.7 No-finding is a valid result *(from B)*
"If a phase finds nothing, one line saying so is the correct output." Never pad;
never manufacture findings to justify the audit; state plainly when a config is
good. We have a weaker version of this.

### 6.8 Reproduction-or-it-didn't-happen *(from B)*
No permission finding ships without a concrete bypass string someone else can run
— constructed **on paper, never executed**. We have this for interpreter grants;
B applies it to every finding.

### 6.9 Fleet sweep before deep audit *(from B)*
Sweep every repo's settings first, rank by exposure, then run the full audit only
where the sweep flags something. Ranking: blanket grant in a **tracked**
`settings.json` (ships to whoever clones) > blanket grant in `settings.local.json`
> zero deny rules + no sandbox > high allow count with no blanket grant (noise,
not risk). **We have 23 repos under `~/projects`** — this is directly applicable.

### 6.10 Platform / OS awareness *(from C + B)*
Windows path handling (`%USERPROFILE%\.claude\`), and D's note that some platform
limitations can't be worked around silently — e.g. individual MCP servers in
`claude_desktop_config.json` cannot be toggled; renaming a key does not disable
it; only remove-and-re-add works. Warn rather than pretend.

---

## Capabilities we already have that none of them match
> Do not trade these away in any refactor.

1. **Permission reachability analysis** (`analyze_reachability`) — flag-scoped
   deny detection, plus cross-surface inventory. **Neither C nor D does this**;
   D's permission checks are hygiene-only, C's are hook/secret-focused, and B
   reasons about it in prose without computing it.

   ⚠️ **The `cross_surface` half was UNSOUND and has been demoted to
   informational.** This was the most consequential finding of the whole
   2026-08-07 verification pass, and it cuts against our own tool.

   Empirical test, Claude Code 2.1.224 (scratch dir, dummy `.env`, project
   `deny: ["Read(**/.env)"]`):

   | Command | Result | What it establishes |
   |---|---|---|
   | `cat .env` | DENIED | control — a doc-named reader |
   | `strings .env`, `od -c .env`, `cut -d= -f2 .env` | DENIED | coverage exceeds the four doc-named examples |
   | `rg`, `jq`, `sort`, `uniq`, `perl -ne` on `.env` | DENIED | …far exceeds them |
   | `ls -la .env` | **DENIED** | `ls` never reads *contents* — so coverage is not about reading |
   | `file .env` | **DENIED** | same |
   | `echo skipping .env` | **RAN** | path appears verbatim → **not** naive string matching |
   | `strings plain.txt`, `jq -r .a plain.json` | RAN | controls — no blanket binary block |
   | `python3 -c "print(open('.env').read())"` | prompted only | documented arbitrary-subprocess carve-out is real |

   **Conclusion: the deny extension is not a fixed set of recognized reader
   binaries.** Claude Code parses the command, resolves which paths each
   argument actually operates on, and applies the `Read`/`Edit` deny to any
   Bash command touching that path — regardless of binary. `ls` denied
   together with `echo` allowed is the clean discriminator.

   **Therefore any check that infers exposure from binary identity is
   invalid**, including the original `reachable_via` / `already_covered`
   split. On the live config it reported `jq`, `rg`, `sort`, `uniq` as gaps;
   all four were then verified DENIED. Every one was a false positive.

   **Fix applied:** `DENY_EXTENSION_RECOGNIZED_READERS` removed entirely (a
   constant implying binary-identity coverage is worse than none);
   `cross_surface` now emits `allowed_bash_readers` as plain inventory with
   `status: "informational"` and `reportable: false`. `flag_scoped` is
   untouched and remains a real finding. The genuinely uncovered class is
   arbitrary subprocesses that `open()` files themselves, whose documented fix
   is `sandbox.credentials.files` with mode deny — matching guidance already in
   our SKILL.md.

   **Open question this raises (see #6 below):** is `cross_surface` worth
   keeping even as inventory, given it can no longer distinguish covered from
   uncovered?
2. **Deliberate non-inference of sibling binaries** — tried, reverted, documented
   in DESIGN-NOTES. Restraint backed by evidence.
3. **Parse-error hard gate** — grade capped at F while any config file fails to
   parse, plus the trap that `permissions`/`hooks` are *absent* not empty after a
   parse error (never report "no rules configured" for an inert file).
4. **Mixed symlink-style detection** — the per-file-vs-dir symlink hazard that
   corrupts the *source repo*. Nobody else has this.
5. **Recoverability double-check** before recommending deletion of a broken
   symlink target (`--follow` **and** `--diff-filter=D`).
6. **`mirrors_user_scope`** — prevents reporting one scope twice as two
   disagreeing scopes.
7. **Anti-security-theatre guidance** — refusing to recommend more `Bash(...)`
   deny patterns, and ranking `sandbox.credentials.files` (OS-enforced) above
   `PreToolUse` hooks above "say plainly it's best-effort."
8. **`/audit:spec`** — 5-layer delegation-readiness audit. C and D have no
   counterpart; only B does (and ours is the compressed version of B's).

---

## Cross-cutting: what to *not* copy

- **B's "Guide MCP installed: 2 pts"** — self-promotional, not a real check.
- **B's chars÷4 + flat "+7500 token" constant** — an unstated assumption
  presented as a measurement. D's measured/deferred/assumed model is strictly
  better and MIT.
- **B's `paths:` glob validity check** — only tests the first entry of a
  single-line YAML list; misses inline arrays. Adopt the intent, not the code.
- **B's DB-MCP check** — name substring match only; cannot actually tell prod
  from dev despite the rubric awarding points as if it could.
- **B's `claude-3-5-sonnet` in the deprecated-model regex** — will need
  maintaining against current model IDs regardless.
- **B's `CLAUDE_HOOK_PROFILE` / `HOOK_PROFILE` env-driven hook profiles
  (v3.38.0+)** — fabricated. Zero occurrences in the installed 2.1.224 binary,
  absent from official docs, and "v3.38.0" isn't a real Claude Code version.
  Do not adopt in any form, including as a speculative future check.
- **B's cache bug #40524 (`--resume` costs 87–118K tokens)** — misattributed.
  The real #40524 is a closed issue about prompt-cache invalidation causing
  repeated cache *writes* on ordinary subsequent turns, unrelated to `--resume`
  and with no 87–118K figure in it. If a cache-cost check is wanted, source it
  from the docs' own cache-miss-after-a-break description instead, with no
  issue number or token figure attached.
- **C's decision-memory as a reason to skip re-verification** — evidence is
  machine- and time-specific; a cached verdict is not a current one.

---

## Recommended sequencing (spec only — not yet approved)

**Phase 1 — fix what we claim (Tier 1).** Self-contained, no new deps, no
architecture change. Restores integrity of a score we've been quoting.

**Phase 2 — evidence (2.1, 2.2, 2.3).** Turns usage guesses into measurements.
Session-history counter is MIT and standalone.

**Phase 3 — systems we run (3.1, 3.2, 3.3, 3.4).** Memory hygiene, hook content
security, MCP health, DB-MCP risk.

**Phase 4 — self-grading (4.1–4.5).** We author a lot of skills/commands/agents
and grade none of them.

**Phase 5 — reporting (Tier 6).** Cheap, mostly prose-level.

**Phase 6 — lifecycle (Tier 5).** ⚠️ Read-only → mutating is an architecture
decision requiring explicit approval per our own rules. Do not start without it.

---

## Open questions for the user

1. **Read-only or mutating?** Tier 5 is the highest-leverage cluster but changes
   what the tool fundamentally is. Our current tool finds problems and leaves
   fixing to a human, every run, forever.
2. **One tool or several?** We have three entry points (`/config-audit`,
   `/audit:permissions`, `/audit:spec`). Much of Tier 3–4 has no obvious home.
3. **Licence stance on B.** Re-derive from official docs (clean), or carry CC
   BY-SA attribution on the commands as the skill already does?
4. **Threat-DB:** adopt the shape and maintain our own, or skip entirely? A stale
   threat DB is worse than none because it reads as coverage.

5. **Session-history counting — where does it live? (blocks Tier 2.1)**
   `memory-bank` already ingests exactly the transcripts the usage counter needs
   (`~/.claude/projects/**/*.jsonl`), via its own SessionStart/Stop hooks. Two
   options, and they are not equivalent:

   **(a) Extend `memory-bank` to emit usage counts.** No duplicated ingestion, one
   parser to maintain, counts stay fresh automatically via existing hooks.
   **But this is a cross-project dependency** — `config-audit` would depend on
   `memory-bank` internals. Our own architecture rule requires this coupling be
   proposed and explicitly approved *before* it's built, precisely because it's
   irreversible without a refactor. It also couples the audit's correctness to
   memory-bank's ingestion being current and its Qdrant DB being present.

   **(b) Vendor MJWNA's standalone `analyze-session-history.py` into the skill.**
   MIT, self-contained, stdlib-only, no runtime dependency on memory-bank, works
   on a machine where memory-bank isn't installed. **But** it re-walks the same
   JSONL tree with a second parser, so transcript-format changes must be tracked
   in two places.

   Leaning (b) for a first pass — it keeps `config-audit` self-contained, matches
   the existing `collect.py` design (stdlib-only, no external deps), and defers
   the coupling decision rather than making it by accident. Revisit if the
   duplicate-parser cost becomes real. **Needs your call either way.**

6. **Keep `cross_surface` as inventory, or delete it? (raised by the 2026-08-07
   verification)**
   It was our most sophisticated check and the one capability neither C nor D
   matched — but its premise (binary identity determines deny coverage) is now
   disproved, so it can no longer tell a covered binary from an uncovered one.
   It currently survives as `status: informational`, `reportable: false`.

   **(a) Keep as inventory.** "Which allowed, installed, file-reading binaries
   coexist with path denies" is still context a human or model can reason from,
   and the block now carries an explicit disclaimer.
   **(b) Delete it.** A check that cannot distinguish covered from uncovered
   adds noise to every report, and an informational block with a caveat is
   exactly the kind of thing a future reader re-promotes to a finding without
   re-reading the caveat.

   No lean. `flag_scoped` is unaffected either way and stays. The honest
   framing for the spec's "capabilities we have that others don't" claim is
   that it is now **one** capability (`flag_scoped`), not two.
