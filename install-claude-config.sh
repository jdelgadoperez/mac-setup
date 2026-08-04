#!/bin/bash
# install-claude-config.sh — symlinks files from dotfiles/.claude/ into ~/.claude/
#
# The single installer for Claude Code config. It replaced install-claude.sh,
# which linked whole directories from a hand-maintained list of files, skills,
# and agent categories.
#
# ONE LINKING MODEL: per-file. Every regular file under dotfiles/.claude/ is
# discovered by walking the tree and linked individually. Do not add
# directory-level symlinks here or in any sibling script — mixing the two
# models is what corrupted 19 skills. Once ~/.claude/skills/X is a link to the
# source directory, a per-file pass computes a target inside it that resolves
# back to the source, and overwriting that target destroys the real file in
# the repo. The parent-directory guard in install_symlink() is the backstop,
# but the actual fix is never creating dir symlinks in the first place.
#
# Walking beats a curated list: install-claude.sh's list had drifted badly —
# it named 9 agent categories that no longer exist and only 1 of the 12 files
# in rules/, so most of rules/ was linked by this script anyway.
#
# Per-file also protects unrelated tooling: ~/.claude/commands/job/ links into
# the separate job-hunt repo. A directory-level model would clobber it.
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

SOURCE_DIR="$SCRIPT_DIR/dotfiles/.claude"
TARGET_DIR="$HOME/.claude"

# Warn if claude CLI is not installed, but still set up config
if ! command -v claude &> /dev/null; then
  printf "${YELLOW}Warning:${NC} claude CLI not found — install it via Homebrew or npm first\n"
  printf "  brew install claude\n"
  printf "Config will be symlinked now and will take effect once claude is installed.\n\n"
fi

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

  # If an ancestor directory of the target is already a symlink into the source
  # tree, the target path resolves to the source file itself. Linking here would
  # overwrite the real source file with a self-referential symlink. Skip it.
  #
  # Compare the resolved *parent* directories, not the target itself: once a
  # file has already been corrupted into a broken self-link, `[ -e "$target" ]`
  # is false (a dangling link fails -e) and a target-based check waves it
  # through, re-running the same destructive branch. The parent still resolves
  # correctly in that state, so this catches both the first pass and any rerun.
  if [ "$(realpath "$target_dir" 2>/dev/null)" = "$(realpath "$(dirname "$source")" 2>/dev/null)" ]; then
    if [ "$DRY_RUN" = "true" ]; then
      printf "${YELLOW}[DRY-RUN]${NC} Already reachable via linked parent: %s\n" "$(basename "$target")"
    else
      loginfo "Already reachable via linked parent: $(basename "$target")"
      (( count_skipped++ )) || true
    fi
    return
  fi

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

# ── Walk dotfiles/.claude/ and install every file ─────────────────────────────

loginstall "Claude Code config (symlink install)"

if [ ! -d "$SOURCE_DIR" ]; then
  logerror "Source directory not found: $SOURCE_DIR"
  exit 1
fi

while IFS= read -r -d '' source_file; do
  relative="${source_file#"$SOURCE_DIR/"}"
  target_file="$TARGET_DIR/$relative"
  install_symlink "$source_file" "$target_file"
done < <(
  find "$SOURCE_DIR" \
    \( -name '__pycache__' -o -name '.ruff_cache' -o -name '.pytest_cache' \
       -o -name 'node_modules' -o -name '.DS_Store' \) -prune -o \
    -type f -print0 | sort -z
)

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
if [ "$DRY_RUN" = "true" ]; then
  printf "${YELLOW}[DRY-RUN]${NC} No changes made.\n"
else
  printf "${GREEN}✓ Done:${NC} %s installed, %s skipped, %s updated\n" \
    "$count_installed" "$count_skipped" "$count_updated"
fi
