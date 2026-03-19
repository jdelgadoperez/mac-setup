---
name: review-prs
description: Batch review open PRs requesting your review. Fetches, displays, and dispatches parallel reviews with optional inline comment posting.
arguments:
  - name: flags
    description: Optional flags (--all to include PRs with 2+ approvals)
    required: false
---

# /review-prs

Review open PRs where you are a requested reviewer.

## Usage

/review:prs          # standard mode (excludes PRs with 2+ approvals from "all")
/review:prs --all    # includes PRs with 2+ approvals in "all" selection

## Execution

1. Check whether `--all` was passed as an argument. Hold this as a boolean: `all_flag = true` if `--all` was present, `all_flag = false` otherwise.

2. Use the `Skill` tool to invoke `review:prs` — the skill contains the full orchestration workflow. Pass `all_flag` context when following its instructions.
