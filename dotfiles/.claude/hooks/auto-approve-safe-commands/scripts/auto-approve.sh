#!/bin/bash
# @hook-event: PreToolUse
# @hook-command: ~/.claude/hooks/auto-approve-safe-commands/scripts/auto-approve.sh
# @description: Auto-approves safe, read-only Bash commands — system info, file inspection, gh CLI, and scripts in ~/.claude/skills/ or ~/.claude/scripts/
#
# PreToolUse hook: auto-approves safe, read-only Bash commands.
# Returns {"decision":"approve"} for known-safe commands.
# Exits with no output for everything else (pass through to normal flow).

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [ "$TOOL" != "Bash" ]; then
  exit 0
fi

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
if [ -z "$CMD" ]; then
  exit 0
fi

# Pre-approve any script in ~/.claude/scripts/ or ~/.claude/skills/ (matches both ~/... and $HOME/... forms)
# Reject commands containing shell metacharacters (;, |, &, `, $()) to prevent command injection
if echo "$CMD" | grep -qE "^(python3?\s+)?(~|${HOME})/\.claude/(scripts|skills)/[^ ]+(\s|$)" && \
   ! echo "$CMD" | grep -qE '[;|&`]|\$\('; then
  echo '{"decision":"approve"}'
  exit 0
fi

# Extract base command (first word, strip path prefix)
BASE_CMD=$(echo "$CMD" | awk '{print $1}' | sed 's|.*/||')

case "$BASE_CMD" in
  # System info
  which|type|uname|hostname|whoami|id|date|uptime|sw_vers|arch|sysctl)
    echo '{"decision":"approve"}'
    exit 0
    ;;
  # Directory creation (non-destructive)
  mkdir)
    echo '{"decision":"approve"}'
    exit 0
    ;;
  # Git — safe subcommands only (no push, reset, rebase, clean)
  git)
    SUBCMD=$(echo "$CMD" | awk '{print $2}')
    case "$SUBCMD" in
      status|log|diff|branch|fetch|checkout|stash|remote|show|rev-parse|merge-base|symbolic-ref)
        echo '{"decision":"approve"}'
        exit 0
        ;;
    esac
    ;;
  # File inspection (non-destructive)
  pwd|file|stat|du|df|head|tail|wc|diff|md5|shasum|sha256sum|readlink|realpath|basename|dirname)
    echo '{"decision":"approve"}'
    exit 0
    ;;
  # Safe output
  echo|printf|env|printenv|locale|true|false|test)
    echo '{"decision":"approve"}'
    exit 0
    ;;
  # Package managers — read-only subcommands only
  npm|yarn|pnpm)
    SUBCMD=$(echo "$CMD" | awk '{print $2}')
    case "$SUBCMD" in
      list|ls|info|view|outdated|why|show|audit|version|--version|-v|config)
        echo '{"decision":"approve"}'
        exit 0
        ;;
    esac
    ;;
  # GitHub CLI — read-only and pipeline-required subcommands only
  gh)
    SUBCMD=$(echo "$CMD" | awk '{print $2}')
    case "$SUBCMD" in
      pr)
        # Allow read operations and comment posting (needed by the PR-review pipeline)
        PR_ACTION=$(echo "$CMD" | awk '{print $3}')
        case "$PR_ACTION" in
          view|diff|list|checks|comment)
            echo '{"decision":"approve"}'
            exit 0
            ;;
        esac
        ;;
      api)
        # Allow GET requests (default) — block explicit --method DELETE/PUT/PATCH
        if ! echo "$CMD" | grep -qiE '\-\-method\s+(DELETE|PUT|PATCH|POST)' && \
           ! echo "$CMD" | grep -qiE '\-X\s+(DELETE|PUT|PATCH|POST)'; then
          echo '{"decision":"approve"}'
          exit 0
        fi
        ;;
      issue|run|search|repo)
        # Allow read-only: gh issue view, gh run view, gh search, gh repo view
        SUB_ACTION=$(echo "$CMD" | awk '{print $3}')
        case "$SUB_ACTION" in
          view|list|"")
            echo '{"decision":"approve"}'
            exit 0
            ;;
        esac
        ;;
    esac
    ;;
  # Docker — read-only subcommands only
  docker)
    SUBCMD=$(echo "$CMD" | awk '{print $2}')
    case "$SUBCMD" in
      ps|images|inspect|logs|stats|version|info|network|volume)
        echo '{"decision":"approve"}'
        exit 0
        ;;
    esac
    ;;
  # Piped read commands — only if no write redirections
  cat|grep|rg|ag|awk|sed|sort|uniq|cut|tr|xargs)
    if ! echo "$CMD" | grep -qE '>\s*[^&]|>>|rm |mv |cp |chmod |chown '; then
      echo '{"decision":"approve"}'
      exit 0
    fi
    ;;
esac

# Not a known safe command — pass through to normal permission flow
exit 0
