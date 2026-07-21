# Login-Agents Observability — Design Spec

**Date:** 2026-07-21
**Status:** Approved design; ready for implementation plan
**Repo:** `~/projects/mac-setup`

## Objective

Give macOS login automation (launchd LaunchAgents) the kind of observability you get
from Docker. The native `launchctl list` (label, PID, last exit code) is too thin. We
add a lightweight instrumentation layer + a Docker-style CLI so every login task has
uniform, inspectable run history, health, live logs, and resource use.

Two classes of task, both first-class:

- **One-shot login tasks** (launch apps, set audio I/O, restore window layout):
  observability = run history / last status — *did it run, when, did it succeed, what
  did it print.*
- **Long-running daemons** (a keepalive, a watcher): observability = uptime, health,
  live logs, resource use — the full `docker ps` experience.

## Approach (decided)

Lightweight wrapper + status-store + CLI over launchd. **No new runtime daemon** (pm2
was considered and rejected — another runtime, Node-centric, awkward for one-shots).
This mirrors Docker's own shape: a runtime that wraps the process, a state store, and a
client.

```
LaunchAgent plist  ──exec──▶  bin/run-agent <name> -- <cmd>     (instrumentation point)
   (on-login/)                        │
                                      ├─▶ ~/.local/state/login-agents/<name>.json  (last-run snapshot)
                                      └─▶ ~/.local/state/login-agents/<name>.log   (append-only history)

custom-zsh/login-agents.zsh  ──reads──▶ status JSONs + `launchctl print` + `log stream`
   (the `agents` CLI)                    └─▶ Docker-style views (ps / logs / health / stats / events)
```

### Docker → CLI mapping

| Docker            | Ours                                                                      |
|-------------------|---------------------------------------------------------------------------|
| `docker ps`       | status JSONs + `launchctl print` → table: name, state, last-run, exit, runs, kind |
| `docker logs -f`  | per-agent logfile via `tail -f`, or `log stream --predicate` (`events`)   |
| `HEALTHCHECK`     | optional per-agent `health` hook the CLI invokes on demand                |
| restart count     | launchd's "runs" counter (from `launchctl print`), surfaced               |
| `docker stats`    | `ps -o %cpu,%mem,etime -p <pid>` for running agents                       |
| `docker events`   | `log stream` on the launchd subsystem / process predicate                 |

## Locked decisions

- launchd + lightweight bash wrapper (no pm2 / no new daemon)
- **Plist is the source of truth.** Each agent = one plist that calls `run-agent`. No new config format.
- `bin/` is a new PATH directory holding standalone executables (the deferred `.my_bin` idea). launchd must exec a real file, not a zsh function.
- CLI lives as a zsh function in `custom-zsh/login-agents.zsh`, `caff` subcommand idiom.
- State + logs both under XDG: `~/.local/state/login-agents/` (fully pipeable; not surfaced in Console.app — CLI is the surface).
- Run history = **last-run snapshot** in JSON + **append-only rotated log**. No rolling history array in JSON.
- JSON **write** path is hand-rolled (`printf`, no `jq` dependency). CLI **read** path uses `jq` when present, bash-parse fallback.
- Label scheme: `com.jdp.agent.<name>` (extends the existing `com.jdp.*` convention, namespaced away from hand-rolled agents like `com.jdp.hub`).
- `agents ps` lists **all defined** agents (from `on-login/*.plist`), docker-`ps -a` style, so an exited one-shot still shows last status. `--running` filters to live.
- **Primary shipped example = app-launcher** (one-shot, no external deps beyond `open`). Audio-I/O kept as a documented recipe. A daemon example exercises the supervise path.

## Components

### 1. `bin/run-agent` — instrumentation wrapper

The hot path; dependency-free (bash + `date`). Every agent invocation goes through it.

**Contract:** `run-agent <name> -- <command> [args...]`

Per run:
1. Stamp start time (epoch ms + ISO 8601).
2. Ensure `~/.local/state/login-agents/` exists (idempotent).
3. Run the command, streaming stdout+stderr to the terminal/launchd **and** appended to
   `<name>.log` (`tee`), so live `log stream` and the persisted file agree.
4. Capture exit code + wall-clock duration.
5. Write `<name>.json` — the last-run snapshot:
   ```json
   {
     "name": "launch-apps",
     "status": "success",
     "exit_code": 0,
     "duration_ms": 812,
     "started_at": "2026-07-21T09:03:00Z",
     "finished_at": "2026-07-21T09:03:01Z"
   }
   ```
   `status` ∈ `success | failure`. No hardcoded values — derived from the real run.
6. Append a framed run block to `<name>.log`:
   ```
   ── 2026-07-21T09:03:00Z  run start ──
   <command output…>
   ── 2026-07-21T09:03:01Z  exit=0  812ms  success ──
   ```
7. **Exit with the child's real exit code** — transparent to launchd, keeping
   `launchctl`'s own accounting (last exit reason, runs counter) truthful.

**Log rotation:** if `<name>.log` exceeds a cap (default 1 MB), truncate keeping the
tail. No logrotate dependency.

**Non-TTY safe:** wrapper never assumes a terminal; file output is colorless.

### 2. `custom-zsh/login-agents.zsh` — the `agents` CLI

Subcommand CLI in the `caff` idiom: styled help via `styles.zsh`
(`BLUE`/`GREEN`/`RED`/`YELLOW`/`BOLD`/`NC`), TTY-aware coloring (colors only when
attached to a terminal, so `agents ps | grep FAIL` works). Read-only over state except
`restart`.

| Command | Docker analog | Implementation |
|---|---|---|
| `agents ps [--running]` | `docker ps` / `ps -a` | Table `NAME  STATE  LAST-RUN  EXIT  RUNS  KIND`. State/PID/runs from `launchctl print gui/$UID/<label>`; last-run/exit from `<name>.json`. `KIND` = oneshot/daemon (from `KeepAlive` in the plist). No arg → discover all via `on-login/*.plist`. |
| `agents logs <name>` | `docker logs` | `cat <name>.log` → stdout, pipeable. |
| `agents logs -f <name>` | `docker logs -f` | `tail -f <name>.log`. |
| `agents events <name>` | `docker events` | `log stream --predicate 'process == "<name>"'` (live feed, pipeable). |
| `agents health <name>` | `HEALTHCHECK` | Runs `on-login/health/<name>.sh` on demand if present; prints pass/fail + output. No hook → "no healthcheck defined". |
| `agents stats <name>` | `docker stats` | Running PID → `ps -o %cpu,%mem,etime -p <pid>`. Oneshot with no live PID → "not running (oneshot)". |
| `agents restart <name>` | `docker restart` | `launchctl kickstart -k gui/$UID/<label>`. |
| `agents inspect <name>` | `docker inspect` | Raw JSON + resolved plist path + health-hook path. |

**Name resolution:** `<name>` → label `com.jdp.agent.<name>` and
`~/.local/state/login-agents/<name>.{json,log}`.

**Read path:** `jq` when available, bash-parse fallback.

### 3. `on-login/` — agent definitions

```
on-login/
  com.jdp.agent.launch-apps.plist       # PRIMARY example — oneshot app-launcher
  com.jdp.agent.keepalive-demo.plist    # daemon example (supervise path)
  agents/
    launch-apps.sh                       # `open -ga` a user-edited app list
    keepalive-demo.sh                    # tiny long-running loop
  health/
    keepalive-demo.sh                    # example health hook
```

**Example plist** — execs `run-agent`, never the script directly. Paths absolute
(launchd has no `$HOME`/repo-relative resolution); templates use a `__REPO__`
placeholder the installer substitutes at symlink/bootstrap time so the repo stays
portable across machines.

```xml
<key>Label</key><string>com.jdp.agent.launch-apps</string>
<key>ProgramArguments</key>
<array>
  <string>__REPO__/bin/run-agent</string>
  <string>launch-apps</string>
  <string>--</string>
  <string>__REPO__/on-login/agents/launch-apps.sh</string>
</array>
<key>RunAtLoad</key><true/>
```

`launch-apps.sh` uses `open -ga "<App>"` for a small, user-editable list (`-g` = don't
steal focus). It is the login-time, observable version of the existing `ensure_service`
pattern. Ships safe on any machine (missing apps log a warning, non-fatal).

### 4. Install / uninstall — `dorothy agents` subcommand

Fits the existing dorothy dispatch; callable standalone.

- `dorothy agents install [name]` — substitute `__REPO__`, symlink `on-login/*.plist` →
  `~/Library/LaunchAgents/`, then `launchctl bootstrap gui/$UID <plist>`. Idempotent
  (repo `createdirsafely`-style guards).
- `dorothy agents uninstall [name]` — `launchctl bootout` + remove symlink. Leaves state
  files; `--purge` also wipes `~/.local/state/login-agents/<name>.*`.
- `dorothy agents list` — alias to `agents ps`.

### 5. Docs — `CLAUDE.md`

Document the new `bin/` PATH dir, `run-agent` contract, `agents` CLI commands, the
`on-login/` convention, and `dorothy agents` install/uninstall.

## Rejected alternative

**pm2 supervisor booted by launchd** — brings `pm2 ls/logs/monit` for free, but adds a
Node-centric runtime, is awkward for one-shots, and is less version-controllable /
off-aesthetic for this repo. The lightweight wrapper wins on no-new-daemon,
version-controllable, matches the repo idiom, and handles one-shots natively.

## Testing strategy

- **Wrapper:** unit-style bash tests — success/failure exit codes propagate; JSON snapshot
  fields correct and non-hardcoded; duration measured; log framing + rotation at the cap.
- **CLI:** `ps`/`logs`/`inspect` against fixture state files; TTY vs non-TTY (colorless)
  output; name→label→file resolution; graceful "no healthcheck" / "not running".
- **End-to-end:** install the `launch-apps` example via `dorothy agents install`, confirm
  the plist bootstraps, it runs at load, writes a snapshot, and `agents ps`/`logs` show it.
- **Portability:** `__REPO__` substitution yields absolute paths; uninstall cleanly boots
  out and removes the symlink.

## Success criteria

1. Every agent runs through `run-agent`; uniform snapshot + log produced.
2. `agents ps` shows oneshots (last status) and daemons (live state) in one table.
3. `agents logs`/`events`/`health`/`stats`/`restart`/`inspect` behave as mapped.
4. App-launcher example works end-to-end through a symlinked plist.
5. `dorothy agents install/uninstall` is idempotent and portable across machines.
6. `CLAUDE.md` documents all new behavior.

## Deliverables

1. This spec.
2. `bin/run-agent` + `custom-zsh/login-agents.zsh`.
3. App-launcher example agent wired end-to-end via a symlinked plist (+ daemon example).
4. `dorothy agents` install/uninstall path + `CLAUDE.md` docs.

## Deferred

- `.my_bin`-style `bin/` PATH dir is introduced here for `run-agent`; adopting it broadly
  for other standalone executables is a natural follow-on.
- Audio-I/O and window-layout one-shots as additional documented recipes.
