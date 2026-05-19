INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
[ "$TOOL" != "Bash" ] && exit 0
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Note: `git -C` blocking lives in cd-git-allow.sh (personal override of the
# shared hook). bash-guard owns agent-routing rules only — keeps each hook
# with one job.

# Optional: Block direct Jira CLI operations if you use a dedicated Jira agent.
# Customize the agent name and CLI pattern to match your setup.
# Example (uncomment and adapt):
# AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')
# if [ "$AGENT_TYPE" != "your-jira-agent" ] && echo "$CMD" | grep -qE '^acli\b|curl.*atlassian\.net|curl.*jira'; then
#   echo '{"decision":"block","reason":"Use your Jira agent for all Jira operations."}'
#   exit 0
# fi

# Auto-approve cd commands (unless paired with destructive ops)
if echo "$CMD" | grep -qE '^cd\s+' && ! echo "$CMD" | grep -qE '(rm\s+-rf|git\s+push\s+--force|git\s+reset\s+--hard)'; then
  echo '{"decision":"approve"}'
  exit 0
fi

exit 0
