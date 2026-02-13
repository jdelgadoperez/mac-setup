---
name: context7
description: "Look up library documentation using Context7 MCP. Use when the user invokes /context7 or needs to fetch up-to-date docs and code examples for any library or framework."
---

# Context7 Documentation Lookup

Fetch up-to-date documentation and code examples for any library using the Context7 MCP tools.

## Input Format

The user provides a library name and an optional query:

/context7 <library> [query]

Examples:
- `/context7 nestjs dependency injection`
- `/context7 react useEffect cleanup`
- `/context7 temporal workflow versioning`
- `/context7 date-fns format`

If only a library name is provided, use the surrounding conversation context to infer a relevant query.

## Workflow

### Step 1: Parse the input

The first word or recognizable library/framework name is the `libraryName`. Everything after it is the `query`. If the boundary is ambiguous, use the full input as both.

### Step 2: Resolve the library ID

Call `mcp__context7__resolve-library-id` with:
- `libraryName`: The parsed library name
- `query`: The user's full input

If no results are returned, tell the user the library was not found and suggest checking spelling or trying an alternative name (e.g., "nextjs" vs "next.js").

Use the top match. Briefly note the selected library so the user can verify.

### Step 3: Query the documentation

Call `mcp__context7__query-docs` with:
- `libraryId`: The resolved ID from Step 2
- `query`: The query portion of the input

### Step 4: Present the results

Share the documentation and code examples directly. Do not over-summarize — the user wants the actual docs and code.

## Rules

- Always run both steps in sequence. Do not skip the resolve step.
- Do not ask for clarification unless the resolve step returns zero results. Pick the best match and proceed.
- Keep it fast — this should feel like a single command, not a multi-turn conversation.
