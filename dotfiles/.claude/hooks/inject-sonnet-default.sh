#!/usr/bin/env bash
# PreToolUse hook: inject model: "sonnet" into subagent tool calls if model is not set.
# Reads JSON from stdin, outputs JSON with hookSpecificOutput.updatedInput if model is missing.
#
# Matches BOTH "Task" and "Agent". The subagent tool is named `Agent` in current
# Claude Code and was `Task` in older versions; this file syncs across machines
# via mac-setup, so it must cover whichever name the local version uses. Matching
# only one name makes the hook a silent no-op -- it still runs and still exits 0,
# so nothing surfaces the failure. That is exactly how this went unnoticed before.

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
  exit 0
fi

# Check if model is already set (non-null, non-empty)
model=$(echo "$input" | jq -r '.tool_input.model // empty')

if [ -n "$model" ]; then
  # Model already set — pass through unchanged
  exit 0
fi

# Inject model: "sonnet" into the tool input
updated_input=$(echo "$input" | jq '.tool_input + {"model": "sonnet"}')

echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PreToolUse\", \"updatedInput\": $updated_input}}"
