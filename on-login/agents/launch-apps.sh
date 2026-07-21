#!/usr/bin/env bash
# Primary example agent: launch a user-defined set of apps at login.
# Observable via `agents ps` / `agents logs launch-apps`.
# Edit APPS to taste. Missing apps warn but do not fail the whole run.
set -uo pipefail

APPS=(
  # "Slack"
  # "OrbStack"
)

if [ "${#APPS[@]}" -eq 0 ]; then
  echo "no apps configured — edit on-login/agents/launch-apps.sh APPS array"
  exit 0
fi

status=0
for app in "${APPS[@]}"; do
  if open -ga "$app"; then
    echo "launched: $app"
  else
    echo "WARN: could not launch '$app' (not installed?)"
    status=1
  fi
done

exit "$status"
