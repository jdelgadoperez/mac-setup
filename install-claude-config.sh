#!/bin/bash
# install-claude-config.sh — symlinks files from claude-config/ into ~/.claude/
#
# Idempotent: existing matching symlinks are left in place; conflicting
# non-symlink files trigger an interactive prompt (skip / overwrite /
# backup-then-overwrite).
#
# Flags:
#   --dry-run   Show what would happen without making any changes
#   --yes       Auto-answer "backup-then-overwrite" for all conflicts

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.sh"

SOURCE_DIR="$SCRIPT_DIR/claude-config"
TARGET_DIR="$HOME/.claude"

DRY_RUN=false
AUTO_YES=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --yes)     AUTO_YES=true ;;
  esac
done

count_installed=0
count_skipped=0
count_updated=0

# ── Core symlink helper ────────────────────────────────────────────────────────

install_symlink() {
  local source="$1"
  local target="$2"
  local target_dir
  target_dir="$(dirname "$target")"

  if [ "$DRY_RUN" = "true" ]; then
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
      printf "${YELLOW}[DRY-RUN]${NC} Already linked: %s\n" "$(basename "$target")"
    elif [ -e "$target" ] || [ -L "$target" ]; then
      printf "${YELLOW}[DRY-RUN]${NC} Would backup and overwrite: %s\n" "$(basename "$target")"
    else
      printf "${YELLOW}[DRY-RUN]${NC} Would symlink: %s -> %s\n" "$target" "$source"
    fi
    return
  fi

  # Ensure parent directory exists
  if [ ! -d "$target_dir" ]; then
    printf "${BLUE}Create directory: ${GREEN}%s${NC}\n" "$target_dir"
    mkdir -p "$target_dir"
  fi

  # Already a correct symlink — skip
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    loginfo "Already linked: $(basename "$target")"
    (( count_skipped++ )) || true
    return
  fi

  # Conflict: target exists but is not the right symlink
  if [ -e "$target" ] || [ -L "$target" ]; then
    if [ "$AUTO_YES" = "true" ]; then
      answer="b"
    else
      printf "${YELLOW}Conflict:${NC} %s already exists (not a symlink to source)\n" "$target"
      printf "  [s]kip / [o]verwrite / [b]ackup-then-overwrite? "
      read -r answer
    fi

    case "$answer" in
      o|O)
        rm -rf "$target"
        ln -s "$source" "$target"
        loginfo "Overwritten: $(basename "$target")"
        (( count_updated++ )) || true
        ;;
      b|B)
        local backup
        backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
        mv "$target" "$backup"
        ln -s "$source" "$target"
        loginfo "Backed up to $(basename "$backup"), linked: $(basename "$target")"
        (( count_updated++ )) || true
        ;;
      *)
        loginfo "Skipped: $(basename "$target")"
        (( count_skipped++ )) || true
        ;;
    esac
    return
  fi

  # Clean install
  ln -s "$source" "$target"
  loginfo "Linked: $(basename "$target")"
  (( count_installed++ )) || true
}

# ── Walk claude-config/ and install every file ────────────────────────────────

loginstall "Claude Code config (symlink install)"

if [ ! -d "$SOURCE_DIR" ]; then
  logerror "Source directory not found: $SOURCE_DIR"
  exit 1
fi

while IFS= read -r -d '' source_file; do
  relative="${source_file#"$SOURCE_DIR/"}"
  target_file="$TARGET_DIR/$relative"
  install_symlink "$source_file" "$target_file"
done < <(find "$SOURCE_DIR" -type f -print0 | sort -z)

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
if [ "$DRY_RUN" = "true" ]; then
  printf "${YELLOW}[DRY-RUN]${NC} No changes made.\n"
else
  printf "${GREEN}✓ Done:${NC} %s installed, %s skipped, %s updated\n" \
    "$count_installed" "$count_skipped" "$count_updated"
fi
