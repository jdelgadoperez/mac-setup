---
name: prep
description: "Create or open an interview prep workspace for a company."
allowed-tools: Read(*), Write(*), Bash(*), AskUserQuestion(*)
argument-hint: <company>
---

# Interview Prep

Create or open an interview prep workspace for a specific company under `~/projects/job-hunt/`.

## Usage

`/job:prep Acme`

## Parameters

- `company` (required): Company name to create/find prep workspace for

## Process

1. Read `~/projects/job-hunt/applications.md` to find the matching application entry
2. Derive a directory name from the company: lowercase, hyphenated (e.g., "Acme Corp" -> `acme-corp-prep`)
3. Check if `~/projects/job-hunt/<company>-prep/` already exists

### If the directory exists:
- Read its contents and summarize what's there
- Ask the user what they'd like to work on

### If the directory doesn't exist:
- Create `~/projects/job-hunt/<company>-prep/`
- Ask the user about the interview format (rounds, topics, timeline)
- Create a starter `CLAUDE.md` in the prep directory with:
  - Company name and role from the application entry
  - Interview schedule (if provided)
  - Links to the job posting
- Create a `prep.md` with sections for:
  - Company research
  - Role-specific preparation
  - Questions to ask
  - Technical prep areas (if applicable)
