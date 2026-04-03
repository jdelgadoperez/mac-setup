---
name: view
description: "View full details of a specific job application by company name."
allowed-tools: Bash(jt *)
argument-hint: <company name>
---

# View Job Application

Display the full details of a specific job application using the `jt` CLI.

## Usage

`/job:view Solace`
`/job:view inspiren`
`/job:view` (interactive — ask for company name)

## Parameters

- `company name` (required): Full or partial company name to look up (case-insensitive match)

## Process

1. If no argument provided, ask the user which company to look up
2. Run `jt view <company>`
3. Display the output to the user
4. If no match, suggest using `/job:search <term>` to broaden the search
