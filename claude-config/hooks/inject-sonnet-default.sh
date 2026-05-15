#!/usr/bin/env bash
# PreToolUse hook: inject model: "sonnet" into Task tool calls if model is not set.
# Reads JSON from stdin, outputs JSON with hookSpecificOutput.updatedInput if model is missing.

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty')

# Only act on Task tool calls
if [ "$tool_name" != "Task" ]; then
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
