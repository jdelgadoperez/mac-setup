---
name: review-prs
description: Batch review open PRs requesting your review. Fetches, displays, and dispatches parallel reviews with optional inline comment posting.
---

# review-prs Skill

Orchestrates fetching, selecting, and reviewing PRs where the user is a requested reviewer.

---

## Phase 0: Sandbox Detection

Before fetching PRs, determine whether the sandbox is active by running **without** `dangerouslyDisableSandbox`:

```bash
gh auth status 2>&1
```

- If the command **succeeds** (exit 0): set `sandbox_active = false`. All subsequent `gh` commands run normally.
- If the command **fails with a TLS/certificate/sandbox error** (e.g. `x509`, `OSStatus`, `Operation not permitted`, `token in keyring is invalid`): set `sandbox_active = true`. All subsequent `gh` commands must run with `dangerouslyDisableSandbox: true`. The sandbox blocks keychain access, causing `gh` to report an invalid keyring token — this is a sandbox signal, not a real auth failure.
- If it fails for any **other reason** (network timeout, explicit login prompt): report the error and stop.

Also determine the GitHub org. Run:

```bash
gh api user --jq '.login'
```

Then check CLAUDE.md or project config for org name. If not found, ask the user. Hold `org` in context.

Hold `sandbox_active` in context for all subsequent Bash calls.

---

## Phase 1: Fetch & Enrich

### 1.1 Fetch PRs

Run (with `dangerouslyDisableSandbox: true` only if `sandbox_active = true`):

```bash
gh search prs --review-requested=@me --state=open --json number,title,author,repository,url,createdAt --limit 25
```

Parse the JSON array. Each item has: `number`, `title`, `author.login`, `repository.name`, `url`, `createdAt`.

If the array is empty, output: "No open PRs requesting your review." and stop.

### 1.2 Enrich with approval counts

For each PR, run (with `dangerouslyDisableSandbox: true` only if `sandbox_active = true`):

```bash
gh pr view <number> --repo <org>/<repository.name> --json reviews --jq '[.reviews[] | select(.state == "APPROVED")] | length'
```

Store the approval count alongside each PR. A PR with **2 or more approvals** is **pre-approved**.

---

## Phase 2: Present & Select

### 2.1 Display the list

Sort PRs by `createdAt` ascending (oldest first). **Print the table directly as output text** (NOT inside `AskUserQuestion`). Include the GitHub PR URL for each so the user can open it in a browser for a human review alongside or instead of the batch review.

```
━━━ PRs Requesting Your Review ━━━

 #   Repo           PR       Author          Age    Title
 ─   ────           ──       ──────          ───    ─────
 1   api            #31497   EmilyParr       9d     fix(cli): require -r flag [PLAT-14352]
     https://github.com/<org>/api/pull/31497

 2   ai-tools       #59      jdelgadoperez   8d     fix(agents): add ADF workflow docs
     https://github.com/<org>/ai-tools/pull/59

 3   api            #30934   JonWolfeDrata   54d    feat(build): migrate to pnpm  [2+ approvals]
     https://github.com/<org>/api/pull/30934
```

- **Age** is days since `createdAt` (e.g. `9d`, `2h` for same-day PRs).
- The URL on the second line of each entry links directly to the PR in the GitHub UI.
- `[2+ approvals]` tag appears after the title when applicable.

This lets the user see their pending reviews without being forced into the review workflow.

### 2.2 Ask for selection

After printing the table, use `AskUserQuestion` to ask:

```
Enter numbers to review (e.g. "1, 2"), "all", or "done" to stop here.
"all" excludes [2+ approvals] PRs unless --all was passed.
```

Parse the user's response:
- `"done"` or `"none"` → stop. Print "No reviews started." and exit.
- `"all"` → select all PRs that are NOT pre-approved (or ALL PRs if `all_flag = true`)
- Comma-separated numbers (e.g. `"1, 3"`) → select those specific PRs by their displayed number
- Any number, including pre-approved PRs, is valid regardless of mode

If the user's input is empty or unrecognizable, re-display the selection prompt.

Explicit selection (comma-separated numbers) always reviews the specified PRs, even if pre-approved. The "all" keyword is the only path that applies the pre-approval filter.

---

## Phase 3: Parallel Dispatch

### 3.1 Ensure output directory exists

```bash
mkdir -p ~/.claude/reviews
```

### 3.2 Determine output filename for each selected PR

Format: `YYYY-MM-DD-<repository.name>--<number>.md`

Use today's date. Double dash (`--`) separates repo name from PR number to handle hyphenated repo names.

If a file at that path already exists, it will be overwritten.

### 3.3 Dispatch all subagents in parallel

Dispatch ALL selected PRs as parallel subagents in a single message using the Agent tool. Do not dispatch sequentially.

For each selected PR, dispatch a subagent with this instruction (fill in `<org>`, `<repo>`, `<number>`, `<output_path>`, and `<sidecar_path>`).

`<sidecar_path>` is the same as `<output_path>` but with `.json` extension instead of `.md`.
Example: if `<output_path>` is `~/.claude/reviews/2026-03-12-ai-tools--59.md`,
then `<sidecar_path>` is `~/.claude/reviews/2026-03-12-ai-tools--59.json`.

> You are performing a code review. Read `~/.claude/commands/review/code-review-core.md` and follow Steps 1-5 exactly to review PR #<number> in the `<org>/<repo>` repository.
>
> When your review is complete, write the FULL review output (all sections: Summary, Existing Unresolved Comments, Blocking Issues, Non-Blocking Feedback, Final Verdict) to: `<output_path>`
>
> Also write a JSON sidecar to: `<sidecar_path>`
>
> The sidecar maps each finding to its diff location for optional inline comment posting. Follow the JSON sidecar format described in Step 5 of the code-review-core prompt.
>
> Do NOT post anything to GitHub. Do NOT approve or comment on the PR. Write only to the local files.

If a subagent fails or errors, write the following to its output path instead:

```markdown
# Review Failed

**PR:** <org>/<repo>#<number>
**Error:** <error message or "Unknown error">
**Date:** <YYYY-MM-DD>
```

Do not let one failure block other subagents or the summary phase.

---

## Phase 4: Summary

After all subagents complete, read each review's **sidecar JSON** (`.json` file) to build the summary. The verdict comes from the sidecar's `verdict` field.

**Fallback:** If a sidecar JSON is missing or unparseable for a PR, fall back to scanning the markdown file for the verdict line (`APPROVE` or `REJECT`). Show the verdict and review link for that PR, but replace the finding index with `(inline posting unavailable — sidecar missing)`.

Print the summary using `AskUserQuestion`:

```
Reviews complete:

 Repo        PR       Verdict
 ai-tools    #59      REJECT     ~/.claude/reviews/2026-03-12-ai-tools--59.md
   Blocking:
     1. JSON injection risk                  (agents/claude/janet-jira-cli-expert.md:47)
     2. Overly broad skill glob              (agents/claude/janet-jira-cli-expert.md:12)
   Non-blocking:
     A. Augment path mismatch                (agents/augment/janet-jira-cli-expert.md:12)
     B. Keychain check coverage              (install-agents.sh:45)

 api         #31497   APPROVE    ~/.claude/reviews/2026-03-12-api--31497.md
   Non-blocking:
     A. Hard-coded region lists              (scripts/deploy.sh:142)
     B. No test coverage                     (general)

Post comments? Enter selections (e.g. "ai-tools 1, 2, D" or "api approve" or "none")
  Format: <repo> <ids>  where numbers = blocking, letters = non-blocking
  Use "all" for all findings, "approve" for bare approval with no comments
  If multiple PRs from same repo: use "<repo> #<number> <ids>" syntax
```

For each finding in the sidecar's `comments` array:
- Blocking items: display number from the `id` field (e.g. `blocking-1` → `1.`)
- Non-blocking items: display letter from the `id` field (e.g. `non-blocking-A` → `A.`)
- Location: `(<path>:<line>)` if path is non-null, otherwise `(general)`

---

## Phase 5: Post

### 5.1 Parse Selection

Wait for user input. Parse the input:

| Input example | Meaning |
|---------------|---------|
| `ai-tools 1, 2, D` | Post blocking-1, blocking-2, non-blocking-D from ai-tools |
| `ai-tools all` | Post all findings from ai-tools |
| `api approve` | Post bare APPROVE with no inline comments |
| `ai-tools 1, 2, api approve` | Selected from ai-tools + bare approve on api |
| `none` | Skip posting, done |

- Numbers map to blocking items; letters map to non-blocking items.
- `<repo>` must match the Repo column from the Phase 4 summary table.
- **Same-repo disambiguation:** If multiple reviewed PRs share the same repo name, require `<repo> #<number> <ids>` syntax (e.g. `"api #31497 1, 2"`). If only one PR was reviewed for a repo, bare repo name is sufficient.
- **Invalid IDs:** If a selected ID doesn't exist in the sidecar, report the invalid selection and re-prompt.
- If input is unrecognizable, re-display the selection prompt.

If `none`, print "No comments posted." and stop.

### 5.2 Derive Review Event

For each repo/PR being posted to:

- Any selected finding with `"type": "blocking"` → event = `REQUEST_CHANGES`
- No blocking findings selected (or bare `approve`) → event = `APPROVE`

### 5.3 Verify Commit Freshness

For each PR about to be posted to, fetch the current head SHA:

```bash
gh pr view <number> --repo <org>/<repo> --json headRefOid --jq '.headRefOid'
```

(Use `dangerouslyDisableSandbox: true` if `sandbox_active = true`.)

If the current head SHA differs from the sidecar's `commit_id`, print:

```
Warning: <org>/<repo> #<number> has new commits since the review was generated.
  Reviewed: <sidecar commit_id>  |  Current: <current SHA>
  Inline comments may land on wrong lines. Re-review recommended.
  Post anyway? (y/n/re-review)
```

- `re-review` → abort posting for this PR, suggest re-running `/review:prs`
- `n` → skip this PR
- `y` → proceed

### 5.4 Run resolve-lines

For each PR being posted, verify line numbers against the current diff:

```bash
gh pr diff <number> --repo <org>/<repo> | ~/.claude/scripts/review-tool.py resolve-lines --sidecar <sidecar_path>
```

Read the corrected sidecar back before composing payloads. If any comment shows `???` (file not in diff), drop it from the payload and note it in the confirmation output.

### 5.5 Compose Review Payloads

For each PR being posted (after freshness check + resolve-lines), build a GitHub review payload using `review-tool.py post`:

```bash
~/.claude/scripts/review-tool.py post --sidecar <sidecar_path> --select "<ids>" --dry-run
```

Review the dry-run output. If it looks correct, proceed to confirmation.

### 5.6 Confirm Before Posting

Display using `AskUserQuestion`:

```
About to post:

  <org>/ai-tools #59 (commit 87486ea):
    Review type: REQUEST_CHANGES
    Inline comments: 3  (blocking-1, blocking-2, non-blocking-D)
    Body comments: 0

  <org>/api #31497 (commit e3be9d5):
    Review type: APPROVE
    Inline comments: 1  (non-blocking-A)
    Body comments: 0

Proceed? (y/n)
```

If `n`, return to the selection prompt (5.1). If `y`, proceed.

### 5.7 Post via review-tool.py

Post each PR (can be parallel if multiple):

```bash
~/.claude/scripts/review-tool.py post --sidecar <sidecar_path> --select "<ids>" --yes
```

(Use `dangerouslyDisableSandbox: true` if `sandbox_active = true`.)

### 5.8 Report and Clean Up

Print results:

```
Posted:
  <org>/ai-tools #59  — REQUEST_CHANGES, 3 inline comments  <pr url>
  <org>/api #31497     — APPROVE, 1 inline comment           <pr url>
```

Clean up temp files:

```bash
rm -f /tmp/claude-review-*.json
```

---

## Notes

- Use `dangerouslyDisableSandbox: true` only when `sandbox_active = true` (determined in Phase 0)
- Subagents must NOT post to GitHub under any circumstances
- Each subagent is fully independent — no shared state between them
- Phase 5 is the ONLY place where GitHub posts are made — and only after explicit user selection and confirmation
- Sidecar JSON files live alongside the markdown reviews in `~/.claude/reviews/` with the same filename and `.json` extension
- This command produces single-agent reviews per PR. For deeper multi-agent reviews on a specific PR, use `/review:pr` instead
