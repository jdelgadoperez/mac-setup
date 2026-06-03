#!/usr/bin/env bash
# SessionStart hook: auto-load the anti-sycophancy skill content into every session.
# Emits the skill body as additionalContext so the behavior is active from turn 1
# without relying on the model choosing to invoke the skill.
set -euo pipefail

skill="$HOME/.claude/skills/anti-sycophancy/SKILL.md"
[ -f "$skill" ] || exit 0

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
