#!/usr/bin/env bash
# PreToolUse hook — blocks `git -C` and auto-approves safe `cd` commands
#
# Rationale:
#   - `git -C <path>` silently runs git in a different directory, which can be
#     confusing when Claude is using worktrees. Blocks it with a helpful message.
#   - `cd <path>` commands (that don't chain destructive ops) are safe to
#     auto-approve so Claude doesn't have to prompt for every directory change.
#
# Note: If you use fnm with repos that have .nvmrc files, `cd` can trigger
# Node version auto-switching. This hook auto-approves pure `cd` commands,
# which avoids the need to prompt the user for every directory change.
# See rules/fnm-bash-hang.md for full context.

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
[ "$TOOL" != "Bash" ] && exit 0

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Block `git -C` only when it's an actual command — not when it appears
# inside a quoted string or other shell context. Anchor to a command
# boundary: start-of-string, semicolon, &&, ||, single pipe, command
# substitution opener, or backtick.
if echo "$CMD" | grep -qE '(^|;|&&|\|\||\||\$\(|`)[[:space:]]*git[[:space:]]+-C\b'; then
  echo '{"decision":"block","reason":"Do not use git -C. Use cd into the directory instead."}'
  exit 0
fi

# Auto-approve pure cd commands (no chaining operators that could smuggle other commands)
if echo "$CMD" | grep -qE '^cd\s+[^;&|$`()]+$' && ! echo "$CMD" | grep -qE '[;&|]|&&|\|\||`|\$\('; then
  echo '{"decision":"approve"}'
  exit 0
fi

exit 0
