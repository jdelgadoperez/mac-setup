#!/bin/bash
# classify-harness-artifact.sh — classify a single ~/.claude artifact as
# Drata-COUPLED or CLEAN (portable) based on content markers.
#
# Usage:   classify-harness-artifact.sh <path-to-file-or-dir>
# Output:  one line: "<status>\t<path>\t<matched-markers>"
#          status ∈ { coupled, clean }
#
# For a directory (e.g. a skill folder), every file inside is scanned and the
# dir is "coupled" if ANY file matches a marker. This is intentionally a coarse,
# mechanical signal — judgment (borderline cases, de-coupling) stays with a human.
#
# Exit code: 0 = clean, 1 = coupled, 2 = bad usage.

set -o pipefail

target="$1"
if [ -z "$target" ] || [ ! -e "$target" ]; then
  echo "usage: classify-harness-artifact.sh <path>" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OWNERSHIP="$SCRIPT_DIR/harness-export-ownership.txt"
base="$(basename "$target")"

# Self-exclusion: this tooling references the marker regex and would otherwise
# flag itself. It is itself portable.
case "$base" in
  classify-harness-artifact.sh|harness-export-diff.sh|harness-export-ownership.txt)
    printf 'clean\t%s\t-\n' "$target"; exit 0 ;;
esac

# Override list: semantic/convention/group coupling that grep cannot see.
if [ -f "$OWNERSHIP" ] && grep -qxF "$base" <(grep -vE '^\s*#|^\s*$' "$OWNERSHIP"); then
  printf 'coupled\t%s\t(ownership-list)\n' "$target"; exit 1
fi

# Drata-coupling markers. Word-bounded where a bare token would over-match.
# Kept deliberately specific: these strings essentially never appear in a
# genuinely generic Claude Code artifact.
MARKERS='drata|dmcp|\bacli\b|\bdcli\b|looking[- ]?glass|tierzero|buggysmalls|beacon-(api|core|ui)|multiverse|jira-project-config|slack-project-config|github-project-config|/projects/drata/|drata-cli|scalable.?sync|RELEASE_[A-Z_]*IDENTITY|temporal.*determinism'

if [ -d "$target" ]; then
  matches="$(grep -rIioE "$MARKERS" "$target" 2>/dev/null | sed 's/.*://' | sort -u | paste -sd, -)"
else
  matches="$(grep -IioE "$MARKERS" "$target" 2>/dev/null | sort -u | paste -sd, -)"
fi

if [ -n "$matches" ]; then
  printf 'coupled\t%s\t%s\n' "$target" "$matches"
  exit 1
else
  printf 'clean\t%s\t-\n' "$target"
  exit 0
fi
