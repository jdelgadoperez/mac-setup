#!/bin/bash
# @hook-event: PreToolUse
# @hook-command: echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"STOP. Before proceeding with this push, you MUST run /pre-push-checks skill NOW. Do not push until checks pass. If you have already run /pre-push-checks in this session and all checks passed, you may proceed."}}'
# @hook-matcher: Bash(git push*)
# @description: Reminds to run /pre-push-checks before git push

# This hook is a simple reminder — the actual checks are in the pre-push-checks skill.
# The hook-command is an inline echo, not this script.
# Uses JSON output with additionalContext so the model actually sees the reminder.
