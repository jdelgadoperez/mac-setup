#!/usr/bin/env bash
# PreToolUse hook: hard-blocks outbound (externally-visible) content that leaks
# a local filesystem path or this machine's identity.
#
# WHY: repeatedly, PR review bodies / Slack messages / Jira-Linear comments /
# Notion pages have shipped strings like
#   "full working in /Users/jessdelgadoperez/projects/drata/_reports/..."
# That path means nothing to an external reader and exposes the local machine
# layout. This gate stops the post before it lands, so the fix isn't "remember
# to strip it every time."
#
# SCOPE (parent-session, main-thread):
#   - Bash commands that publish (gh pr/issue/api, acli, linear-cli, curl,
#     slack_send_message)
#   - main-thread MCP write tools (Slack / Notion / Linear connectors)
# Also fires inside subagents (seen blocking a linear:linear subagent on
# 2026-10-22), so it covers posts from the github-cli and linear agents too.
# A post tool's own executable path is stripped before scanning; see
# strip_program_paths in the detector.
#
# Blocking is signaled via {"decision":"block"} JSON on stdout, matching the
# other guards in this directory. The regex work lives in the sibling Python
# detector so it can be unit-tested; this wrapper is just plumbing.

INPUT=$(cat)

DETECT=$(printf '%s' "$INPUT" | python3 "$HOME/.claude/scripts/outbound-path-guard.py" 2>/dev/null)
RC=$?

case "$RC" in
  0)
    exit 0
    ;;
  2)
    REASON="Blocked: this outbound content contains local filesystem path(s) or this machine's identity, which mean nothing to an external reader and expose your local setup. Rewrite to describe the artifact in plain words (e.g. \"the readiness report\") instead of pasting a path, then retry.

Offending strings:
$DETECT"
    jq -nc --arg r "$REASON" '{decision:"block", reason:$r}'
    exit 0
    ;;
  3)
    REASON="Blocked (fail-closed): $DETECT"
    jq -nc --arg r "$REASON" '{decision:"block", reason:$r}'
    exit 0
    ;;
  *)
    # Detector errored unexpectedly — do not block on infrastructure failure.
    exit 0
    ;;
esac
