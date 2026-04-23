---
name: save-session
description: Ingest the current session transcript into memory-bank manually, without waiting for the session to end.
allowed-tools: Bash(memory-bank ingest claude-code)
---

# Save Session to Memory Bank

Manually ingest the current session transcript into memory-bank. Use this mid-session to save progress without waiting for the session to end.

## Steps

1. Run the ingest command against the Claude Code projects directory:

```bash
memory-bank ingest claude-code
```

2. Report the output — confirm the session was ingested and stats updated.

## Notes

- Normally memory-bank auto-ingests via its installed hooks (`memory-bank hooks install`). This command is for ad-hoc mid-session saves.
- To verify, run `memory-bank stats` and compare message count to a prior check.
