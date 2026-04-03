---
name: list
description: "List all job applications, optionally filtered by status."
allowed-tools: Bash(jt *)
argument-hint: "[status]"
---

# List Job Applications

Display job applications using the `jt` CLI.

## Usage

`/job:list` — show all applications
`/job:list applied` — filter by status

## Parameters

- `status` (optional): Filter to a specific status. Valid values: `applied`, `screened`, `interviewed`, `offered`, `rejected`, `ghosted`, `withdrawn`

## Process

1. If a status filter is provided, run `jt list <status>`
2. Otherwise, run `jt list`
3. Display the output to the user
4. If no entries found, suggest using `/job:apply`
