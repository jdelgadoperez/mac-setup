---
name: apply
description: "Add a new job application to the tracker."
allowed-tools: Read(*), Edit(*), Write(*), AskUserQuestion(*)
argument-hint: <company> | <role>
---

# Add Job Application

Add a new job application entry to `~/projects/job-hunt/applications.md`.

## Usage

`/job:apply Company Name | Role Title`
`/job:apply` (interactive — ask for details)

## Parameters

The argument format is `Company Name | Role Title`. If not provided, ask the user for:
1. **Company name** (required)
2. **Role title** (required)
3. **URL** (optional)
4. **Source** (optional — e.g., LinkedIn, Referral, Company site)
5. **Salary range** (optional)
6. **Recruiter** (optional)

## Process

1. Read the current `~/projects/job-hunt/applications.md`
2. Parse the argument or ask for missing required fields (company, role)
3. Use today's date (YYYY-MM-DD format) as the application date
4. Append a new entry at the end of the file using this exact format:

```markdown

## <Company> | <Role>
- **Status:** Applied
- **Date Applied:** <YYYY-MM-DD>
- **URL:** <url>
- **Source:** <source>
- **Salary Range:** <salary>
- **Recruiter:** <recruiter>
- **Notes:**
  - [<YYYY-MM-DD>] Applied
```

5. Omit optional fields that weren't provided (don't include empty lines)
6. Confirm the addition to the user
