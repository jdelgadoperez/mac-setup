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

# Resolve through symlinks: ~/.claude/hooks/ is a directory of per-file links
# into mac-setup, so dirname($0) lands in the install dir, which does not
# contain sibling helpers. Follow the link to find the real source directory.
HOOK_SRC="${BASH_SOURCE[0]}"
while [ -L "$HOOK_SRC" ]; do HOOK_SRC="$(readlink "$HOOK_SRC")"; done
HOOK_DIR="$(cd "$(dirname "$HOOK_SRC")" && pwd)"
# shellcheck source=/dev/null
# if/else, not `A && B || C`: with the && || form the no-op fallback also runs
# when sourcing succeeds but returns non-zero, clobbering the real logger
# (shellcheck SC2015). Verified: that form silently replaced a working helper.
if [ -r "$HOOK_DIR/hook-log.sh" ]; then . "$HOOK_DIR/hook-log.sh"; else hook_log() { :; }; fi

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
[ "$TOOL" != "Bash" ] && exit 0

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Block `git -C` only when it's an actual command — not when it appears
# inside a quoted string or other shell context. Anchor to a command
# boundary: start-of-string, semicolon, &&, ||, single pipe, command
# substitution opener, or backtick.
#
# Match against the whole command as ONE string (-z), not line by line:
# grep treats every newline as `^`, so a heredoc body that merely mentions
# `git -C` — a commit message, a doc block — was blocked as if it were a
# command. With -z the anchor means true start-of-input.
# Boundary check in python, not grep: BSD grep applies `^` per line even with
# -z, so a multi-line command that merely *mentions* the flag (a commit
# message heredoc, a doc block) was blocked as if it were invoking it.
# python's \A anchors to true start-of-string, and [ \t] keeps the gap from
# spanning a newline.
if printf '%s' "$CMD" | python3 -c 'import re,sys; sys.exit(0 if re.search(r"(\A|;|&&|\|\||\||\$\(|`)[ \t]*git[ \t]+-C\b", sys.stdin.read()) else 1)'; then
  hook_log cd-git-allow blocked "git -C"
  echo '{"decision":"block","reason":"Do not use git -C. Use cd into the directory instead."}'
  exit 0
fi

# Auto-approve pure cd commands (no chaining operators that could smuggle other commands)
if echo "$CMD" | grep -qE '^cd\s+[^;&|$`()]+$' && ! echo "$CMD" | grep -qE '[;&|]|&&|\|\||`|\$\('; then
  hook_log cd-git-allow approved "cd"
  echo '{"decision":"approve"}'
  exit 0
fi

hook_log cd-git-allow passthrough ""
exit 0
