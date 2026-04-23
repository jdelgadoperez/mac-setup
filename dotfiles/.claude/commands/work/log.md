---
name: log
description: "View and update the work log. Tracks active tasks, blockers, backlog, and weekly completions."
allowed-tools: Read(*), Write(*), AskUserQuestion(*)
---

# Work Log

View and update the work log at `~/work-log.md`.

## Usage

`/work:log` - View current work log
`/work:log update` - Update the work log based on current session progress

## Actions

### View (default)
Display the current work log contents.

### Update
When updating, the agent should:
1. Read the current work-log.md
2. Ask what changed during this session:
   - Tasks completed? Move to "Done This Week" with date
   - New tasks started? Add to "Active"
   - Blockers encountered? Add to "Blocked" or as notes
   - Context to capture? Add as dated notes under tasks
3. Make the updates
4. Show the diff

## Work Log Location
`~/work-log.md`

## Structure
```markdown
# Work Log

## Active
- [ ] Task name
  - PR: [repo#number](url)
  - Status: In Progress / Code Review
  - 2/10: Context note about where we left off

## Blocked
- [ ] Task waiting on something

## Backlog
- [ ] Future task

## Done This Week
- [x] Completed task (merged 2/10)
  - Learning: Any lessons learned

## Notes
- 2/10: General notes not tied to specific tasks
```
