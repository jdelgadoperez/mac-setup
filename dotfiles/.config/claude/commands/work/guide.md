---
name: guide
description: "Tool selection guide — maps task size to the right workflow. Use when starting a work item or unsure which tools to use."
---

# Workflow Guide — Tool Selection by Task Size

## Decision Rule

```
Single commit or two?               → Small  (Superpowers only)
Need a plan I'd write down?         → Medium (Superpowers write-plan)
Has phases or milestones?            → Large  (GSD)
```

## Small (1–3 points, clear scope)

**Brainstorm → implement → PR**

```
# Superpowers brainstorming auto-fires
# Write code — TDD skill fires for tests, debugging skill if stuck
# Superpowers verification auto-fires before commit
/review:pr                           # Self-review
```

Skip: GSD, write-plan. Scope is already clear.

## Medium (3–5 points, some ambiguity)

**Brainstorm → write plan → execute → PR**

```
# Superpowers brainstorming auto-fires — explores design space
# Enter plan mode — Superpowers write-plan auto-fires
# Superpowers executing-plans guides through with review checkpoints
/review:pr                           # Self-review
```

## Large (8+ points, multi-phase)

**GSD project → plan phases → execute → milestone**

```
/gsd:new-project                     # Deep questioning → research → requirements → roadmap
/gsd:map-codebase                    # For existing repos — creates .planning/codebase/ docs
/gsd:discuss-phase N                 # Articulate vision before planning
/gsd:plan-phase N                    # Detailed execution plan
/gsd:execute-phase N                 # Wave-based execution (Superpowers fires inside)
/gsd:progress                        # Check status, route to next action
/gsd:pause-work                      # Context handoff between sessions
/gsd:resume-work                     # Restore context next session
/gsd:complete-milestone X.Y.Z        # Archive and tag
```

Quick ad-hoc with GSD tracking: `/gsd:quick`

## Always-On (every task, every size)

| Tool | Trigger |
|------|---------|
| Work log | `/work:log` |
| Daily/Weekly | `/work:daily-summary`, `/work:weekly-summary` |

## When NOT to Use

| Tool | Skip when... |
|------|-------------|
| GSD | Scope is clear, no phases needed |
| write-plan | You know exactly what to change |
| /gsd:research-phase | Domain you already know well |
