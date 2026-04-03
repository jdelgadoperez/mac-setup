---
name: search
description: "Search job applications by keyword across all fields."
allowed-tools: Bash(jt *)
argument-hint: <search term>
---

# Search Applications

Search all job application entries using the `jt` CLI.

## Usage

`/job:search engineer`
`/job:search LinkedIn`

## Parameters

- `search term` (required): Keyword to search across all fields (company, role, notes, source, etc.)

## Process

1. Run `jt search <term>`
2. Display the output to the user
3. If no results, say so
