# on-login — observable LaunchAgents

Each agent is one plist here that execs `run-agent <name> -- <cmd>` (never the
script directly), so every agent gets uniform observability via the `agents` CLI.

## Add an agent
1. Write the work script in `agents/<name>.sh` (make it executable).
2. Copy a plist here as `com.jdp.agent.<name>.plist`. Keep `__REPO__` placeholders —
   the installer substitutes the absolute repo path at install time.
3. `oneshot` (default) vs `daemon`: add `<key>KeepAlive</key><true/>` for daemons.
4. Optional health hook: `health/<name>.sh` (exit 0 = healthy).
5. Install: `dorothy agents install <name>`.

## Observe
- `agents ps` — all defined agents, last status / live state
- `agents logs [-f] <name>` — per-agent log
- `agents health <name>` / `agents stats <name>` / `agents restart <name>`
- `agents inspect <name>` — raw state + resolved paths

State lives in `~/.local/state/login-agents/<name>.{json,log}`.
