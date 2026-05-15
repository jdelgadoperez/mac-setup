#!/usr/bin/env bash
# UserPromptSubmit hook: prepend delegation reminder when running on Opus.
# Detects Opus via CLAUDE_MODEL env var or falls back to settings.json model field.
# If detection is inconclusive, injects anyway (reminder is harmless on Sonnet).

DELEGATION_MSG="[OPUS DELEGATION DIRECTIVE] You are running on Opus. For any implementation work (Edit/Write/Bash for builds/tests/code changes, multi-file refactors, lint/typecheck runs, PR ops), default to dispatching a Sonnet subagent via Task. Do orchestration, planning, brief one-off edits, and reviewing subagent output yourself."

# Try CLAUDE_MODEL env var first
current_model="${CLAUDE_MODEL:-}"

# If not set, try reading from settings.json
if [ -z "$current_model" ]; then
  settings_model=$(jq -r '.model // empty' ~/.claude/settings.json 2>/dev/null)
  current_model="${settings_model:-}"
fi

# If we have a model value, only inject for opus
if [ -n "$current_model" ]; then
  # Check if model contains "opus" (case-insensitive)
  if echo "$current_model" | grep -qi "opus"; then
    echo "{\"hookSpecificOutput\": {\"hookEventName\": \"UserPromptSubmit\", \"additionalContext\": \"$DELEGATION_MSG\"}}"
  fi
  # Not opus — no-op, exit 0
  exit 0
fi

# Model unknown — inject anyway (safe on all models)
echo "{\"hookSpecificOutput\": {\"hookEventName\": \"UserPromptSubmit\", \"additionalContext\": \"$DELEGATION_MSG\"}}"
