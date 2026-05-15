#!/usr/bin/env bash
# manage-toggle.sh — enable or disable agents, skills, and commands
# Usage: manage-toggle.sh <enable|disable> <name1> [name2 ...]

set -euo pipefail

AGENTS_DIR="${HOME}/.claude/agents"
SKILLS_DIR="${HOME}/.claude/skills"
COMMANDS_DIR="${HOME}/.claude/commands"

# ── Argument validation ───────────────────────────────────────────────────────

if [[ $# -lt 1 ]]; then
  echo "Usage: manage-toggle.sh <enable|disable> <name1> [name2 ...]" >&2
  exit 1
fi

mode="${1}"

if [[ "${mode}" != "enable" && "${mode}" != "disable" ]]; then
  echo "Error: mode must be 'enable' or 'disable', got: ${mode}" >&2
  exit 1
fi

if [[ $# -lt 2 ]]; then
  echo "Usage: manage-toggle.sh <enable|disable> <name1> [name2 ...]" >&2
  exit 1
fi

shift  # remove mode, remaining args are names

# ── Helpers ───────────────────────────────────────────────────────────────────

# Normalise a raw token: strip trailing .md.disabled or .md, trim whitespace.
normalise_name() {
  local raw="${1}"
  raw="${raw//,/ }"   # treat embedded commas as spaces (extra safety)
  raw="${raw#"${raw%%[![:space:]]*}"}"  # ltrim
  raw="${raw%"${raw##*[![:space:]]}"}"  # rtrim
  raw="${raw%.md.disabled}"
  raw="${raw%.md}"
  printf '%s' "${raw}"
}

toggle_item() {
  local name
  name=$(normalise_name "${1}")

  [[ -z "${name}" ]] && return

  # ── Agent ──────────────────────────────────────────────────────────────────
  local agent_enabled="${AGENTS_DIR}/${name}.md"
  local agent_disabled="${AGENTS_DIR}/${name}.md.disabled"

  if [[ -f "${agent_enabled}" || -f "${agent_disabled}" ]]; then
    if [[ "${mode}" == "enable" ]]; then
      if [[ -f "${agent_disabled}" ]]; then
        mv "${agent_disabled}" "${agent_enabled}"
        echo "enabled (agent): ${name}"
      else
        echo "already enabled: ${name}"
      fi
    else
      if [[ -f "${agent_enabled}" ]]; then
        mv "${agent_enabled}" "${agent_disabled}"
        echo "disabled (agent): ${name}"
      else
        echo "already disabled: ${name}"
      fi
    fi
    return
  fi

  # ── Skill ──────────────────────────────────────────────────────────────────
  local skill_enabled="${SKILLS_DIR}/${name}/SKILL.md"
  local skill_disabled="${SKILLS_DIR}/${name}/SKILL.md.disabled"

  if [[ -f "${skill_enabled}" || -f "${skill_disabled}" ]]; then
    if [[ "${mode}" == "enable" ]]; then
      if [[ -f "${skill_disabled}" ]]; then
        mv "${skill_disabled}" "${skill_enabled}"
        echo "enabled (skill): ${name}"
      else
        echo "already enabled: ${name}"
      fi
    else
      if [[ -f "${skill_enabled}" ]]; then
        mv "${skill_enabled}" "${skill_disabled}"
        echo "disabled (skill): ${name}"
      else
        echo "already disabled: ${name}"
      fi
    fi
    return
  fi

  # ── Command ────────────────────────────────────────────────────────────────
  # Convert colons to slashes for filesystem path
  local cmd_path="${name//:/\/}"
  local cmd_enabled="${COMMANDS_DIR}/${cmd_path}.md"
  local cmd_disabled="${COMMANDS_DIR}/${cmd_path}.md.disabled"

  if [[ -f "${cmd_enabled}" || -f "${cmd_disabled}" ]]; then
    if [[ "${mode}" == "enable" ]]; then
      if [[ -f "${cmd_disabled}" ]]; then
        mv "${cmd_disabled}" "${cmd_enabled}"
        echo "enabled (command): ${name}"
      else
        echo "already enabled: ${name}"
      fi
    else
      if [[ -f "${cmd_enabled}" ]]; then
        mv "${cmd_enabled}" "${cmd_disabled}"
        echo "disabled (command): ${name}"
      else
        echo "already disabled: ${name}"
      fi
    fi
    return
  fi

  # ── Not found ──────────────────────────────────────────────────────────────
  echo "not found: ${name}"
}

# ── Process all names ─────────────────────────────────────────────────────────
# Split each argument on commas and whitespace to handle e.g. "foo, bar,baz"
for raw_arg in "$@"; do
  # Split on comma, then iterate tokens
  IFS=',' read -ra comma_parts <<< "${raw_arg}"
  for part in "${comma_parts[@]}"; do
    # Split on whitespace within each part
    read -ra space_parts <<< "${part}"
    for token in "${space_parts[@]}"; do
      [[ -z "${token}" ]] && continue
      toggle_item "${token}"
    done
  done
done

echo ""
echo "Changes take effect in the next session."
