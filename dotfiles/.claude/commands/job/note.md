---
name: note
description: "Add a timestamped note to a job application."
allowed-tools: Read(*), Edit(*)
argument-hint: <company> <note text>
---

# Add Application Note

Add a timestamped note to an existing application in `~/projects/job-hunt/applications.md`.

## Usage

`/job:note Acme Had a great phone screen with hiring manager`
`/job:note` (interactive — ask for company and note)

## Parameters

- `company`: First word(s) used to match the company (case-insensitive partial match)
- `note text`: The rest of the argument is the note content

## Process

1. Read `~/projects/job-hunt/applications.md`
2. Find the `## ` heading that matches the company name
3. If multiple matches, show them and ask the user to pick one
4. Find the `- **Notes:**` section within that entry
5. Append a new note line after the last existing note: `  - [YYYY-MM-DD] <note text>`
6. Confirm the note was added
