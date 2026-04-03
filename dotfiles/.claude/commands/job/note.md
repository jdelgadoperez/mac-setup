---
name: note
description: "Add a timestamped note to a job application."
allowed-tools: Bash(jt *)
argument-hint: <company> <note text>
---

# Add Application Note

Add a timestamped note to an existing application using the `jt` CLI.

## Usage

`/job:note Acme Had a great phone screen with hiring manager`
`/job:note` (interactive — ask for company and note)

## Parameters

- `company`: First word(s) used to match the company (case-insensitive partial match)
- `note text`: The rest of the argument is the note content

## Process

1. If arguments are missing, ask the user for company and/or note text
2. Run `jt note <company> <note text>`
3. Display the output to the user
