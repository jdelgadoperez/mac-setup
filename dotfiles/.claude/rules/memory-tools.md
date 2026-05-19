## AI Memory Tools

Two complementary memory systems are available:

- **Memory Bank** (`memory-bank search`) — retrospective search over the full Claude Code conversation history. Use when you need to find something from a past session (prior decisions, earlier bug fixes, past approaches). Use the `memory-search` skill for semantic search or `memory-recall` for full session context retrieval.
- **ICM** (MCP tools) — structured forward-looking memory with knowledge graphs and temporal decay. ICM manages its own recall/store lifecycle via its MCP instructions. Prefer ICM for storing decisions, preferences, and patterns going forward.

**Division of labor:** "What did we discuss about X before?" → Memory Bank. "What do I know about X right now?" → ICM.

### Memory Bank — when to search explicitly

Auto-recall (UserPromptSubmit hook) handles passive context injection before each prompt. Reach for the `memory-search` or `memory-recall` skill explicitly when:

- The user references past work ("remember when we...", "we fixed this before", "what was that approach")
- Starting a significant task in a project with deep history — search for prior decisions and context before proposing anything
- Debugging a recurring issue — search for prior resolution attempts before diagnosing from scratch
- Auto-injected context seems incomplete or missing for the current task
