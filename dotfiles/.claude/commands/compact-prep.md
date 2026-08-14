---
name: compact-prep
description: Generate ready-to-paste instructions for Claude Code's built-in /compact command, preserving task state and what's already been tried.
argument-hint: ""
---

# Compact Prep

Thin, self-contained command. No skill delegation, no external calls, no file writes — just reads back over the current conversation and prints instructions formatted for `/compact <instructions>`.

## When to use

Mid-task, before context pressure forces an auto-compact that might drop detail you still need. Not for after-the-fact recovery (the conversation has to still be live to read back over it).

## Process

Read back over the current conversation and produce the four sections below, in order. This is task-state only, not a narrative — skip general reasoning/color and keep every line actionable for continuing the task. Do this compression silently; do not print a draft, outline, or narrative pass before the final block — the ONLY text this command outputs is the single block described under Output.

1. **Task & goal** — one or two lines: what's being done and why, stated so a compacted session immediately knows what it's continuing.
2. **State so far** — key decisions already made (outcome only, not the deliberation), and files/systems touched so far.
3. **Tried and failed** — every approach, fix, or command that was attempted and did NOT work, with the reason it failed in one clause. This is the most important section to preserve exactly — its entire purpose is stopping a compacted session from re-attempting a dead end. If nothing has failed yet, state that plainly.
4. **Open threads** — unresolved questions, pending approvals, anything waiting on the user, and the concrete next step.

Keep every section grounded in what actually happened in this conversation — do not invent detail to fill a section. If a section is genuinely empty, state that plainly rather than omitting the header.

## Output

Output EXACTLY ONE block, and nothing before it: the four sections folded directly into a single `/compact` invocation, formatted as:

```
/compact Task: ... State so far: ... Tried and failed: ... Open threads: ...
```

Do not separately print the four sections as their own display first — the `/compact ...` line IS the four-section block; there is no other copy of this content to show. If the result risks being hard to read as one line, use line breaks inside the single fenced code block, but it must still be one fenced block total, not two.

Do not invoke `/compact` yourself. This command only produces the text — the user runs it (or edits it first).
