---
name: review-pr
description: Multi-agent PR review that synthesizes feedback into a summary comment plus inline comments.
arguments:
  - name: pr_url
    description: GitHub PR URL (e.g., https://github.com/myorg/myrepo/pull/123)
    required: true
  - name: agents
    description: Comma-separated agent types to use (default: sam-senior-engineer)
    required: false
---

# Multi-Agent PR Review

Review a PR using multiple specialized agents, synthesize their feedback, and post:
1. A **brief summary review** (approve or request changes) — NOT a giant AI-generated wall of text
2. **Inline comments** attached to specific lines in the diff, each prefixed with `blocking` or `non-blocking`

> Every comment must be prefixed `blocking` or `non-blocking`. Always approve or request changes — never comment-only. Push detail into inline comments, keep the summary minimal. Account for existing comments to avoid duplicates.


## Inputs

- **PR URL**: $ARGUMENTS.pr_url
- **Agents**: $ARGUMENTS.agents

## Step 0: Select Agents (MANDATORY)

**STOP — do not fetch PR data or begin any review work until agents are confirmed.**

If agents were provided as an argument, use those. Otherwise:
1. Auto-discover available agents using the system context (no filesystem scanning needed).
2. Use `AskUserQuestion` to present them (multi-select) and ask which should review.
3. If none discovered, use `AskUserQuestion` to ask the user to provide agent names.

The `agents` argument accepts any agent types available in your Claude Code configuration as a comma-separated list.

**Do NOT default to any agent. Do NOT skip this step. The user must confirm which agents to use.**

## Workflow

### Step 1: Fetch PR Context

Use the `Bash` tool to run these `gh` commands in parallel:

```bash
gh pr view <PR_NUMBER> --repo <OWNER>/<REPO> --json title,body,files,additions,deletions,changedFiles,headRefOid
gh pr diff <PR_NUMBER> --repo <OWNER>/<REPO>
```

**Also fetch existing review comments** to avoid repeating what other reviewers have already flagged:

```bash
# Inline/line-level comments from previous reviewers
gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/comments --jq '.[] | {path, line, body, user: .user.login}'

# Review-level comments (summary comments from previous reviews)
gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/reviews --jq '.[] | {body, user: .user.login, state}'
```

Store these as `existing_inline_comments` and `existing_review_comments` for use in Steps 2 and 3.

**Important**: Store `headRefOid` - this is the commit SHA required for posting inline comments.

### Step 2: Agent Reviews

For each agent, launch in parallel using the `Task` tool with the agent's `subagent_type`. Agents should only use the `Bash` tool with `gh` CLI to access PR content — do not checkout or clone the branch.

**Prompt template for each agent:**
```
Review this PR for code quality issues within your area of expertise.

IMPORTANT: The PR branch is likely NOT checked out locally. Use `gh` CLI to fetch PR content:
- `gh pr diff <PR_NUMBER> --repo <OWNER>/<REPO>` - Full diff
- `gh api repos/<OWNER>/<REPO>/contents/<path>?ref=<branch>` - Fetch specific file contents

DO NOT use `git checkout` or `git clone` to access the PR branch.

PR: <pr_url>
Title: <pr_title>
Description: <pr_body>

Changes (diff):
<diff>

## EXISTING REVIEWER COMMENTS (DO NOT REPEAT THESE)

The following comments have already been left by other reviewers on this PR. Do NOT raise the same issues or make substantially similar suggestions. Focus only on NEW findings not already covered.

**Existing inline comments:**
<existing_inline_comments>

**Existing review comments:**
<existing_review_comments>

If you have nothing new to add beyond what's already been flagged, return an empty list for that category. Quality over quantity — only flag genuinely new issues.

---

Provide feedback in TWO categories:

## INLINE COMMENTS
For issues tied to a SPECIFIC LINE in the diff, provide:
- **File**: exact path from the diff (e.g., `src/services/auth.ts`)
- **Line**: line number in the NEW file (right side of diff, the + lines)
- **Type**: `blocking` or `non-blocking`
- **Comment**: 1-2 sentence suggestion (collaborative tone), MUST start with `blocking:` or `non-blocking:`

Example:
- **File**: `src/api/users.ts`
- **Line**: 45
- **Type**: blocking
- **Comment**: `blocking:` Consider adding null check here to handle edge case when user is not found.

## GENERAL FEEDBACK
For overall patterns, architecture, or issues NOT tied to a specific line:
- **Type**: `blocking` or `non-blocking` (MUST prefix your feedback with this)
- **Issue**: 1 sentence
- **Suggestion**: 1 sentence (collaborative tone)
Keep general feedback minimal. If a concern can be expressed as an inline comment, put it there instead.

Guidelines:
- Use collaborative tone ("Consider...", "One option...", "You might...", "Should...?", "Would it make sense to...?")
- For structural suggestions (ordering, missing steps, architecture), prefer questions over directives
- Be succinct (1-2 sentences max per item)
- Focus on genuine improvements, not nitpicks
- For inline comments, use the ACTUAL line number visible in the diff
- Only create inline comments when you can pinpoint the EXACT line
- **WET > DRY**: Do NOT flag duplication until the same pattern appears 3 or more times. Two instances of similar code is acceptable and often preferable to a premature abstraction. Only suggest extracting a helper, utility, or shared function when there are 3+ occurrences.
```

### Step 3: Synthesize Feedback

Combine all agent feedback into two distinct lists:

**Inline Comments** (for posting on specific lines):
- Group by file
- Keep unique file:line combinations (if multiple agents flag same line, merge into one comment)
- **Drop any comment that overlaps with an existing inline comment** on the same file/line or that raises the same concern as an existing comment on a nearby line
- Format: `{file: string, line: number, body: string}` — body MUST start with `blocking:` or `non-blocking:`

**General Feedback** (for the summary comment — ONLY cross-cutting concerns):
- De-duplicate overlapping concerns across agents
- **Drop any feedback that substantially overlaps with existing review comments** — if a previous reviewer already raised the same issue or suggestion (even in different words), omit it
- **Drop any feedback that is already covered by an inline comment** — if an issue has an inline comment, it MUST NOT appear as a spelled-out item in the summary. The summary uses counts to reference inline comments and only spells out concerns that span multiple locations, are architectural in nature, or cannot be pinpointed to a single line
- Sort: blocking items first, then non-blocking
- Format: `{type: "blocking" | "non-blocking", issue: string, suggestion: string}`

**If all findings overlap with existing comments**, skip posting entirely and inform the user that previous reviewers have already covered the relevant feedback.

### Step 3.5: Verify Line Numbers

Before presenting findings, verify that every inline comment targets a valid line in the diff using `review-tool.py`.

**Step 3.5a: Write sidecar JSON**

Use the `Bash` tool to write the synthesized inline comments to a temp sidecar file. The sidecar format:

```json
{
  "repo": "<REPO>",
  "pr": <PR_NUMBER>,
  "commit_id": "<headRefOid>",
  "comments": [
    {
      "id": "blocking-1",
      "type": "blocking",
      "title": "Short title",
      "path": "src/services/auth.ts",
      "line": 45,
      "side": "RIGHT",
      "body": "blocking: Consider adding null check here..."
    },
    {
      "id": "non-blocking-A",
      "type": "non-blocking",
      "title": "Short title",
      "path": "src/api/users.ts",
      "line": 123,
      "side": "RIGHT",
      "body": "non-blocking: This could be simplified..."
    }
  ]
}
```

ID convention: `blocking-1`, `blocking-2`, ... for blocking; `non-blocking-A`, `non-blocking-B`, ... for non-blocking.

Write to `/tmp/claude-review-sidecar-<REPO>-<PR_NUMBER>.json`.

**Step 3.5b: Run resolve-lines**

```bash
gh pr diff <PR_NUMBER> --repo <OWNER>/<REPO> | ~/.claude/scripts/review-tool.py resolve-lines --sidecar /tmp/claude-review-sidecar-<REPO>-<PR_NUMBER>.json
```

This verifies each inline comment's line number against the actual diff. If a line is off, the tool corrects it in-place using content matching (code snippets from the comment body matched against diff lines). Review the correction table output — if any comment shows `???` (file not in diff), drop that comment entirely.

**Step 3.5c: Read corrected sidecar**

Read the sidecar JSON back and use the corrected line numbers for Steps 4 and 5. If resolve-lines reported corrections, note which comments were adjusted.

### Step 4: Format Review Output

Use `AskUserQuestion` to present the formatted review and get approval BEFORE posting:

```markdown
## Summary Comment (keep this SHORT — 2-4 lines max)

<1-2 sentence overall assessment — e.g., "Solid approach, a couple of blocking items to address." or "Clean implementation, a few non-blocking suggestions.">

<Count of inline comments by type — e.g., "1 blocking + 2 non-blocking inline comments." Only include this line when inline comments exist.>

<ONLY if there are general/cross-cutting items that have NO corresponding inline comment, list them here. Otherwise, omit the Blocking/Non-blocking sections entirely.>

### Blocking (only cross-cutting items without an inline comment)
- `blocking:` <architectural or multi-location concern that can't be pinned to one line>

### Non-blocking (only cross-cutting items without an inline comment)
- `non-blocking:` <pattern-level observation that spans the PR>

See inline comments for details.

---

## Inline Comments (<N> total)

Each comment body MUST start with `blocking:` or `non-blocking:` prefix.

| File | Line | Comment (as posted) |
|------|------|---------------------|
| `src/auth.ts` | 45 | `blocking:` Consider adding error handling here |
| `src/api.ts` | 123 | `non-blocking:` This could be simplified using X |

---
**Action: Approve / Request Changes**
```

**Redundancy rule**: The summary MUST NOT repeat what inline comments already say. If every finding has an inline comment, the summary is just an overall assessment + counts. Only spell out items in the summary when they are cross-cutting concerns with no inline comment. The summary covers the "what" at a glance; inline comments cover the "where" and "why".

**No "Strengths" section**: Do not enumerate what the PR does well. If the code is good, the brevity of the review says that. Do not summarize what the PR does — the author knows.

**Always approve or request changes**: Never post a comment-only review. If there are blocking items, use `--request-changes`. If there are no blocking items (only non-blocking suggestions or no issues), use `--approve`.

If no issues are found, post a brief positive assessment (e.g., "Looks good, clean implementation.") with a clean approval.

### Step 5: Post Review (on user approval)

Use the `Bash` tool for each of the following:

**Step 5a: Get the commit SHA**
```bash
COMMIT_SHA=$(gh pr view <PR_NUMBER> --repo <OWNER>/<REPO> --json headRefOid --jq '.headRefOid')
```

**Step 5b: Post the summary as a review**

Use `--request-changes` if there are any blocking items, otherwise `--approve`:
```bash
# If blocking items exist:
gh pr review <PR_NUMBER> --repo <OWNER>/<REPO> --request-changes --body "<summary_comment>"

# If no blocking items (non-blocking only or no issues):
gh pr review <PR_NUMBER> --repo <OWNER>/<REPO> --approve --body "<summary_comment>"
```

**Step 5c: Post each inline comment individually**

Every inline comment body MUST start with `blocking:` or `non-blocking:` prefix per team CR standards.

```bash
# Example: posting a blocking inline comment
gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/comments \
  --method POST \
  -f body="blocking: <comment_body>" \
  -f commit_id="$COMMIT_SHA" \
  -f path="<file_path>" \
  -F line=<line_number> \
  -f side="RIGHT"

# Example: posting a non-blocking inline comment
gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/comments \
  --method POST \
  -f body="non-blocking: <comment_body>" \
  -f commit_id="$COMMIT_SHA" \
  -f path="<file_path>" \
  -F line=<line_number> \
  -f side="RIGHT"
```

**Important notes:**
- `commit_id` is required - use the `headRefOid` from Step 1
- `line` is the line number in the NEW file (for additions/changes)
- `side="RIGHT"` means the new version of the file (use `LEFT` for deletions)
- Post each inline comment separately (one API call per comment)
- Every comment body MUST be prefixed with `blocking:` or `non-blocking:`

### Step 6: Confirm Success

After posting, output:
- Link to the PR
- Count of inline comments posted
- Any errors encountered

## Example Usage

```
/review-pr https://github.com/myorg/myrepo/pull/456 sam-senior-engineer,alex-api-ddd-architect
/review-pr https://github.com/myorg/myrepo/pull/456 denise-design-expert,tessa-temporal-architect
```

## Tone Guidelines

**Be collaborative, not condescending.** Assume the author is a competent engineer who made deliberate choices. Feedback should open a dialogue, not lecture.

**Open with a brief overall assessment, skip the recap.** The author knows what their PR does — don't summarize it back to them. Open with a 1-2 sentence overall take (e.g., "Overall this looks solid. Just a few suggestions." or "Clean implementation, one thing to flag before merging."), then move into suggestions. Don't enumerate strengths — if the code is good, the brevity of the review says that.

- **Do**: Open with a concise overall statement that sets the tone
- **Don't**: Open with a "What's Done Well" section listing strengths, or a summary of what the PR is about

- **Do**: "Consider extracting this to a helper for reusability"
- **Don't**: "You should extract this" or "This needs to be extracted"

- **Do**: "One option would be to add error handling here"
- **Don't**: "Missing error handling" or "Add error handling"

- **Do**: "This could be simplified by using X"
- **Don't**: "This is too complex"

- **Do**: "I'm curious about the reasoning here—would X work for this case?"
- **Don't**: "This is wrong" or "You forgot to handle Y"

- **Do**: "Should the existence check come before the create step to fail fast?"
- **Don't**: "The existence check should come before the create step"

**Prefer questions over directives for structural suggestions.** When flagging ordering, missing steps, or architectural choices, frame the feedback as a question (e.g., "Should X happen before Y?", "Would it make sense to...?"). This acknowledges the author may have context you don't and invites discussion rather than prescribing a fix.

**Follow WET (Write Everything Twice) over DRY.** Do not suggest extracting shared helpers, utilities, or abstractions for code that only appears twice. Two similar blocks of code is fine — premature abstraction creates coupling that's harder to undo than duplication. Only flag duplication when the same pattern appears 3+ times.

- **Do**: (on 3rd occurrence) "This pattern appears in three places now — would a shared helper make sense?"
- **Don't**: (on 2nd occurrence) "Consider extracting this into a reusable utility"

## Troubleshooting

**Inline comment fails with "line not part of diff"**:
- The line number must be from the diff, not the original file
- Only lines that appear in the diff can have inline comments
- Use `side="RIGHT"` for added/modified lines, `side="LEFT"` for removed lines
- Re-run resolve-lines to verify: `gh pr diff <PR_NUMBER> --repo <OWNER>/<REPO> | ~/.claude/scripts/review-tool.py resolve-lines --sidecar <sidecar_path> --dry-run`

**No inline comments posted**:
- Verify agents provided specific file:line references
- Check that the file path matches exactly (case-sensitive)
- Ensure line numbers are within the diff range

**Need to fix posted comments with wrong line numbers**:
- Use the repost command to delete and re-post with corrected lines:
  ```bash
  # First, correct lines in the sidecar
  gh pr diff <PR_NUMBER> --repo <OWNER>/<REPO> | ~/.claude/scripts/review-tool.py resolve-lines --sidecar <sidecar_path>
  # Then repost (get review_id from the PR's review list)
  ~/.claude/scripts/review-tool.py repost --review-id <REVIEW_ID> --sidecar <sidecar_path> --select all --yes
  ```
