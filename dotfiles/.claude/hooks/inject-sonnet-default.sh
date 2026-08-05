#!/usr/bin/env bash
# PreToolUse hook: inject model: "sonnet" into subagent tool calls if model is not set.
# Reads JSON from stdin, outputs JSON with hookSpecificOutput.updatedInput if model is missing.
#
# Matches BOTH "Task" and "Agent". The subagent tool is named `Agent` in current
# Claude Code and was `Task` in older versions; this file syncs across machines
# via mac-setup, so it must cover whichever name the local version uses. Matching
# only one name makes the hook a silent no-op -- it still runs and still exits 0,
# so nothing surfaces the failure. That is exactly how this went unnoticed before.

# Resolve through symlinks: ~/.claude/hooks/ is a directory of per-file links
# into mac-setup, so dirname($0) lands in the install dir, which does not
# contain sibling helpers. Follow the link to find the real source directory.
# Falls back to a no-op hook_log so a missing helper can never break the hook.
HOOK_SRC="${BASH_SOURCE[0]}"
while [ -L "$HOOK_SRC" ]; do HOOK_SRC="$(readlink "$HOOK_SRC")"; done
HOOK_DIR="$(cd "$(dirname "$HOOK_SRC")" && pwd)"
# shellcheck source=/dev/null
if [ -r "$HOOK_DIR/hook-log.sh" ]; then . "$HOOK_DIR/hook-log.sh"; else hook_log() { :; }; fi

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty')

# Only act on subagent dispatch tools
case "$tool_name" in
  Task|Agent) ;;
  *) exit 0 ;;
esac

# Forks always inherit the parent model -- a model override is ignored for them,
# so injecting one would be a no-op that misrepresents what the call will do.
subagent_type=$(echo "$input" | jq -r '.tool_input.subagent_type // empty')
if [ "$subagent_type" = "fork" ]; then
  hook_log inject-sonnet-default declined "fork inherits parent model"
  exit 0
fi

# Check if model is already set (non-null, non-empty)
model=$(echo "$input" | jq -r '.tool_input.model // empty')

if [ -n "$model" ]; then
  # Model already set — pass through unchanged
  hook_log inject-sonnet-default declined "model already set: $model"
  exit 0
fi

# Inject model: "sonnet" into the tool input
updated_input=$(echo "$input" | jq '.tool_input + {"model": "sonnet"}')

hook_log inject-sonnet-default injected "model=sonnet tool=$tool_name"
echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PreToolUse\", \"updatedInput\": $updated_input}}"
