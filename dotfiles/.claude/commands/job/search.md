---
name: search
description: "Search job applications by keyword across all fields."
allowed-tools: Read(*)
argument-hint: <search term>
---

# Search Applications

Search all job application entries in `~/projects/job-hunt/applications.md` by keyword.

## Usage

`/job:search engineer`
`/job:search LinkedIn`

## Parameters

- `search term` (required): Keyword to search across all fields (company, role, notes, source, etc.)

## Process

1. Read `~/projects/job-hunt/applications.md`
2. Search all content (case-insensitive) for the term
3. For each matching entry, display the full `## ` section
4. Show the count of matching entries
5. If no results, say so
