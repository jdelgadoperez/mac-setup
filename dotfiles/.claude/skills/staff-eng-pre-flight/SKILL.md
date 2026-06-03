---
name: staff-eng-pre-flight
description:
  Use before opening a PR, requesting reviews, marking a draft ready, or pushing a substantive code change to
  a feature branch — the author's own staff-engineer self-review gate. Triggers on "open a PR", "create the
  PR", "ready for review", "request reviews", "mark ready", "un-draft", "ship it", "I'm done", "ready to
  merge", "push this feature".
---

# Staff-Eng Pre-Flight

## Overview

Before code is exposed to reviewers or prod, step out of author mode and apply the lens a skeptical staff
engineer would apply in review — while you still own the diff and changes are cheap. This is a **forcing
reflection**, not a linter: it surfaces judgment gaps (blast radius, reversibility, over-build) that automated
checks and even multi-agent review miss because they don't know intent.

Running this gate writes a **sentinel** for the current HEAD SHA (`record-preflight.sh`). A `PreToolUse` hook
can block `gh pr create` / review-requests until that sentinel exists (and soft-nudge on feature-branch
pushes). New commits invalidate the sentinel — so it re-runs when the code actually changes.

## When to use

- About to `gh pr create`, mark a draft ready, or request/re-request reviews.
- About to push a substantive feature change to a branch.
- Any "I'm done / ship it / ready to merge / let's get this reviewed" moment on real code.

## When NOT to use (skip — don't gate)

- Doc-only, README, or comment-only changes.
- WIP/checkpoint pushes mid-task.
- Default-branch operations blocked by other rules.

## The lens

Read the actual diff first — `git diff $(git merge-base HEAD <base>)...HEAD` (base = your repo's
integration/default branch — verify per repo). Then work each dimension and mark **PASS / FIX / N/A** with a
one-line reason. Don't hand-wave a PASS you didn't check.

0. **Personal anti-pattern catalog (check first)** — Read `~/.claude/staff-eng-antipatterns.md` (start from
   the template if you haven't seeded it). For every entry whose **Tell** matches this change's shape, ask its
   **Check** question. A hit is a `FIX`. This is your proven-to-slip bar — it outranks the generic dimensions
   below. When AI-generated code is involved, this is where it usually gets caught.
1. **Blast radius** — Who/what depends on this? Shared modules, public contracts, multi-tenant paths,
   cross-service consumers, other teams' code. If this is wrong, what's the widest thing that breaks?
2. **Failure modes & reversibility** — How does it fail in prod (not in the happy path)? Behind a flag /
   reversible without a deploy? Rollback plan? Writes idempotent / retry-safe? Partial-failure story?
3. **Simplicity / altitude** — Is this the simplest change that achieves the goal, or did I over-build? Any
   abstraction added before a second caller exists? Could the diff be smaller?
4. **Contract & compatibility** — API / DB / event / queue / interface changes backward-compatible? Migration
   ordering safe? All consumers updated?
5. **Operational readiness** — Observability for the failure case (who/what/when/where/why in
   logs/metrics/spans)? Will on-call understand a failure without reading the code? Scale/perf: payload
   limits, N+1, unbounded loops?
6. **Pre-mortem** — "It's 2am and this paged someone. What's the most likely cause, and would they have what
   they need to debug it from telemetry alone?" Then: "What's the one thing a skeptical staff reviewer would
   block this on?"

## Output

Produce a compact verdict, not prose:

```
Staff-Eng Pre-Flight — <repo> @ <short-sha>
1 Blast radius        PASS  <reason>
2 Failure/revert      FIX   <what to fix>
3 Simplicity          PASS  <reason>
4 Contract/compat     PASS  <reason>
5 Ops readiness       FIX   <what to fix>
6 Pre-mortem          PASS  <reason>

VERDICT: FIX-FIRST  (2 must-fix before exposing)
Must-fix:
- <item>
```

Verdict is **READY** (all PASS/N/A) or **FIX-FIRST** (any FIX). On FIX-FIRST, list the must-fix items and stop
— do not write the sentinel.

## Recording the gate (after a READY verdict)

Only once the verdict is READY — or the must-fix items are addressed — record the sentinel so the hook lets
the action through:

```bash
~/.claude/skills/staff-eng-pre-flight/record-preflight.sh <repo-root> "READY: <one-line summary>"
```

Writes `~/.claude/.staff-preflight/<HEAD-sha>.done`. Amend/add commits afterward → re-run (new SHA has no
sentinel). Emergency bypass on the gated command: `STAFF_PREFLIGHT_SKIP=1`.

## Definition of Done (run before declaring code complete)

"Code complete" is a claim, not a feeling. Before saying done / complete / ready on a turn that produced
substantive code, run these three layers in order. They compose — none replaces another.

1. **Evidence — did it actually run?** `superpowers:verification-before-completion` (or your equivalent).
   Built, typechecked, tests green — observed output, not "should work." No evidence = not done.
2. **Judgment — would I reject this on review?** The lens above (dim 0 catalog first, then 1–6). Produce the
   verdict. Any `FIX` = not done.
3. **Gate routing — does what this touches demand a deeper gate?** Route by diff shape, then return:

| If the diff touches…                            | Also run                                                |
| ----------------------------------------------- | ------------------------------------------------------- |
| Large / risky / multi-file change               | Your multi-agent code-review command                    |
| A ticket with acceptance criteria               | Your delivery / AC-completeness review                  |
| Auth, trust boundaries, external input, secrets | A threat-model pass                                     |
| New error paths, logging, batch ops             | An observability/logging review                         |
| A domain with known invariants                  | That domain's checklist (see your anti-pattern catalog) |

**Done = all three layers clear.** Evidence green, lens READY, any diff-shape gate run (or consciously judged
N/A). Only then record the sentinel. If any layer isn't clear, say what's left, not "done."
