---
name: manage-enable
description: Enable agents, skills, or commands by removing the .disabled extension from their file
arguments:
  - name: items
    description: "Space or comma-separated list of names to enable (e.g. react-engineer, ts-engineer, ai-engineer)"
    required: true
---

# /manage:enable

Run `~/.claude/scripts/manage-toggle.sh enable $ARGUMENTS` and display its output verbatim.

The script handles parsing (comma/whitespace split, stripping .md/.md.disabled suffixes), resolution across agents/skills/commands, and per-item reporting.
