#!/usr/bin/env bash
# format-pr-table.sh — Format PR JSON into a consistent markdown table with links
#
# Usage:
#   # Basic mode — pipe gh search prs JSON directly
#   gh search prs --review-requested=USER --state=open \
#     --json repository,number,title,author,updatedAt | format-pr-table.sh
#
#   # Enriched mode — add status/action per row via enriched JSON
#   cat enriched.json | format-pr-table.sh --enriched
#
#   # Options
#   format-pr-table.sh [--watched] [--action ACTION] [--enriched] < input.json
#
# Options:
#   --watched    Prefix row numbers with W (for watched-author PRs)
#   --action     Set the Action column for ALL rows (basic mode only)
#   --enriched   Expect enriched JSON with per-row status/action/approvals fields
#
# Basic input fields (from gh search prs):
#   repository.name, repository.nameWithOwner, number, title, author.login, updatedAt
#
# Enriched input fields (all basic fields plus):
#   approvals (number), state (string), status (string), action (string)
#
# Column semantics (enriched mode):
#   State   — PR-level state: Ready | Draft | Merged | Closed
#   Status  — user's review status relative to the PR: New | Approved | Changes requested | Needs re-review
#   Action  — derived next-step: Review | Re-review | Waiting | Done
#
# Output: Markdown table with linked PRs

set -euo pipefail

PREFIX=""
ACTION=""
ENRICHED=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --watched) PREFIX="W"; shift ;;
        --action) ACTION="$2"; shift 2 ;;
        --enriched) ENRICHED=true; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

INPUT=$(cat)

if [[ -z "$INPUT" || "$INPUT" == "[]" ]]; then
    echo "(no PRs)"
    exit 0
fi

COUNT=$(echo "$INPUT" | jq 'length')

if [[ "$ENRICHED" == true ]]; then
    echo "| # | PR | Author | Title | State | Approvals | Status | Action |"
    echo "|---|-----|--------|-------|-------|-----------|--------|--------|"
else
    echo "| # | PR | Author | Title | Updated | Action |"
    echo "|---|-----|--------|-------|---------|--------|"
fi

for i in $(seq 0 $((COUNT - 1))); do
    ROW_NUM=$((i + 1))
    REPO=$(echo "$INPUT" | jq -r ".[$i].repository.name")
    OWNER_REPO=$(echo "$INPUT" | jq -r ".[$i].repository.nameWithOwner")
    NUMBER=$(echo "$INPUT" | jq -r ".[$i].number")
    TITLE=$(echo "$INPUT" | jq -r ".[$i].title")
    AUTHOR=$(echo "$INPUT" | jq -r ".[$i].author.login")

    if [[ ${#TITLE} -gt 80 ]]; then
        TITLE="${TITLE:0:77}..."
    fi
    # Replace literal | with full-width ｜ — markdown table layout safe; visually identical to readers.
    TITLE="${TITLE//|/｜}"

    LINK="[${REPO}#${NUMBER}](https://github.com/${OWNER_REPO}/pull/${NUMBER})"
    LABEL="${PREFIX}${ROW_NUM}"

    if [[ "$ENRICHED" == true ]]; then
        APPROVALS=$(echo "$INPUT" | jq -r ".[$i].approvals // 0")
        STATE=$(echo "$INPUT" | jq -r ".[$i].state // \"Ready\"")
        STATUS=$(echo "$INPUT" | jq -r ".[$i].status // \"\"")
        ROW_ACTION=$(echo "$INPUT" | jq -r ".[$i].action // \"\"")
        echo "| ${LABEL} | ${LINK} | ${AUTHOR} | ${TITLE} | ${STATE} | ${APPROVALS} | ${STATUS} | ${ROW_ACTION} |"
    else
        UPDATED=$(echo "$INPUT" | jq -r ".[$i].updatedAt" | cut -c1-10)
        echo "| ${LABEL} | ${LINK} | ${AUTHOR} | ${TITLE} | ${UPDATED} | ${ACTION} |"
    fi
done
