---
name: review-pr
description: Multi-agent PR review that synthesizes feedback into a summary comment plus inline comments.
arguments:
  - name: pr_url
    description: GitHub PR URL (e.g., https://github.com/org/repo/pull/123)
    required: true
  - name: agents
    description: Comma-separated agent types to use (default: senior-engineer)
    required: false
---

# Multi-Agent PR Review

Review a PR using multiple specialized agents, synthesize their feedback, and post:
1. A **summary review comment** with overall feedback
2. **Inline comments** attached to specific lines in the diff

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
- **Comment**: 1-2 sentence suggestion (collaborative tone)

Example:
- **File**: `src/api/users.ts`
- **Line**: 45
- **Comment**: Consider adding null check here to handle edge case when user is not found.

## GENERAL FEEDBACK
For overall patterns, architecture, or issues NOT tied to a specific line:
- **Priority**: high/medium/low
- **Issue**: 1 sentence
- **Suggestion**: 1 sentence (collaborative tone)

Guidelines:
- Use collaborative tone ("Consider...", "One option...", "You might...", "Should...?", "Would it make sense to...?")
- For structural suggestions (ordering, missing steps, architecture), prefer questions over directives
- Be succinct (1-2 sentences max per item)
- Focus on genuine improvements, not nitpicks
- For inline comments, use the ACTUAL line number visible in the diff
- Only create inline comments when you can pinpoint the EXACT line
```

### Step 3: Synthesize Feedback

Combine all agent feedback into two distinct lists:

**Inline Comments** (for posting on specific lines):
- Group by file
- Keep unique file:line combinations (if multiple agents flag same line, merge into one comment)
- **Drop any comment that overlaps with an existing inline comment** on the same file/line or that raises the same concern as an existing comment on a nearby line
- Format: `{file: string, line: number, body: string}`

**General Feedback** (for the summary comment):
- De-duplicate overlapping concerns across agents
- **Drop any feedback that substantially overlaps with existing review comments** — if a previous reviewer already raised the same issue or suggestion (even in different words), omit it
- Sort by priority: high > medium > low
- Format: `{priority: string, issue: string, suggestion: string}`

**If all findings overlap with existing comments**, skip posting entirely and inform the user that previous reviewers have already covered the relevant feedback.

### Step 4: Format Review Output

Use `AskUserQuestion` to present the formatted review and get approval BEFORE posting:

```markdown
## Summary Comment

### What's Done Well
- <specific strengths worth calling out>

### High Priority
- <issue and suggestion>

### Medium Priority
- <issue and suggestion>

### Low Priority
- <issue and suggestion>

---

## Inline Comments (<N> total)

| File | Line | Comment |
|------|------|---------|
| `src/auth.ts` | 45 | Consider adding error handling here |
| `src/api.ts` | 123 | This could be simplified using X |

---
**Ready to post?** (y/n)
```

If no issues are found, omit the priority sections and post only "What's Done Well" with a clean approval.

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

**Important notes:**
- `commit_id` is required - use the `headRefOid` from Step 1
- `line` is the line number in the NEW file (for additions/changes)
- `side="RIGHT"` means the new version of the file (use `LEFT` for deletions)
- Post each inline comment separately (one API call per comment)

### Step 6: Confirm Success

After posting, output:
- Link to the PR
- Count of inline comments posted
- Any errors encountered

## Example Usage

```
/review-pr https://github.com/org/repo/pull/456 senior-engineer,architect
/review-pr https://github.com/org/repo/pull/456 design-expert,architect
```

## Tone Guidelines

**Be collaborative, not condescending.** Assume the author is a competent engineer who made deliberate choices. Feedback should open a dialogue, not lecture.

**Lead with strengths, skip the recap.** The author knows what their PR does — don't summarize it back to them. Instead, start by highlighting what was done well (good patterns, clean abstractions, solid test coverage, etc.), then move into suggestions.

- **Do**: Start with "What's Done Well" before any change suggestions
- **Don't**: Open with a summary of what the PR is about

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

## Troubleshooting

**Inline comment fails with "line not part of diff"**:
- The line number must be from the diff, not the original file
- Only lines that appear in the diff can have inline comments
- Use `side="RIGHT"` for added/modified lines, `side="LEFT"` for removed lines

**No inline comments posted**:
- Verify agents provided specific file:line references
- Check that the file path matches exactly (case-sensitive)
- Ensure line numbers are within the diff range
