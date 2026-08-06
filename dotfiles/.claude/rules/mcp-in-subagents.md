# MCP Configuration in Subagents

## Key Rules

### Claude.ai connectors don't work in subagents
`mcp__claude_ai_*` tools (Notion, Slack, GitHub, etc.) are NOT accessible to custom subagents — they're session-only connectors.
**Fix**: Register at user scope: `claude mcp add --scope user --transport http <name> <url>`

### OAuth servers must be user-scoped
Inline `mcpServers` definitions for OAuth-required servers silently fail — zero tools appear, no error.
**Fix**: Pre-register at user scope, reference by name in frontmatter: `mcpServers: - notion`

### `tools` ≠ access
Listing `mcp__server__*` in `tools` does NOT grant access. The server must be in `mcpServers` or user-scoped.

### Scope table
| Scope | Subagent access? |
|-------|-----------------|
| User (`--scope user`) | Yes |
| Project (`.mcp.json`) | No |
| Claude.ai connector | No |

## Auth Handoff Pattern
When writing subagents that need OAuth MCP servers, include this in the agent's instructions:

```
If no mcp__<server>__* tools are available — stop and return:
"AUTH_REQUIRED: No <server> MCP tools available. Authenticate via /mcp, then re-invoke."
```

## Anti-Patterns
- Never use Bash (`claude mcp list`, `cat ~/.claude/settings.json`) to check MCP state inside a subagent — it sees the parent session, not its own scope
- Don't have both a connector and user-scoped server for the same service (duplicate prefixes cause confusion)
- Don't put MCP setup instructions in the agent .md — the agent only needs which tools to call and what to do when they fail

## Reference
Full guide: `<internal-doc>`
