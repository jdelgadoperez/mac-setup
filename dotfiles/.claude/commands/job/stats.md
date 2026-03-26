---
name: stats
description: "Show summary counts of job applications by status."
allowed-tools: Read(*)
---

# Application Stats

Show a summary of job applications by status from `~/projects/job-hunt/applications.md`.

## Usage

`/job:stats`

## Process

1. Read `~/projects/job-hunt/applications.md`
2. Count entries by status
3. Display a summary:

```
Application Stats
-----------------
Applied:      5
Screened:     2
Interviewed:  1
Offered:      0
Rejected:     1
Ghosted:      0
Withdrawn:    0
-----------------
Total:        9
```

4. Only show statuses that have at least one entry
5. If no entries, suggest using `/job:apply`
