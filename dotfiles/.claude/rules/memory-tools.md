## AI Memory Tools

**Memory Bank** (`memory-bank search`) is the memory system. It is retrospective
search over the full Claude Code conversation history — prior decisions, earlier
bug fixes, past approaches. Use the `memory-search` skill for semantic search or
`memory-recall` for full session context retrieval.

Ingestion is automatic via hooks (SessionStart, UserPromptSubmit, PreCompact,
Stop). Those hooks are write-only — they log to `~/.memory-bank/ingest.log` and
inject nothing into the prompt — so recall is always an explicit action you or I
take, never something that arrives on its own.

### When to search explicitly

- The user references past work ("remember when we...", "we fixed this before",
  "what was that approach")
- Starting a significant task in a project with deep history — search for prior
  decisions and context before proposing anything
- Debugging a recurring issue — search for prior resolution attempts before
  diagnosing from scratch
