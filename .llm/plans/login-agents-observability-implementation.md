# Login-Agents Observability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give macOS launchd LaunchAgents Docker-style observability via a `run-agent` instrumentation wrapper, an XDG status store, and an `agents` CLI.

**Architecture:** A dependency-free bash wrapper (`bin/run-agent`) wraps every login task, stamping timing and writing a last-run JSON snapshot + append-only log to `~/.local/state/login-agents/`. A `caff`-idiom zsh CLI (`custom-zsh/login-agents.zsh`) reads those files plus `launchctl print`/`log stream` to render Docker-style views. Plists in `on-login/` are the source of truth and exec the wrapper; `dorothy agents` installs them via symlink + `launchctl bootstrap`.

**Tech Stack:** Bash, zsh, launchd/launchctl, macOS `log` tool, `open(1)`. `jq` optional (read path only).

## Global Constraints

- Target platform: macOS only. Per-user LaunchAgents in `gui/$UID` (never LaunchDaemons).
- No new runtime daemon (pm2 rejected). Wrapper is bash + `date` only.
- Strong "typing": fixed JSON schema; no hardcoded values in tests' expectations — assert against computed inputs.
- JSON **write** path hand-rolled with `printf` (no `jq` to write). CLI **read** path uses `jq` if present, bash-parse fallback.
- State + logs both under `~/.local/state/login-agents/<name>.{json,log}`.
- Run history = last-run snapshot in JSON + append-only rotated log (rotate at 1 MB, keep tail). No history array in JSON.
- Label scheme: `com.jdp.agent.<name>`.
- `agents ps` lists **all defined** agents (from `on-login/*.plist`); `--running` filters to live.
- Plists use `__REPO__` placeholder; installer substitutes the absolute repo path.
- Styled output uses `styles.zsh` vars (`BLUE GREEN RED YELLOW BOLD NC`), TTY-aware (colors only when stdout is a terminal).
- Wrapper exits with the child's real exit code (transparent to launchd).
- Follow repo idioms: `case`-dispatch subcommand CLI (like `caff`), `.test.sh` harness with `pass/fail` counter (no bats), `createdirsafely` from `shared.sh`.

**Repo facts (verified):**
- dorothy dispatches in `main()` via `case $command in ... esac` calling `cmd_<name>` functions; add `agents) cmd_agents "${args[@]}" ;;`.
- dorothy sources `shared.sh` which defines `createdirsafely`, color vars, log fns (`loginfo logsuccess logerror`).
- Test idiom: `dotfiles/.claude/hooks/pre-push-checks/scripts/staff-eng-preflight-gate.test.sh` — self-contained bash, `check expected label cmd`, ends `[ "$fail" -eq 0 ]`.

---

## File Structure

- Create `bin/run-agent` — wrapper executable.
- Create `bin/tests/run-agent.test.sh` — wrapper tests.
- Create `custom-zsh/login-agents.zsh` — `agents` CLI.
- Create `custom-zsh/tests/login-agents.test.sh` — CLI tests.
- Create `on-login/com.jdp.agent.launch-apps.plist` — primary oneshot example (templated).
- Create `on-login/agents/launch-apps.sh` — app-launcher script.
- Create `on-login/com.jdp.agent.keepalive-demo.plist` — daemon example (templated).
- Create `on-login/agents/keepalive-demo.sh` — daemon loop.
- Create `on-login/health/keepalive-demo.sh` — health hook example.
- Create `on-login/README.md` — how to add an agent.
- Modify `dorothy` — add `cmd_agents` + dispatch + help entry.
- Modify `CLAUDE.md` — document new behavior.

---

## Task 1: `run-agent` wrapper — core run + snapshot

**Files:**
- Create: `bin/run-agent`
- Test: `bin/tests/run-agent.test.sh`

**Interfaces:**
- Consumes: nothing (leaf).
- Produces: executable `run-agent <name> -- <cmd...>`. Writes `$STATE_DIR/<name>.json` with keys `name,status,exit_code,duration_ms,started_at,finished_at`. Appends framed blocks to `$STATE_DIR/<name>.log`. Exits with child's exit code. `STATE_DIR` defaults to `${XDG_STATE_HOME:-$HOME/.local/state}/login-agents`, overridable via `LOGIN_AGENTS_STATE_DIR` (test seam).

- [ ] **Step 1: Write the failing test**

Create `bin/tests/run-agent.test.sh`:

```bash
#!/usr/bin/env bash
# Tests for bin/run-agent. Uses LOGIN_AGENTS_STATE_DIR to sandbox state.
set -uo pipefail

WRAP="$(cd "$(dirname "$0")/.." && pwd)/run-agent"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export LOGIN_AGENTS_STATE_DIR="$TMP/state"

pass=0; fail=0
check() { # label, condition-already-evaluated ("0" ok)
  if [ "$2" = "0" ]; then echo "PASS  $1"; pass=$((pass+1))
  else echo "FAIL  $1"; fail=$((fail+1)); fi
}
json() { # file, key -> value (bash parse, no jq dependency in tests)
  grep -o "\"$2\"[[:space:]]*:[[:space:]]*\"\{0,1\}[^\",}]*" "$1" \
    | sed 's/.*:[[:space:]]*"\{0,1\}//'
}

echo "=== run-agent tests ==="

# success case
"$WRAP" ok-agent -- /bin/sh -c 'echo hello; exit 0' >/dev/null 2>&1
rc=$?
check "success: exit code propagates (0)" "$([ "$rc" -eq 0 ] && echo 0 || echo 1)"
J="$LOGIN_AGENTS_STATE_DIR/ok-agent.json"
check "success: json created" "$([ -f "$J" ] && echo 0 || echo 1)"
check "success: name field" "$([ "$(json "$J" name)" = "ok-agent" ] && echo 0 || echo 1)"
check "success: status=success" "$([ "$(json "$J" status)" = "success" ] && echo 0 || echo 1)"
check "success: exit_code=0" "$([ "$(json "$J" exit_code)" = "0" ] && echo 0 || echo 1)"
check "success: log has output" "$(grep -q hello "$LOGIN_AGENTS_STATE_DIR/ok-agent.log" && echo 0 || echo 1)"

# failure case — real child code, not hardcoded
"$WRAP" bad-agent -- /bin/sh -c 'exit 7' >/dev/null 2>&1
rc=$?
check "failure: exit code propagates (7)" "$([ "$rc" -eq 7 ] && echo 0 || echo 1)"
JB="$LOGIN_AGENTS_STATE_DIR/bad-agent.json"
check "failure: exit_code matches child" "$([ "$(json "$JB" exit_code)" = "$rc" ] && echo 0 || echo 1)"
check "failure: status=failure" "$([ "$(json "$JB" status)" = "failure" ] && echo 0 || echo 1)"

echo "==============================="
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash bin/tests/run-agent.test.sh`
Expected: FAIL — `run-agent` does not exist / not executable.

- [ ] **Step 3: Write minimal implementation**

Create `bin/run-agent`:

```bash
#!/usr/bin/env bash
# run-agent <name> -- <command> [args...]
# Instrumentation wrapper: stamps timing, captures exit + duration, writes a
# last-run JSON snapshot and appends a framed block to a per-agent log, then
# exits with the child's real exit code (transparent to launchd).
set -uo pipefail

STATE_DIR="${LOGIN_AGENTS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/login-agents}"
LOG_MAX_BYTES="${LOGIN_AGENTS_LOG_MAX_BYTES:-1048576}"

name="${1:-}"
if [ -z "$name" ] || [ "${2:-}" != "--" ]; then
  echo "usage: run-agent <name> -- <command> [args...]" >&2
  exit 64
fi
shift 2  # drop name and --

mkdir -p "$STATE_DIR"
json_file="$STATE_DIR/$name.json"
log_file="$STATE_DIR/$name.log"

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }
now_ms()  { echo $(( $(date +%s) * 1000 )); }

started_at="$(now_iso)"
start_ms="$(now_ms)"

printf '\xe2\x94\x80\xe2\x94\x80 %s  run start \xe2\x94\x80\xe2\x94\x80\n' "$started_at" >> "$log_file"

# Run child; tee combined output to terminal/launchd and the log.
"$@" 2>&1 | tee -a "$log_file"
exit_code="${PIPESTATUS[0]}"

finished_at="$(now_iso)"
duration_ms=$(( $(now_ms) - start_ms ))
status="success"; [ "$exit_code" -eq 0 ] || status="failure"

printf '\xe2\x94\x80\xe2\x94\x80 %s  exit=%s  %sms  %s \xe2\x94\x80\xe2\x94\x80\n' \
  "$finished_at" "$exit_code" "$duration_ms" "$status" >> "$log_file"

# Rotate: if log exceeds cap, keep the tail.
if [ -f "$log_file" ]; then
  bytes=$(wc -c < "$log_file" | tr -d ' ')
  if [ "$bytes" -gt "$LOG_MAX_BYTES" ]; then
    tail -c "$LOG_MAX_BYTES" "$log_file" > "$log_file.tmp" && mv "$log_file.tmp" "$log_file"
  fi
fi

# Hand-rolled JSON snapshot (no jq dependency on the write path).
printf '{\n  "name": "%s",\n  "status": "%s",\n  "exit_code": %s,\n  "duration_ms": %s,\n  "started_at": "%s",\n  "finished_at": "%s"\n}\n' \
  "$name" "$status" "$exit_code" "$duration_ms" "$started_at" "$finished_at" > "$json_file"

exit "$exit_code"
```

Make executable: `chmod +x bin/run-agent`

- [ ] **Step 4: Run test to verify it passes**

Run: `chmod +x bin/run-agent && bash bin/tests/run-agent.test.sh`
Expected: PASS — all checks, `Results: 9 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add bin/run-agent bin/tests/run-agent.test.sh
git commit -m "feat(login-agents): add run-agent instrumentation wrapper"
```

---

## Task 2: `run-agent` — log rotation test

**Files:**
- Modify: `bin/tests/run-agent.test.sh` (add a rotation case)

**Interfaces:**
- Consumes: `run-agent` from Task 1, honoring `LOGIN_AGENTS_LOG_MAX_BYTES`.
- Produces: nothing new (verifies existing rotation behavior).

- [ ] **Step 1: Add the failing test**

Append before the `echo "====="` results line in `bin/tests/run-agent.test.sh`:

```bash
# rotation: with a tiny cap, the log stays bounded near the cap
export LOGIN_AGENTS_LOG_MAX_BYTES=2048
"$WRAP" rot-agent -- /bin/sh -c 'for i in $(seq 1 500); do echo "line-$i-xxxxxxxxxxxxxxxx"; done' >/dev/null 2>&1
LR="$LOGIN_AGENTS_STATE_DIR/rot-agent.log"
rbytes=$(wc -c < "$LR" | tr -d ' ')
check "rotation: log bounded (<= 2x cap)" "$([ "$rbytes" -le 4096 ] && echo 0 || echo 1)"
unset LOGIN_AGENTS_LOG_MAX_BYTES
```

- [ ] **Step 2: Run test to verify it passes**

Run: `bash bin/tests/run-agent.test.sh`
Expected: PASS — rotation check included, `Results: 10 passed, 0 failed`. (Rotation logic already exists from Task 1; this locks it in.)

- [ ] **Step 3: Commit**

```bash
git add bin/tests/run-agent.test.sh
git commit -m "test(login-agents): verify run-agent log rotation"
```

---

## Task 3: `agents` CLI — name resolution + `inspect`

**Files:**
- Create: `custom-zsh/login-agents.zsh`
- Test: `custom-zsh/tests/login-agents.test.sh`

**Interfaces:**
- Consumes: state files written by `run-agent` (Task 1).
- Produces: zsh function `agents <subcommand> [name]`. Internal helpers (sourceable when `LOGIN_AGENTS_TEST=1`): `_la_state_dir`, `_la_label <name>` → `com.jdp.agent.<name>`, `_la_json_get <file> <key>`, `_la_on_login_dir`. `inspect <name>` prints raw JSON + resolved label + plist path + health-hook path.

- [ ] **Step 1: Write the failing test**

Create `custom-zsh/tests/login-agents.test.sh`:

```bash
#!/usr/bin/env zsh
# Tests for custom-zsh/login-agents.zsh helper resolution + inspect.
set -uo pipefail
emulate -L zsh

HERE="${0:A:h}"
export LOGIN_AGENTS_TEST=1
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export LOGIN_AGENTS_STATE_DIR="$TMP/state"
export LOGIN_AGENTS_ON_LOGIN_DIR="$TMP/on-login"
mkdir -p "$LOGIN_AGENTS_STATE_DIR" "$LOGIN_AGENTS_ON_LOGIN_DIR"

# minimal styles stub so sourcing works standalone
for v in BLUE GREEN RED YELLOW CYAN BOLD NC RESET; do typeset -g "$v"=""; done

source "$HERE/../login-agents.zsh"

pass=0; fail=0
check() { if [ "$2" = "0" ]; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1"; fail=$((fail+1)); fi }

echo "=== login-agents CLI tests ==="

lbl="$(_la_label demo)"
check "label scheme" "$([ "$lbl" = "com.jdp.agent.demo" ] && echo 0 || echo 1)"

cat > "$LOGIN_AGENTS_STATE_DIR/demo.json" <<'EOF'
{
  "name": "demo",
  "status": "success",
  "exit_code": 0,
  "duration_ms": 42,
  "started_at": "2026-07-21T09:00:00Z",
  "finished_at": "2026-07-21T09:00:00Z"
}
EOF
check "json_get status" "$([ "$(_la_json_get "$LOGIN_AGENTS_STATE_DIR/demo.json" status)" = "success" ] && echo 0 || echo 1)"
check "json_get exit_code" "$([ "$(_la_json_get "$LOGIN_AGENTS_STATE_DIR/demo.json" exit_code)" = "0" ] && echo 0 || echo 1)"

out="$(agents inspect demo 2>&1)"
check "inspect shows label" "$(printf '%s' "$out" | grep -q 'com.jdp.agent.demo' && echo 0 || echo 1)"
check "inspect shows json" "$(printf '%s' "$out" | grep -q '"status": "success"' && echo 0 || echo 1)"

echo "==============================="
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh custom-zsh/tests/login-agents.test.sh`
Expected: FAIL — `login-agents.zsh` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `custom-zsh/login-agents.zsh`:

```bash
#!/usr/bin/env zsh
# agents — Docker-style observability CLI for login LaunchAgents.
# Reads run-agent state + `launchctl print` / `log stream`. Read-only except restart.

_la_state_dir() {
  echo "${LOGIN_AGENTS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/login-agents}"
}
_la_on_login_dir() {
  echo "${LOGIN_AGENTS_ON_LOGIN_DIR:-$HOME/projects/mac-setup/on-login}"
}
_la_label() { echo "com.jdp.agent.$1"; }

# _la_json_get <file> <key> — jq if present, else bash/sed fallback.
_la_json_get() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$key" '.[$k] // empty' "$file"
  else
    grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"\{0,1\}[^\",}]*" "$file" \
      | sed 's/.*:[[:space:]]*"\{0,1\}//'
  fi
}

_la_plist_path() { echo "$(_la_on_login_dir)/$(_la_label "$1").plist"; }
_la_health_path() { echo "$(_la_on_login_dir)/health/$1.sh"; }

agents() {
  local sub="${1:-help}"; shift 2>/dev/null
  case "$sub" in
    inspect)
      local name="$1"
      [ -n "$name" ] || { echo "usage: agents inspect <name>" >&2; return 64; }
      echo "${BOLD}label:${NC}  $(_la_label "$name")"
      echo "${BOLD}plist:${NC}  $(_la_plist_path "$name")"
      echo "${BOLD}health:${NC} $(_la_health_path "$name")"
      echo "${BOLD}state:${NC}"
      local jf="$(_la_state_dir)/$name.json"
      if [ -f "$jf" ]; then cat "$jf"; else echo "  (no runs recorded)"; fi
      ;;
    help|--help|-h|"")
      echo "usage: agents <ps|logs|events|health|stats|restart|inspect> [name]"
      ;;
    *)
      echo "agents: unknown subcommand '$sub'" >&2
      echo "usage: agents <ps|logs|events|health|stats|restart|inspect> [name]" >&2
      return 1
      ;;
  esac
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `zsh custom-zsh/tests/login-agents.test.sh`
Expected: PASS — `Results: 5 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add custom-zsh/login-agents.zsh custom-zsh/tests/login-agents.test.sh
git commit -m "feat(login-agents): add agents CLI with resolution and inspect"
```

---

## Task 4: `agents ps` — table over all defined agents

**Files:**
- Modify: `custom-zsh/login-agents.zsh` (add `ps` case + `_la_discover`, `_la_kind`)
- Modify: `custom-zsh/tests/login-agents.test.sh` (add `ps` cases)

**Interfaces:**
- Consumes: `_la_label`, `_la_json_get`, `_la_on_login_dir`, `_la_plist_path` (Task 3).
- Produces: `agents ps [--running]` prints a header row `NAME STATE LAST-RUN EXIT RUNS KIND` and one row per agent discovered from `on-login/*.plist`. Helper `_la_kind <name>` → `daemon` if the plist contains `<key>KeepAlive</key>` else `oneshot`. `_la_discover` echoes agent names (basename of `com.jdp.agent.<name>.plist`, stripped).

- [ ] **Step 1: Add the failing test**

Append before the results line in `custom-zsh/tests/login-agents.test.sh`:

```bash
# ps: discovery + kind from plist fixtures
cat > "$LOGIN_AGENTS_ON_LOGIN_DIR/com.jdp.agent.demo.plist" <<'EOF'
<plist><dict><key>Label</key><string>com.jdp.agent.demo</string><key>RunAtLoad</key><true/></dict></plist>
EOF
cat > "$LOGIN_AGENTS_ON_LOGIN_DIR/com.jdp.agent.watch.plist" <<'EOF'
<plist><dict><key>Label</key><string>com.jdp.agent.watch</string><key>KeepAlive</key><true/></dict></plist>
EOF

check "kind: oneshot (no KeepAlive)" "$([ "$(_la_kind demo)" = "oneshot" ] && echo 0 || echo 1)"
check "kind: daemon (KeepAlive)" "$([ "$(_la_kind watch)" = "daemon" ] && echo 0 || echo 1)"

psout="$(agents ps 2>&1)"
check "ps: header present" "$(printf '%s' "$psout" | grep -q 'NAME' && echo 0 || echo 1)"
check "ps: lists demo" "$(printf '%s' "$psout" | grep -q 'demo' && echo 0 || echo 1)"
check "ps: lists watch" "$(printf '%s' "$psout" | grep -q 'watch' && echo 0 || echo 1)"
check "ps: demo shows last exit 0" "$(printf '%s' "$psout" | grep demo | grep -q ' 0 ' && echo 0 || echo 1)"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh custom-zsh/tests/login-agents.test.sh`
Expected: FAIL — `_la_kind`/`ps` not defined; unknown subcommand.

- [ ] **Step 3: Add implementation**

In `custom-zsh/login-agents.zsh`, add helpers after `_la_health_path`:

```bash
_la_kind() {
  local p="$(_la_plist_path "$1")"
  if [ -f "$p" ] && grep -q '<key>KeepAlive</key>' "$p"; then echo daemon; else echo oneshot; fi
}
_la_discover() {
  local dir="$(_la_on_login_dir)" f base
  for f in "$dir"/com.jdp.agent.*.plist(N); do
    base="${f:t}"; base="${base#com.jdp.agent.}"; base="${base%.plist}"
    echo "$base"
  done
}
# _la_launchctl_field <name> <needle> — pull "runs"/"pid" etc. from launchctl print. Empty if unavailable.
_la_launchctl_field() {
  local label="$(_la_label "$1")" needle="$2"
  launchctl print "gui/${UID}/${label}" 2>/dev/null \
    | grep -E "^[[:space:]]*${needle} = " | head -1 | sed 's/.*= //'
}
```

Add a `ps)` case inside `agents()` before `help|--help`:

```bash
    ps)
      local only_running=0
      [ "${1:-}" = "--running" ] && only_running=1
      printf '%-18s %-10s %-22s %-5s %-6s %s\n' NAME STATE LAST-RUN EXIT RUNS KIND
      local name jf status exit_code finished runs pid state kind
      for name in $(_la_discover); do
        jf="$(_la_state_dir)/$name.json"
        status="$(_la_json_get "$jf" status 2>/dev/null)"
        exit_code="$(_la_json_get "$jf" exit_code 2>/dev/null)"
        finished="$(_la_json_get "$jf" finished_at 2>/dev/null)"
        pid="$(_la_launchctl_field "$name" pid)"
        runs="$(_la_launchctl_field "$name" runs)"; [ -n "$runs" ] || runs="-"
        kind="$(_la_kind "$name")"
        if [ -n "$pid" ]; then state="running"; else state="${status:-never}"; fi
        if [ "$only_running" = "1" ] && [ -z "$pid" ]; then continue; fi
        printf '%-18s %-10s %-22s %-5s %-6s %s\n' \
          "$name" "$state" "${finished:--}" "${exit_code:--}" "$runs" "$kind"
      done
      ;;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `zsh custom-zsh/tests/login-agents.test.sh`
Expected: PASS — `Results: 12 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add custom-zsh/login-agents.zsh custom-zsh/tests/login-agents.test.sh
git commit -m "feat(login-agents): add agents ps table"
```

---

## Task 5: `agents` — logs / events / health / stats / restart

**Files:**
- Modify: `custom-zsh/login-agents.zsh` (add remaining subcommand cases)
- Modify: `custom-zsh/tests/login-agents.test.sh` (add logs + health cases)

**Interfaces:**
- Consumes: `_la_state_dir`, `_la_label`, `_la_health_path` (Tasks 3-4).
- Produces: `agents logs [-f] <name>`, `agents events <name>`, `agents health <name>`, `agents stats <name>`, `agents restart <name>`. `logs` cats the log (or `tail -f` with `-f`); `health` runs the hook if present else prints "no healthcheck defined"; `stats` runs `ps -o` on a live PID else "not running (oneshot)"; `restart` runs `launchctl kickstart -k`; `events` execs `log stream --predicate`.

- [ ] **Step 1: Add the failing test**

Append before the results line in `custom-zsh/tests/login-agents.test.sh`:

```bash
# logs
echo "hello-log-line" > "$LOGIN_AGENTS_STATE_DIR/demo.log"
logout="$(agents logs demo 2>&1)"
check "logs: prints log contents" "$(printf '%s' "$logout" | grep -q hello-log-line && echo 0 || echo 1)"

# health: missing hook
hmiss="$(agents health demo 2>&1)"
check "health: no hook message" "$(printf '%s' "$hmiss" | grep -qi 'no healthcheck' && echo 0 || echo 1)"

# health: present hook runs and its exit is surfaced
mkdir -p "$LOGIN_AGENTS_ON_LOGIN_DIR/health"
cat > "$LOGIN_AGENTS_ON_LOGIN_DIR/health/demo.sh" <<'EOF'
#!/usr/bin/env bash
echo "healthy-output"; exit 0
EOF
chmod +x "$LOGIN_AGENTS_ON_LOGIN_DIR/health/demo.sh"
hok="$(agents health demo 2>&1)"
check "health: runs hook (output)" "$(printf '%s' "$hok" | grep -q healthy-output && echo 0 || echo 1)"
check "health: reports pass" "$(printf '%s' "$hok" | grep -qi 'pass' && echo 0 || echo 1)"

# stats: oneshot with no live pid
sout="$(agents stats demo 2>&1)"
check "stats: not running message" "$(printf '%s' "$sout" | grep -qi 'not running' && echo 0 || echo 1)"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh custom-zsh/tests/login-agents.test.sh`
Expected: FAIL — `logs`/`health`/`stats` unknown subcommands.

- [ ] **Step 3: Add implementation**

Add these cases inside `agents()` before `help|--help`:

```bash
    logs)
      local follow=0
      if [ "${1:-}" = "-f" ]; then follow=1; shift; fi
      local name="$1"; [ -n "$name" ] || { echo "usage: agents logs [-f] <name>" >&2; return 64; }
      local lf="$(_la_state_dir)/$name.log"
      [ -f "$lf" ] || { echo "no log for '$name'" >&2; return 1; }
      if [ "$follow" = "1" ]; then tail -f "$lf"; else cat "$lf"; fi
      ;;
    events)
      local name="$1"; [ -n "$name" ] || { echo "usage: agents events <name>" >&2; return 64; }
      log stream --predicate "process == \"$name\""
      ;;
    health)
      local name="$1"; [ -n "$name" ] || { echo "usage: agents health <name>" >&2; return 64; }
      local hook="$(_la_health_path "$name")"
      if [ ! -x "$hook" ] && [ ! -f "$hook" ]; then
        echo "no healthcheck defined for '$name'"; return 0
      fi
      local out; out="$(bash "$hook" 2>&1)"; local rc=$?
      echo "$out"
      if [ "$rc" -eq 0 ]; then echo "${GREEN}health: pass${NC}"; else echo "${RED}health: fail (exit $rc)${NC}"; return "$rc"; fi
      ;;
    stats)
      local name="$1"; [ -n "$name" ] || { echo "usage: agents stats <name>" >&2; return 64; }
      local pid="$(_la_launchctl_field "$name" pid)"
      if [ -z "$pid" ]; then echo "$name: not running (oneshot or stopped)"; return 0; fi
      ps -o pid,%cpu,%mem,etime -p "$pid"
      ;;
    restart)
      local name="$1"; [ -n "$name" ] || { echo "usage: agents restart <name>" >&2; return 64; }
      launchctl kickstart -k "gui/${UID}/$(_la_label "$name")"
      ;;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `zsh custom-zsh/tests/login-agents.test.sh`
Expected: PASS — `Results: 18 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add custom-zsh/login-agents.zsh custom-zsh/tests/login-agents.test.sh
git commit -m "feat(login-agents): add logs, events, health, stats, restart"
```

---

## Task 6: Example agents + `on-login/` scaffolding

**Files:**
- Create: `on-login/com.jdp.agent.launch-apps.plist`
- Create: `on-login/agents/launch-apps.sh`
- Create: `on-login/com.jdp.agent.keepalive-demo.plist`
- Create: `on-login/agents/keepalive-demo.sh`
- Create: `on-login/health/keepalive-demo.sh`
- Create: `on-login/README.md`

**Interfaces:**
- Consumes: `bin/run-agent` (Task 1) at runtime via `__REPO__/bin/run-agent`.
- Produces: templated plists (with `__REPO__` placeholder) and scripts the installer (Task 7) wires up.

- [ ] **Step 1: Create the app-launcher script**

Create `on-login/agents/launch-apps.sh`:

```bash
#!/usr/bin/env bash
# Primary example agent: launch a user-defined set of apps at login.
# Observable via `agents ps` / `agents logs launch-apps`.
# Edit APPS to taste. Missing apps warn but do not fail the whole run.
set -uo pipefail

APPS=(
  # "Slack"
  # "OrbStack"
)

status=0
for app in "${APPS[@]}"; do
  if open -ga "$app"; then
    echo "launched: $app"
  else
    echo "WARN: could not launch '$app' (not installed?)"
    status=1
  fi
done

if [ "${#APPS[@]}" -eq 0 ]; then
  echo "no apps configured — edit on-login/agents/launch-apps.sh APPS array"
fi
exit "$status"
```

Make executable: `chmod +x on-login/agents/launch-apps.sh`

- [ ] **Step 2: Create the launch-apps plist (templated)**

Create `on-login/com.jdp.agent.launch-apps.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.jdp.agent.launch-apps</string>
  <key>ProgramArguments</key>
  <array>
    <string>__REPO__/bin/run-agent</string>
    <string>launch-apps</string>
    <string>--</string>
    <string>__REPO__/on-login/agents/launch-apps.sh</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
```

- [ ] **Step 3: Create the daemon example (script + health hook + plist)**

Create `on-login/agents/keepalive-demo.sh`:

```bash
#!/usr/bin/env bash
# Daemon example: a trivial long-running loop to exercise the supervise path
# (agents stats/health/restart). Writes a heartbeat file health can check.
set -uo pipefail
HEARTBEAT="${XDG_STATE_HOME:-$HOME/.local/state}/login-agents/keepalive-demo.heartbeat"
mkdir -p "$(dirname "$HEARTBEAT")"
while true; do
  date -u +%s > "$HEARTBEAT"
  echo "heartbeat $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  sleep 30
done
```

Create `on-login/health/keepalive-demo.sh`:

```bash
#!/usr/bin/env bash
# Health hook: pass if heartbeat is fresh (< 90s old).
set -uo pipefail
HEARTBEAT="${XDG_STATE_HOME:-$HOME/.local/state}/login-agents/keepalive-demo.heartbeat"
[ -f "$HEARTBEAT" ] || { echo "no heartbeat file"; exit 1; }
now=$(date -u +%s); last=$(cat "$HEARTBEAT")
age=$(( now - last ))
echo "heartbeat age: ${age}s"
[ "$age" -lt 90 ]
```

Create `on-login/com.jdp.agent.keepalive-demo.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.jdp.agent.keepalive-demo</string>
  <key>ProgramArguments</key>
  <array>
    <string>__REPO__/bin/run-agent</string>
    <string>keepalive-demo</string>
    <string>--</string>
    <string>__REPO__/on-login/agents/keepalive-demo.sh</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
```

Make executable: `chmod +x on-login/agents/keepalive-demo.sh on-login/health/keepalive-demo.sh`

- [ ] **Step 4: Create `on-login/README.md`**

```markdown
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
```

- [ ] **Step 5: Verify scripts run standalone through the wrapper**

Run: `LOGIN_AGENTS_STATE_DIR="$(mktemp -d)" bin/run-agent launch-apps -- ./on-login/agents/launch-apps.sh; echo "exit=$?"`
Expected: exit=0, prints "no apps configured …" (empty APPS array is a clean success).

- [ ] **Step 6: Commit**

```bash
git add on-login
git commit -m "feat(login-agents): add app-launcher and daemon example agents"
```

---

## Task 7: `dorothy agents` install/uninstall subcommand

**Files:**
- Modify: `dorothy` (add `cmd_agents`, dispatch case, help entry)

**Interfaces:**
- Consumes: `on-login/*.plist` templates (Task 6), `createdirsafely`/color vars/log fns from `shared.sh`.
- Produces: `dorothy agents <install|uninstall|list> [name]`. `install` substitutes `__REPO__`→repo root into a materialized plist under `~/Library/LaunchAgents/com.jdp.agent.<name>.plist`, then `launchctl bootstrap gui/$UID <plist>`. `uninstall` runs `launchctl bootout` + removes the file (`--purge` also wipes state). `list` delegates to the `agents ps` CLI if available.

- [ ] **Step 1: Add `cmd_agents` to `dorothy`**

In `dorothy`, before the final `main()` function, add:

```bash
###############################################################################
# Login Agents                                                                #
###############################################################################

cmd_agents() {
  local action="${1:-list}"; shift 2>/dev/null
  local repo="$SCRIPT_DIR"
  local src_dir="$repo/on-login"
  local dest_dir="$HOME/Library/LaunchAgents"
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/login-agents"

  _agents_names() {
    local f base
    for f in "$src_dir"/com.jdp.agent.*.plist; do
      [ -e "$f" ] || continue
      base="$(basename "$f")"; base="${base#com.jdp.agent.}"; base="${base%.plist}"
      echo "$base"
    done
  }

  case "$action" in
    install)
      createdirsafely "$dest_dir"
      local names=("$@"); [ ${#names[@]} -gt 0 ] || names=($(_agents_names))
      local name src dest
      for name in "${names[@]}"; do
        src="$src_dir/com.jdp.agent.$name.plist"
        dest="$dest_dir/com.jdp.agent.$name.plist"
        if [ ! -f "$src" ]; then logerror "No such agent: $name"; continue; fi
        sed "s|__REPO__|$repo|g" "$src" > "$dest"
        launchctl bootout "gui/${UID}/com.jdp.agent.$name" 2>/dev/null || true
        if launchctl bootstrap "gui/${UID}" "$dest" 2>/dev/null; then
          logsuccess "Installed agent: $name"
        else
          logerror "Failed to bootstrap: $name"
        fi
      done
      ;;
    uninstall)
      local purge=0 names=()
      for a in "$@"; do
        if [ "$a" = "--purge" ]; then purge=1; else names+=("$a"); fi
      done
      [ ${#names[@]} -gt 0 ] || names=($(_agents_names))
      local name dest
      for name in "${names[@]}"; do
        dest="$dest_dir/com.jdp.agent.$name.plist"
        launchctl bootout "gui/${UID}/com.jdp.agent.$name" 2>/dev/null || true
        rm -f "$dest"
        [ "$purge" = "1" ] && rm -f "$state_dir/$name.json" "$state_dir/$name.log"
        logsuccess "Uninstalled agent: $name"
      done
      ;;
    list)
      if command -v agents >/dev/null 2>&1; then
        agents ps
      else
        loginfo "Defined agents:"; _agents_names
      fi
      ;;
    *)
      logerror "Unknown agents action: $action"
      printf "Usage: dorothy agents <install|uninstall|list> [name...]\n"
      return 1
      ;;
  esac
}
```

- [ ] **Step 2: Wire dispatch + help**

In `dorothy`'s `main()` `case $command in` block, add before the `*)` default:

```bash
    agents)
      cmd_agents "${args[@]}"
      ;;
```

In `show_help()`'s COMMANDS list, add a line after `sync`:

```bash
  ${GREEN}agents${NC}       Install/observe login LaunchAgents
```

- [ ] **Step 3: Verify dispatch (no bootstrap side-effects)**

Run: `bash dorothy agents list`
Expected: prints the `agents ps` table (if the CLI is loaded in this shell) OR "Defined agents:" followed by `launch-apps` and `keepalive-demo`. No error.

- [ ] **Step 4: Verify `__REPO__` substitution produces absolute paths**

Run: `sed "s|__REPO__|$(pwd)|g" on-login/com.jdp.agent.launch-apps.plist | grep run-agent`
Expected: an absolute path line `<string>/Users/.../mac-setup/bin/run-agent</string>` — no `__REPO__` remaining.

- [ ] **Step 5: Commit**

```bash
git add dorothy
git commit -m "feat(login-agents): add dorothy agents install/uninstall/list"
```

---

## Task 8: End-to-end install + docs

**Files:**
- Modify: `CLAUDE.md` (document new behavior)

**Interfaces:**
- Consumes: everything from Tasks 1-7.
- Produces: documentation; a verified end-to-end install of the `launch-apps` example.

- [ ] **Step 1: End-to-end install and observe**

Run:
```bash
bash dorothy agents install launch-apps
launchctl print "gui/${UID}/com.jdp.agent.launch-apps" >/dev/null 2>&1 && echo "BOOTSTRAPPED"
launchctl kickstart -k "gui/${UID}/com.jdp.agent.launch-apps"
sleep 1
cat "$HOME/.local/state/login-agents/launch-apps.json"
```
Expected: prints `BOOTSTRAPPED`, then a JSON snapshot with `"name": "launch-apps"` and `"status": "success"`.

- [ ] **Step 2: Verify via the CLI (in a zsh with the function loaded)**

Run: `zsh -c 'source custom-zsh/login-agents.zsh; agents ps'`
Expected: table listing `launch-apps` (and `keepalive-demo`) with a real LAST-RUN timestamp for launch-apps.

- [ ] **Step 3: Clean up the e2e install**

Run: `bash dorothy agents uninstall launch-apps`
Expected: `Uninstalled agent: launch-apps`; `~/Library/LaunchAgents/com.jdp.agent.launch-apps.plist` gone.

- [ ] **Step 4: Document in `CLAUDE.md`**

In `/Users/jessdelgadoperez/projects/mac-setup/CLAUDE.md`, add a new section after "Shell Navigation & Project Binaries":

```markdown
### Login Agents Observability
Login tasks run as launchd LaunchAgents wrapped by `bin/run-agent <name> -- <cmd>`,
which stamps timing, captures exit code + duration, writes a last-run snapshot to
`~/.local/state/login-agents/<name>.json`, and appends a rotated log
(`<name>.log`, capped at 1 MB). Plists in `on-login/` are the source of truth and
exec the wrapper — never the script directly — so observability is uniform.

The `agents` CLI (`custom-zsh/login-agents.zsh`, `caff`-style) gives Docker-style views:
- `agents ps [--running]` — table of all defined agents: name, state, last-run, exit, runs, kind
- `agents logs [-f] <name>` — per-agent log (`-f` follows, like `docker logs -f`)
- `agents events <name>` — live `log stream` for the process
- `agents health <name>` — runs `on-login/health/<name>.sh` on demand
- `agents stats <name>` — `%cpu/%mem/etime` for a running daemon
- `agents restart <name>` — `launchctl kickstart -k`
- `agents inspect <name>` — raw state + resolved label/plist/health paths

Install/uninstall via `dorothy agents install|uninstall|list [name]` — it substitutes
the `__REPO__` placeholder in each plist with the absolute repo path, symlinks/materializes
into `~/Library/LaunchAgents/`, and `launchctl bootstrap`s. Agents are labeled
`com.jdp.agent.<name>`. Add a new agent: see `on-login/README.md`.

Standalone executables (e.g. `run-agent`) live in `bin/`, which is on `PATH`.
```

- [ ] **Step 5: Ensure `bin/` is on PATH**

Check whether `bin/` is already exported. Run: `grep -rn "mac-setup/bin" custom-zsh/ dotfiles/.zshrc 2>/dev/null`
If absent, add to `custom-zsh/development.zsh` (near the existing PATH block) idempotently:

```bash
# mac-setup standalone executables
if [[ ":$PATH:" != *":$HOME/projects/mac-setup/bin:"* ]]; then
  export PATH="$HOME/projects/mac-setup/bin:$PATH"
fi
```

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md custom-zsh/development.zsh
git commit -m "docs(login-agents): document agents CLI and add bin to PATH"
```

---

## Self-Review

**Spec coverage:**
- Wrapper (snapshot + log + exit passthrough + rotation) → Tasks 1-2. ✓
- CLI ps/logs/events/health/stats/restart/inspect → Tasks 3-5. ✓
- Plist source-of-truth, app-launcher primary + daemon example + health hook → Task 6. ✓
- `dorothy agents` install/uninstall/list, `__REPO__` substitution, `com.jdp.agent.<name>` → Task 7. ✓
- XDG state, jq-optional read, hand-rolled write, TTY-aware, no-pm2, all-defined `ps` → Global Constraints + Tasks 1/3/4. ✓
- CLAUDE.md docs + bin on PATH → Task 8. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code; commands have expected output.

**Type consistency:** Helper names consistent across tasks (`_la_label`, `_la_json_get`, `_la_state_dir`, `_la_on_login_dir`, `_la_plist_path`, `_la_health_path`, `_la_kind`, `_la_discover`, `_la_launchctl_field`). JSON keys identical between wrapper write (Task 1) and CLI read (Tasks 3-5): `name,status,exit_code,duration_ms,started_at,finished_at`. Label scheme identical in wrapper-adjacent CLI and dorothy. `LOGIN_AGENTS_STATE_DIR`/`LOGIN_AGENTS_ON_LOGIN_DIR` test seams consistent.
