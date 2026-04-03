---
name: apply
description: "Add a new job application to the tracker."
allowed-tools: Bash(jt *), AskUserQuestion(*)
argument-hint: <company> | <role>
---

# Add Job Application

Add a new job application using the `jt` CLI.

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

1. Parse the argument or ask for missing required fields (company, role)
2. Build the `jt add` command with all provided fields:
   ```
   jt add --company "Company" --role "Role" --url "url" --source "source" --salary-range "range" --recruiter "name"
   ```
3. Omit flags for optional fields that weren't provided
4. Run the command and confirm the addition to the user
