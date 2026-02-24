---
name: re-review-pr
description: Lighter follow-up PR review focused on verifying prior feedback, catching regressions, and final QA before merge.
arguments:
  - name: pr_url
    description: GitHub PR URL (e.g., https://github.com/org/repo/pull/123)
    required: true
  - name: agents
    description: Comma-separated agent types to use (default: senior-engineer)
    required: false
---

# Re-Review PR

A lighter follow-up pass for PRs that have already been through a full `/review-pr`. Use this after the author has addressed initial feedback and pushed new commits.

## Inputs

- **PR URL**: $ARGUMENTS.pr_url
- **Agents**: $ARGUMENTS.agents (if not provided, prompt user to select)

## Agents

The `agents` argument accepts any agent types available in your Claude Code configuration. Specify as a comma-separated list.

If no agents are specified:
1. Auto-discover available agents using the `Glob` tool to check:
   - `~/.claude/agents/*.md` (user-level)
   - `.claude/agents/*.md` (project-level)
2. If agents are discovered, use `AskUserQuestion` to present them and ask which should review.
3. If none discovered, use `AskUserQuestion` to ask the user to provide agent names or 'skip'.

## Scope

**Focus areas (in order of priority):**
1. **Prior feedback verification** — Were the issues from the previous review actually addressed? Flag anything that was missed or only partially fixed.
2. **Regressions** — Did the new changes introduce any bugs, break existing behavior, or undo something that was working?
3. **Final QA** — Edge cases, off-by-ones, naming consistency, missing null checks, typos in user-facing strings. The kind of thing that slips through on the last push before merge.

**NOT in scope:**
- Re-litigating architecture or design decisions already approved
- Raising new medium/low priority suggestions unrelated to the recent changes
- Nitpicks or style preferences

## Workflow

### Step 1: Fetch PR Context + Prior Review

Use the `Bash` tool to run these `gh` commands:

```bash
# PR metadata and head SHA
gh pr view <PR_NUMBER> --repo <OWNER>/<REPO> --json title,body,files,additions,deletions,changedFiles,headRefOid

# Current diff
gh pr diff <PR_NUMBER> --repo <OWNER>/<REPO>

# Previous review comments (summary reviews)
gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/reviews --jq '.[] | {user: .user.login, state: .state, body: .body}'

# Previous inline comments
gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/comments --jq '.[] | {user: .user.login, path: .path, line: .line, body: .body}'
```

**Important**: Store `headRefOid` for posting inline comments later.

### Step 2: Agent Reviews

For each agent, launch in parallel using the `Task` tool with the agent's `subagent_type`. Agents should only use the `Bash` tool with `gh` CLI to access PR content — do not checkout or clone the branch.

**Prompt template for each agent:**
```
This is a FOLLOW-UP review. The PR has already been through a full review round.
Your job is lighter and more focused — think final QA before merge.

IMPORTANT: The PR branch is likely NOT checked out locally. Use `gh` CLI to fetch PR content:
- `gh pr diff <PR_NUMBER> --repo <OWNER>/<REPO>` - Full diff
- `gh api repos/<OWNER>/<REPO>/contents/<path>?ref=<branch>` - Fetch specific file contents

DO NOT use `git checkout` or `git clone` to access the PR branch.

PR: <pr_url>
Title: <pr_title>

Current diff:
<diff>

Previous review comments:
<previous_comments>

Your review should ONLY cover:

## 1. PRIOR FEEDBACK CHECK
For each previous review comment, verify whether it was addressed.
- If addressed: note it briefly
- If missed or partially addressed: flag it clearly

## 2. REGRESSIONS
Did the new changes break anything or undo prior work? Only flag actual problems.
Do NOT re-raise issues that are already called out in the previous review comments above.

## 3. FINAL QA
Look for last-mile issues ONLY in the changed code:
- Edge cases, off-by-ones, boundary conditions
- Null/undefined risks
- Naming inconsistencies within the PR
- Typos in user-facing strings or log messages
- Missing or incorrect types

**Skip any issue already raised in the previous review comments** — even if it hasn't been resolved yet. Those belong in the Prior Feedback Check section, not here.

For any issues tied to a SPECIFIC LINE, provide:
- **File**: exact path from the diff
- **Line**: line number in the NEW file (right side of diff, the + lines)
- **Comment**: 1-2 sentence suggestion

DO NOT:
- Re-litigate architecture or design decisions from the first review
- Raise new medium/low suggestions unrelated to recent changes
- Nitpick style preferences
- Summarize what the PR does
```

### Step 3: Synthesize Feedback

Combine all agent feedback into two lists:

**Inline Comments**: Group by file, merge duplicates on the same line. **Drop any comment that overlaps with an existing inline comment** on the same file/line or that raises the same concern already present in the prior review comments.

**General Feedback**: Organize into the three focus areas (prior feedback, regressions, final QA). **Drop any regression or QA finding that substantially overlaps with an existing review comment** — if a previous reviewer already flagged it (even in different words), omit it from those sections. It should only appear under Prior Feedback Check if it wasn't addressed.

**If all findings overlap with existing comments** (and all prior feedback was addressed), skip posting and inform the user that previous reviewers have already covered the relevant feedback.

### Step 4: Format Review Output

Use `AskUserQuestion` to present the formatted review and get approval BEFORE posting:

```markdown
## Re-Review Summary

### Prior Feedback
- [Addressed] <brief note on what was fixed>
- [Missed] <what wasn't addressed and needs attention>

### Regressions
- <any issues introduced by the new changes, or "None found">

### Final QA
- <edge cases, naming, typos, or other last-mile issues>

---

## Inline Comments (<N> total)

| File | Line | Comment |
|------|------|---------|
| `src/auth.ts` | 45 | This was flagged in the prior review but looks unchanged |

---
**Ready to post?** (y/n)
```

If all prior feedback was addressed and no regressions or QA issues found, post a clean approval: "All prior feedback addressed, no new issues. Good to merge."

### Step 5: Post Review (on user approval)

Use the `Bash` tool for each of the following:

**Step 5a: Get the commit SHA**
```bash
COMMIT_SHA=$(gh pr view <PR_NUMBER> --repo <OWNER>/<REPO> --json headRefOid --jq '.headRefOid')
```

**Step 5b: Post the summary as a review comment**
```bash
gh pr review <PR_NUMBER> --repo <OWNER>/<REPO> --comment --body "<summary_comment>"
```

**Step 5c: Post each inline comment individually**
```bash
gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/comments \
  --method POST \
  -f body="<comment_body>" \
  -f commit_id="$COMMIT_SHA" \
  -f path="<file_path>" \
  -F line=<line_number> \
  -f side="RIGHT"
```

### Step 6: Confirm Success

After posting, output:
- Link to the PR
- Count of inline comments posted
- Any errors encountered

## Example Usage

```
/re-review-pr https://github.com/org/repo/pull/456 senior-engineer
/re-review-pr https://github.com/org/repo/pull/456 senior-engineer,typescript-engineer
```

## Tone Guidelines

**Be collaborative, not condescending.** Assume the author is a competent engineer who addressed your feedback thoughtfully. If something wasn't fixed, it may have been a deliberate choice — ask rather than assume.

**Skip the recap.** The author knows what the PR does and what the prior review said. Get straight to the point.

- **Do**: "Looks like the null check from the earlier review might still be missing here"
- **Don't**: "In my previous review I mentioned that..."

- **Do**: "This edge case might be worth covering before merge"
- **Don't**: Re-raise architectural concerns that were already resolved

## Troubleshooting

**Inline comment fails with "line not part of diff"**:
- The line number must be from the diff, not the original file
- Only lines that appear in the diff can have inline comments
- Use `side="RIGHT"` for added/modified lines, `side="LEFT"` for removed lines

**No inline comments posted**:
- Verify agents provided specific file:line references
- Check that the file path matches exactly (case-sensitive)
- Ensure line numbers are within the diff range
