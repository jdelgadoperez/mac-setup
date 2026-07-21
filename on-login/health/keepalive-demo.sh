#!/usr/bin/env bash
# Health hook: pass if heartbeat is fresh (< 90s old).
set -uo pipefail
HEARTBEAT="${XDG_STATE_HOME:-$HOME/.local/state}/login-agents/keepalive-demo.heartbeat"
[ -f "$HEARTBEAT" ] || { echo "no heartbeat file"; exit 1; }
now=$(date -u +%s); last=$(cat "$HEARTBEAT")
age=$(( now - last ))
echo "heartbeat age: ${age}s"
[ "$age" -lt 90 ]
