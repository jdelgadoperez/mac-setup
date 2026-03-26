---
name: list
description: "List all job applications, optionally filtered by status."
allowed-tools: Read(*)
argument-hint: "[status]"
---

# List Job Applications

Display job applications from `~/projects/job-hunt/applications.md`.

## Usage

`/job:list` — show all applications
`/job:list applied` — filter by status

## Parameters

- `status` (optional): Filter to a specific status. Valid values: `applied`, `screened`, `interviewed`, `offered`, `rejected`, `ghosted`, `withdrawn`

## Process

1. Read `~/projects/job-hunt/applications.md`
2. Parse all `## ` entries extracting: company, role, status, date applied
3. If a status filter is provided, only include matching entries
4. Display as a formatted markdown table:

```
| Company | Role | Status | Date Applied |
|---------|------|--------|--------------|
| Acme Corp | Senior Engineer | Applied | 2026-03-25 |
```

5. Show total count at the bottom
6. If no entries found, suggest using `/job:apply`
