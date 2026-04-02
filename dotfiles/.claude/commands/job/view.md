---
name: view
description: "View full details of a specific job application by company name."
allowed-tools: Read(*), AskUserQuestion(*)
argument-hint: <company name>
---

# View Job Application

Display the full details of a specific job application from `~/projects/job-hunt/applications.md`.

## Usage

`/job:view Solace`
`/job:view inspiren`
`/job:view` (interactive — ask for company name)

## Parameters

- `company name` (required): Full or partial company name to look up (case-insensitive match)

## Process

1. Read `~/projects/job-hunt/applications.md`
2. If no argument provided, ask the user which company to look up
3. Search all `## ` entries for a case-insensitive match on the company name (the portion before the `|` delimiter)
4. **If exactly one match:** Display the full `## ` section with all fields and notes, formatted clearly
5. **If multiple matches:** List the matching entries as a numbered list (`Company | Role`) and ask the user to pick one, then display that entry
6. **If no matches:** Say no application was found and suggest using `/job:search <term>` to broaden the search
