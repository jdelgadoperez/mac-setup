---
name: pr
description: End-to-end open-a-PR flow — run the staff-eng pre-flight self-review, commit and push via ship, then open the PR with a clear summary. Use when you say "open a PR", "create the PR", "ship this feature and open a PR", or "ready for review" and want the whole flow, not just a commit.
---

# Open a PR

Chains the existing pieces into one flow: **pre-flight gate → commit & push → open PR**. Each step is an
existing skill; this skill orchestrates the order and fills the gap `ship` leaves (it stops at push).

## When to use

- "Open a PR" / "create the PR" / "ready for review" on a feature branch with real code changes.
- You've finished implementation, tests pass, and you want it committed, pushed, and a PR opened in one go.

## When NOT to use

- Doc-only or WIP/checkpoint pushes → use `ship` directly, skip the gate.
- On the default branch → per git rules, feature work needs a branch first.

## Steps

1. **Confirm branch.** Run `git status`. If on the default branch (`main`/`master`), stop and create a
   feature branch first (`feat/<slug>` if no ticket) per git rules — never open a PR from the default branch.

2. **Pre-flight gate.** Invoke the `staff-eng-pre-flight` skill and work its lens against the actual diff.
   Resolve every `FIX` before proceeding. This writes the HEAD-SHA sentinel that unblocks `gh pr create`.

3. **Commit & push.** Invoke the `ship` skill to group changes into themed conventional commits, confirm the
   split, commit in dependency order, and push to origin.

4. **Verify commit freshness for the gate.** If step 3 produced new commits, the pre-flight sentinel from
   step 2 is now stale (new HEAD SHA). Re-run `staff-eng-pre-flight` against the final HEAD before creating
   the PR, or the `gh pr create` hook will block. (Order alternative: gate can run after commit — but running
   it first catches issues while changes are cheapest, then a quick re-affirm covers the new SHA.)

5. **Open the PR.** Run `gh pr create` with a clear title and a body that eases review: what changed, why,
   and how to verify. Follow the repo's PR conventions.
   - If `gh pr create` fails for any reason, immediately fall back to printing the manual GitHub compare URL
     — do not retry (per git rules, fail fast).

6. **Report.** Print the PR URL and the pushed commit SHAs.

## Guardrails

- Opening a PR is an externally-visible action. Confirm before `gh pr create` unless the user explicitly
  authorized it this turn.
- Never add a Claude co-authored footer to commits or the PR body.
- Verify the git root matches the intended repo before pushing.
