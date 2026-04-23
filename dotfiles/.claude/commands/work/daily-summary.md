---
name: daily-summary
description: "Generate a summary of a single day's work using GitHub activity and the work log."
allowed-tools: Bash(*), Write(*)
argument-hint: <DATE>
---

# Daily Work Summary
Generate a daily work summary by reviewing GitHub activity and the work log for a single day.

## Usage
/daily-summary [date]

## Parameters
- `date` (optional): The date to summarize in YYYY-MM-DD format
  - If not specified, defaults to today
  - Examples: `2025-01-06`, `2024-12-16`

## Examples
Summarize today's work
`/daily-summary`
Summarize a specific day
`/daily-summary 2025-01-06`

## Process
### Step 1: Work Log
Read `~/work-log.md` for:
- Active tasks and their current status
- Any notes or context captured for the target date
- Blockers encountered
This provides context for what was being worked on.

### Step 2: GitHub Activity
Using the GitHub CLI with the target date:
- PRs I authored: `gh search prs --author=@me --created="YYYY-MM-DD"`
- PRs I merged: `gh search prs --author=@me --merged-at="YYYY-MM-DD"`
- PRs I reviewed: `gh search prs --reviewed-by=@me --updated="YYYY-MM-DD"`
- Commits I pushed: `gh search commits --author=@me --committer-date="YYYY-MM-DD"`

## Output Format
Create a markdown file `daily-summary-YYYY-MM-DD.md` with:
- **Summary**: 1-2 sentence overview of the day
- **Pull Requests**: PRs opened, merged, reviewed, or updated
- **Key Activity**: Bullet points of notable work (decisions, debugging sessions, research, reviews)
- **Blockers**: Anything that slowed progress (omit section if none)
- **Carry Forward**: Items to pick up tomorrow (omit section if nothing notable)

### Formatting Rules
- All PR references must be hyperlinked: `[repo#123](https://github.com/org/repo/pull/123)`
- Keep it concise — this is a daily snapshot, not a weekly report

## Output Destination
Write the daily summary file to `~/summaries/daily/`
