---
name: context7
description: "Look up library documentation using Context7 MCP. Use when the user invokes /context7 or needs to fetch up-to-date docs and code examples for any library or framework."
---

# Context7 Documentation Lookup

Fetch up-to-date documentation and code examples for any library using the context7-docs agent.

## Input Format

The user provides a library name and an optional query:

/context7 <library> [query]

Examples:
- `/context7 nestjs dependency injection`
- `/context7 react useEffect cleanup`
- `/context7 temporal workflow versioning`
- `/context7 date-fns format`

## Workflow

Dispatch to the `context7-docs` agent via the Task tool. Pass the user's full input as the prompt.

Example:

```
Task(subagent_type="context7-docs", prompt="Look up documentation for <library>: <query>")
```

Do not call the Context7 MCP tools directly — the agent handles the full resolve → query workflow.
