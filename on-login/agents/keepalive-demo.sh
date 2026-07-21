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
