#!/usr/bin/env bash
# manage-status.sh — list all agents, skills, and commands with enabled/disabled status
# No arguments. Outputs three formatted tables + a summary line.

set -euo pipefail

AGENTS_DIR="${HOME}/.claude/agents"
SKILLS_DIR="${HOME}/.claude/skills"
COMMANDS_DIR="${HOME}/.claude/commands"

NAME_WIDTH=48
STATUS_WIDTH=8
SEPARATOR=$(printf '%*s' "${NAME_WIDTH}" '' | tr ' ' '-')"  "$(printf '%*s' "${STATUS_WIDTH}" '' | tr ' ' '-')

# ── Agents ────────────────────────────────────────────────────────────────────
# Collect all stems (strip .md / .md.disabled), then dedup — if both exist,
# treat as enabled (the .md wins).

declare -A agent_status

for f in "${AGENTS_DIR}"/*.md "${AGENTS_DIR}"/*.md.disabled; do
  [[ -e "${f}" ]] || continue
  base=$(basename "${f}")
  name="${base%.md.disabled}"
  name="${name%.md}"
  # If we already recorded this name as enabled, don't overwrite.
  if [[ "${agent_status[${name}]+_}" ]]; then
    [[ "${agent_status[${name}]}" == "enabled" ]] && continue
  fi
  if [[ "${f}" == *.md.disabled ]]; then
    agent_status["${name}"]="disabled"
  else
    agent_status["${name}"]="enabled"
  fi
done

agent_enabled=0
agent_disabled=0

echo "=== Agents ==="
printf "%-${NAME_WIDTH}s  %s\n" "Name" "Status"
echo "${SEPARATOR}"

while IFS= read -r name; do
  status="${agent_status[${name}]}"
  printf "%-${NAME_WIDTH}s  %s\n" "${name}" "${status}"
  if [[ "${status}" == "enabled" ]]; then
    (( agent_enabled++ )) || true
  else
    (( agent_disabled++ )) || true
  fi
done < <(printf '%s\n' "${!agent_status[@]}" | sort)

echo ""

# ── Skills ────────────────────────────────────────────────────────────────────

skill_enabled=0
skill_disabled=0

echo "=== Skills ==="
printf "%-${NAME_WIDTH}s  %s\n" "Name" "Status"
echo "${SEPARATOR}"

declare -A skill_status

for dir in "${SKILLS_DIR}"/*/; do
  [[ -d "${dir}" ]] || continue
  name=$(basename "${dir}")
  if [[ -f "${dir}SKILL.md" ]]; then
    skill_status["${name}"]="enabled"
  elif [[ -f "${dir}SKILL.md.disabled" ]]; then
    skill_status["${name}"]="disabled"
  fi
done

while IFS= read -r name; do
  status="${skill_status[${name}]}"
  printf "%-${NAME_WIDTH}s  %s\n" "${name}" "${status}"
  if [[ "${status}" == "enabled" ]]; then
    (( skill_enabled++ )) || true
  else
    (( skill_disabled++ )) || true
  fi
done < <(printf '%s\n' "${!skill_status[@]}" | sort)

echo ""

# ── Commands ──────────────────────────────────────────────────────────────────

cmd_enabled=0
cmd_disabled=0

echo "=== Commands ==="
printf "%-${NAME_WIDTH}s  %s\n" "Name" "Status"
echo "${SEPARATOR}"

declare -A cmd_status

while IFS= read -r f; do
  [[ -e "${f}" ]] || continue
  rel="${f#${COMMANDS_DIR}/}"
  name="${rel%.md.disabled}"
  name="${name%.md}"
  name="${name//\//:}"
  if [[ "${f}" == *.md.disabled ]]; then
    # Only record disabled if not already marked enabled
    if [[ ! "${cmd_status[${name}]+_}" ]] || [[ "${cmd_status[${name}]}" != "enabled" ]]; then
      cmd_status["${name}"]="disabled"
    fi
  else
    cmd_status["${name}"]="enabled"
  fi
done < <(find "${COMMANDS_DIR}" -path "*/manage/*" -prune -o \( -name "*.md" -o -name "*.md.disabled" \) -print | sort)

while IFS= read -r name; do
  status="${cmd_status[${name}]}"
  printf "%-${NAME_WIDTH}s  %s\n" "${name}" "${status}"
  if [[ "${status}" == "enabled" ]]; then
    (( cmd_enabled++ )) || true
  else
    (( cmd_disabled++ )) || true
  fi
done < <(printf '%s\n' "${!cmd_status[@]}" | sort)

echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
total_agents=$(( agent_enabled + agent_disabled ))
total_skills=$(( skill_enabled + skill_disabled ))
total_cmds=$(( cmd_enabled + cmd_disabled ))

echo "${total_agents} agents (${agent_enabled} enabled, ${agent_disabled} disabled) · ${total_skills} skills (${skill_enabled} enabled, ${skill_disabled} disabled) · ${total_cmds} commands (${cmd_enabled} enabled, ${cmd_disabled} disabled)"
