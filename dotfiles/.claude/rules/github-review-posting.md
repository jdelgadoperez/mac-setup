# GitHub Review Posting Rules

Canonical rules for posting code reviews to GitHub PRs. Applies to any command or skill that posts a review (inline comments + body + event). Reference from command `allowed-tools` as `Rule(~/.claude/rules/github-review-posting.md)`.

## The atomic-posting rule

**Inline comments, the body, and the review event MUST post in a single API call.** Never post the body with one call and then add inline comments with another — the PR gets two separate "reviews" in its history, the inline comments land without context, and the event type (APPROVE / REQUEST_CHANGES / COMMENT) gets associated only with whichever call carried it.

Use `POST /repos/{owner}/{repo}/pulls/{pull_number}/reviews` with the full payload:

```json
{
  "commit_id": "<head SHA>",
  "body": "<review summary>",
  "event": "APPROVE|REQUEST_CHANGES|COMMENT",
  "comments": [
    {"path": "src/foo.ts", "line": 42, "side": "RIGHT", "body": "..."},
    ...
  ]
}
```

Prefer `~/.claude/scripts/review-tool.py post` which wraps this endpoint correctly over rolling your own `gh api` call.

## Event derivation

The review event is derived, not asked:

| Selected findings include | Event |
|---------------------------|-------|
| Any `blocking` finding | `REQUEST_CHANGES` |
| Only `non-blocking` findings, OR bare approve | `APPROVE` |
| Explicit user override | Respect user choice |

Never post `COMMENT` — it's ambiguous. Every review should either approve or request changes.

## Pre-post checklist (in order)

1. **Verify commit freshness.** Fetch current `headRefOid` via `gh pr view <n> --repo <org>/<repo> --json headRefOid`. If it differs from the sidecar's recorded `commit_id`, warn the user and require explicit opt-in before posting — inline comments may land on wrong lines.

2. **Run `resolve-lines`.** Pipe `gh pr diff` through `~/.claude/scripts/review-tool.py resolve-lines --sidecar <path>` to correct line numbers against the current diff. Any comment whose file isn't in the diff (`???` marker) must be dropped, not posted blind.

3. **Show dry-run payload.** Use `review-tool.py post --dry-run` to preview what will post. The user sees what GitHub will receive.

4. **Confirmation gate.** Display a structured summary via `AskUserQuestion` with the review event, inline count, and body size. Posting is an externally-visible mutation — one explicit opt-in per session.

5. **Post with `--yes` flag.** After confirmation, call `review-tool.py post --yes` to commit. Each PR posts independently — parallelize across PRs.

6. **Report posted URLs.** Print the `<pr-url>` for each posted review so the user can verify.

## What NOT to do

| Anti-pattern | Correct pattern |
|--------------|-----------------|
| Post body first, then add comments in a loop | Single atomic API call — body + comments + event together |
| Skip `resolve-lines` when the diff is "simple" | Always run — diff hunks truncate; wrong + confident = snarky |
| Use `gh pr review --comment` for approval | `--approve` for approvals, `--request-changes` for blocking. `--comment` leaves PR state unchanged. |
| Re-prompt the user between dry-run and post | One confirmation gate covers the actual post |
| Post without verifying commit freshness | Verify first; stale reviews land inline comments on wrong lines |
| Paste raw diff content into comment body | Cite file:line — reviewers already have the diff |

## Consumers

- `~/.claude/skills/review-prs/review-prs.md` — batch review posting
- `~/.claude/commands/review/address-feedback.md` — reply + resolve threads (uses GraphQL, different API shape — but same atomic principle)
- Any future review-posting command should reference this file
