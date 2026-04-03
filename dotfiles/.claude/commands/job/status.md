---
name: status
description: "Update the status of a job application."
allowed-tools: Bash(jt *)
argument-hint: <company> <new-status>
---

# Update Application Status

Update the status of an existing application using the `jt` CLI.

## Usage

`/job:status Acme screened`
`/job:status` (interactive — ask for company and status)

## Parameters

- `company`: Partial company name to match (case-insensitive)
- `new-status`: One of: `applied`, `screened`, `interviewed`, `offered`, `rejected`, `ghosted`, `withdrawn`

## Process

1. If arguments are missing, ask the user for company and/or status
2. Run `jt status <company> <new-status>`
3. Display the output to the user
