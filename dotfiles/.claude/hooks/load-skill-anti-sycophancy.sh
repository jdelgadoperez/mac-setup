#!/usr/bin/env bash
# SessionStart hook: auto-load the anti-sycophancy skill content into every session.
# Emits the skill body as additionalContext so the behavior is active from turn 1
# without relying on the model choosing to invoke the skill.
set -euo pipefail

HOOK_SRC="${BASH_SOURCE[0]}"
while [ -L "$HOOK_SRC" ]; do HOOK_SRC="$(readlink "$HOOK_SRC")"; done
# CDPATH= : cd echoes the resolved dir when it uses CDPATH, which would be
# captured by $( ) and double the path. Harmless for absolute paths, breaks
# relative invocation.
HOOK_DIR="$(CDPATH= cd "$(dirname "$HOOK_SRC")" && pwd)"
# shellcheck source=/dev/null
if [ -r "$HOOK_DIR/hook-log.sh" ]; then . "$HOOK_DIR/hook-log.sh"; else hook_log() { :; }; fi

skill="$HOME/.claude/skills/anti-sycophancy/SKILL.md"
if [ ! -f "$skill" ]; then
  hook_log load-skill-anti-sycophancy declined "skill file missing: $skill"
  exit 0
fi

if ! command -v node >/dev/null 2>&1; then
  hook_log load-skill-anti-sycophancy error "node not found"
  exit 0
fi

node -e '
  const fs = require("fs");
  const body = fs.readFileSync(process.argv[1], "utf8");
  const ctx =
    "# Auto-loaded skill: anti-sycophancy\n\n" +
    "This behavioral skill is active for the ENTIRE session. Apply it to every response.\n\n" +
    body;
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: ctx }
  }));
' "$skill"
hook_log load-skill-anti-sycophancy loaded "anti-sycophancy"
