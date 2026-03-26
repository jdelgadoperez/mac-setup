---
name: status
description: "Update the status of a job application."
allowed-tools: Read(*), Edit(*)
argument-hint: <company> <new-status>
---

# Update Application Status

Update the status of an existing application in `~/projects/job-hunt/applications.md`.

## Usage

`/job:status Acme screened`
`/job:status` (interactive — ask for company and status)

## Parameters

- `company`: Partial company name to match (case-insensitive)
- `new-status`: One of: `applied`, `screened`, `interviewed`, `offered`, `rejected`, `ghosted`, `withdrawn`

## Process

1. Read `~/projects/job-hunt/applications.md`
2. Find the `## ` heading that matches the company name (case-insensitive partial match)
3. If multiple matches, show them and ask the user to pick one
4. If no matches, tell the user and suggest `/job:list`
5. Validate the new status against the allowed values
6. Update the `- **Status:**` line to the new status (capitalize first letter)
7. Add a timestamped note: `  - [YYYY-MM-DD] Status changed from <old> to <new>`
8. Show the user what changed
