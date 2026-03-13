---
name: weekly-summary
description: "Generate a summary of a week's work using GitHub activity and the work log."
allowed-tools: Bash(*), Write(*)
argument-hint: <WEEK_START_DATE>
---

# Weekly Work Summary
Generate a weekly work summary by reviewing GitHub activity and the work log.

## Usage
/weekly-summary [week-start-date]

## Parameters
- `week-start-date` (optional): Monday of the week to summarize in YYYY-MM-DD format
  - If not specified, defaults to last Monday
  - Examples: `2025-01-06`, `2024-12-16`

## Examples
Summarize last week (auto-detect Monday)
`/weekly-summary`
Summarize a specific week
`/weekly-summary 2025-01-06`

## Process
### Step 1: Work Log
Read `~/work-log.md` for:
- Tasks completed this week (from "Done This Week" section)
- Context and notes captured during the week
- Blockers and challenges encountered

### Step 2: GitHub Activity
Using the GitHub CLI with the week start date:
- PRs I authored: `gh search prs --author=@me --created=">=YYYY-MM-DD" --created="<=YYYY-MM-DD+4days"`
- PRs I merged: `gh search prs --author=@me --merged-at=">=YYYY-MM-DD" --merged-at="<=YYYY-MM-DD+4days"`
- PRs I reviewed: `gh search prs --reviewed-by=@me --created=">=YYYY-MM-DD" --created="<=YYYY-MM-DD+4days"`

## Output Format
Create a markdown file `weekly-summary-YYYY-MM-DD.md` with:
- **Summary**: 2-3 sentence overview of the week
- **Completed**: Work finished this week with brief descriptions
- **In Progress**: What I'm actively working on
- **Pull Requests**: PRs opened, merged, and reviewed
- **Key Accomplishments**: Notable wins and progress
- **Next Week**: Carry-over items or upcoming focus areas

### Formatting Rules
- All PR references must be hyperlinked: `[repo#123](https://github.com/org/repo/pull/123)`

## Output Destination
Write the weekly summary file to `~/summaries/weekly/`

## Post-Summary Cleanup
After generating the weekly summary:
1. Move completed items from "Done This Week" in work-log.md to clear it for the next week
2. Ask if any "Active" items should be moved to "Backlog" or removed
