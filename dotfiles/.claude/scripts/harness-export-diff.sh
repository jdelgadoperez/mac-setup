#!/bin/bash
# harness-export-diff.sh — gap analysis between the live ~/.claude harness and
# the portable mac-setup export. Read-only: writes a markdown report, mutates
# nothing.
#
# For each artifact in the live categories (skills, rules, hooks, scripts,
# commands) it determines:
#   - coupling   : coupled | clean        (via classify-harness-artifact.sh)
#   - export     : exported | missing     (name-presence in baseline)
# and buckets into:
#   PORTABLE+MISSING   clean & not exported   -> candidates to port
#   COUPLED            drata-coupled          -> leave in place
#   ALREADY-EXPORTED   present in baseline
# It also flags DANGLING refs: exported hooks/scripts whose referenced skill or
# command is absent from the baseline.
#
# Usage: harness-export-diff.sh [--baseline <dir>] [--out <report.md>]
# Defaults: baseline = ~/projects/mac-setup/dotfiles/.claude
#           out      = /tmp/harness-export-audit/report.md

set -o pipefail

LIVE="$HOME/.claude"
BASELINE="$HOME/projects/mac-setup/dotfiles/.claude"
OUT="/tmp/harness-export-audit/report.md"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLASSIFY="$SCRIPT_DIR/classify-harness-artifact.sh"

while [ $# -gt 0 ]; do
  case "$1" in
    --baseline) BASELINE="$2"; shift 2 ;;
    --out)      OUT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -d "$BASELINE" ] || { echo "baseline dir not found: $BASELINE" >&2; exit 2; }
[ -x "$CLASSIFY" ] || { echo "classifier not executable: $CLASSIFY" >&2; exit 2; }
mkdir -p "$(dirname "$OUT")"

# Category -> live unit granularity. Skills are dirs; the rest are files.
CATEGORIES="skills rules hooks scripts commands"

# baseline membership test by basename (export reorganizes paths, so match on
# the leaf name, not the relative path).
baseline_has() {
  local name="$1"
  find "$BASELINE" -mindepth 1 \( -name "$name" -o -name "${name}.md" -o -name "${name}.sh" \) 2>/dev/null | grep -q .
}

portable_missing=""
coupled=""
already=""

classify_unit() {
  # $1 = display name, $2 = path to classify
  local name="$1" path="$2" status row
  status="$("$CLASSIFY" "$path" | cut -f1)"
  if [ "$status" = "coupled" ]; then
    coupled+="| \`$name\` | $3 | coupled |"$'\n'
  elif baseline_has "$name"; then
    already+="| \`$name\` | $3 | exported |"$'\n'
  else
    portable_missing+="| \`$name\` | $3 | **PORT** |"$'\n'
  fi
}

for cat in $CATEGORIES; do
  dir="$LIVE/$cat"
  [ -d "$dir" ] || continue
  if [ "$cat" = "skills" ]; then
    while IFS= read -r d; do
      [ -z "$d" ] && continue
      classify_unit "$(basename "$d")" "$d" "$cat"
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  else
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      case "$f" in *.new|*.bak*|*.DS_Store) continue ;; esac
      classify_unit "$(basename "$f")" "$f" "$cat"
    done < <(find "$dir" -type f 2>/dev/null | sort)
  fi
done

# ── Dangling reference detection ──────────────────────────────────────────────
# Exported hook/script that loads a skill or calls a command which the baseline
# did not ship.
dangling=""
while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  # extract candidate skill/command names referenced in the file
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    baseline_has "$name" || dangling+="| \`$(basename "$ref")\` | references \`$name\` (not in export) |"$'\n'
  done < <(grep -hoE 'load-skill-[a-z0-9-]+|skills/[a-z0-9-]+|/manage:[a-z]+|commands/[a-z/-]+' "$ref" 2>/dev/null \
            | sed -E 's#load-skill-##; s#skills/##; s#/manage:#manage-#; s#commands/##; s#/.*##' | sort -u)
done < <(find "$BASELINE/hooks" "$BASELINE/scripts" -type f 2>/dev/null)
dangling="$(printf '%s' "$dangling" | sort -u)"

# ── Emit report ───────────────────────────────────────────────────────────────
{
  echo "# Harness Export Audit"
  echo
  echo "- Live: \`$LIVE\`"
  echo "- Baseline: \`$BASELINE\`"
  echo
  echo "## Portable + missing (port candidates)"
  echo
  echo "| Artifact | Category | Action |"
  echo "|---|---|---|"
  printf '%s' "$portable_missing"
  echo
  echo "## Coupled (leave in place)"
  echo
  echo "| Artifact | Category | Status |"
  echo "|---|---|---|"
  printf '%s' "$coupled"
  echo
  echo "## Already exported"
  echo
  echo "| Artifact | Category | Status |"
  echo "|---|---|---|"
  printf '%s' "$already"
  echo
  echo "## Dangling references in export"
  echo
  if [ -n "$dangling" ]; then
    echo "| Exported file | Problem |"
    echo "|---|---|"
    printf '%s\n' "$dangling"
  else
    echo "_None detected._"
  fi
} > "$OUT"

echo "$OUT"
