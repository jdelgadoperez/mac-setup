---
name: manage-disable
description: Disable agents, skills, or commands by appending .disabled to their file
arguments:
  - name: items
    description: "Space or comma-separated list of names to disable (e.g. react-engineer, ts-engineer, ai-engineer)"
    required: true
---

# /manage:disable

Run `~/.claude/scripts/manage-toggle.sh disable $ARGUMENTS` and display its output verbatim.

The script handles parsing (comma/whitespace split, stripping .md/.md.disabled suffixes), resolution across agents/skills/commands, and per-item reporting.
