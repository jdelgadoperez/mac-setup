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
#   --update    Safer update path for a machine that is already running and has
#               diverged: classifies each conflicting target (identical /
#               diverged / foreign-symlink / broken-symlink), auto-resolves
#               identical files with no prompt, shows a diff before prompting
#               on diverged files, always skips symlinks that point outside the
#               source tree, and reports unmanaged files at the end. Composes
#               with --dry-run (classify + show diffs, no changes, no prompts).
#               Mutually exclusive with --yes (auto-answering defeats the
#               point of reviewing diffs).

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
UPDATE_MODE=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --yes)     AUTO_YES=true ;;
    --update)  UPDATE_MODE=true ;;
  esac
done

if [ "$UPDATE_MODE" = "true" ] && [ "$AUTO_YES" = "true" ]; then
  printf "${RED}Error:${NC} --update and --yes are mutually exclusive — --update exists to show you\n" >&2
  printf "diffs before touching diverged files, and --yes auto-answers past that review.\n" >&2
  exit 1
fi

count_installed=0
count_skipped=0
count_updated=0
count_auto_resolved=0
count_backed_up=0
count_foreign_skipped=0

# Managed top-level dirs under ~/.claude that this script owns file-by-file.
# Used by the --update unmanaged-files report to scope its walk of TARGET_DIR.
MANAGED_TOP_LEVEL_DIRS=(hooks rules commands skills agents scripts)

# Paths (relative to TARGET_DIR) that install_symlink() processed this run.
# Populated during the main walk; consulted by the --update unmanaged report.
EXPECTED_RELATIVE_PATHS_FILE="$(mktemp)"
trap 'rm -f "$EXPECTED_RELATIVE_PATHS_FILE"' EXIT

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
      return
    elif [ -e "$target" ] || [ -L "$target" ]; then
      if [ "$UPDATE_MODE" = "true" ]; then
        update_symlink_conflict "$source" "$target"
      else
        printf "${YELLOW}[DRY-RUN]${NC} Would backup and overwrite: %s\n" "$(basename "$target")"
      fi
      return
    else
      printf "${YELLOW}[DRY-RUN]${NC} Would symlink: %s -> %s\n" "$target" "$source"
      return
    fi
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
    if [ "$UPDATE_MODE" = "true" ]; then
      update_symlink_conflict "$source" "$target"
      return
    fi

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

# ── --update mode: classify and resolve a conflicting target ──────────────────

# Resolves a symlink target and reports whether it points inside $SOURCE_DIR.
# Echoes "foreign" or "in-tree"; a dangling/unreadable link is treated as
# foreign so it is never touched by accident.
symlink_resolves_into_source() {
  local target="$1"
  local resolved
  resolved="$(realpath "$target" 2>/dev/null)" || true
  case "$resolved" in
    "$SOURCE_DIR"/*) echo "in-tree" ;;
    *)                echo "foreign" ;;
  esac
}

# Prints a diff of target (local) vs source (repo). $1 = "full" to print the
# whole diff, anything else truncates to 30 lines with a note.
print_update_diff() {
  local source="$1" target="$2" mode="$3"
  printf "${BLUE}--- target (local):${NC} %s\n" "$target"
  printf "${BLUE}+++ source (repo):${NC}  %s\n" "$source"
  if [ "$mode" = "full" ]; then
    diff -u "$target" "$source" || true
  else
    local diff_output
    diff_output="$(diff -u "$target" "$source" 2>&1 || true)"
    local line_count
    line_count="$(printf '%s\n' "$diff_output" | wc -l | tr -d ' ')"
    printf '%s\n' "$diff_output" | head -30
    if [ "$line_count" -gt 30 ]; then
      printf "${YELLOW}… diff truncated (%s lines total). Use 'd' to see the full diff.${NC}\n" "$line_count"
    fi
  fi
}

# Handles one conflicting target under --update: classifies it, then either
# auto-resolves (identical) or reports+skips (foreign-symlink) or prompts
# (diverged / broken-symlink) before delegating the actual filesystem change
# back to the same overwrite/backup logic used everywhere else.
update_symlink_conflict() {
  local source="$1"
  local target="$2"

  # foreign-symlink: points outside the source tree — never touch it.
  if [ -L "$target" ] && [ "$(symlink_resolves_into_source "$target")" = "foreign" ]; then
    if [ "$DRY_RUN" = "true" ]; then
      printf "${YELLOW}[DRY-RUN]${NC} Foreign symlink, leaving alone: %s -> %s\n" \
        "$(basename "$target")" "$(readlink "$target")"
    else
      loginfo "Foreign symlink, leaving alone: $(basename "$target") -> $(readlink "$target")"
    fi
    (( count_foreign_skipped++ )) || true
    return
  fi

  # broken-symlink: dangling in-tree-or-unresolvable link that isn't foreign
  # (i.e. it points at nothing, or realpath failed) — treat like diverged.
  local classification
  if [ -L "$target" ] && [ ! -e "$target" ]; then
    classification="broken-symlink"
  elif [ -f "$target" ] && cmp -s "$target" "$source"; then
    classification="identical"
  else
    classification="diverged"
  fi

  if [ "$classification" = "identical" ]; then
    if [ "$DRY_RUN" = "true" ]; then
      printf "${YELLOW}[DRY-RUN]${NC} Identical content, would auto-resolve to symlink: %s\n" "$(basename "$target")"
      return
    fi
    rm -f "$target"
    ln -s "$source" "$target"
    loginfo "Auto-resolved (identical content): $(basename "$target")"
    (( count_auto_resolved++ )) || true
    return
  fi

  # diverged or broken-symlink from here on: show diff (if there's content to
  # diff) and prompt, unless dry-run.
  if [ "$classification" = "diverged" ]; then
    printf "${YELLOW}Diverged:${NC} %s\n" "$target"
    print_update_diff "$source" "$target" "truncated"
  else
    printf "${YELLOW}Broken symlink:${NC} %s -> %s (target missing)\n" "$target" "$(readlink "$target")"
  fi

  if [ "$DRY_RUN" = "true" ]; then
    printf "${YELLOW}[DRY-RUN]${NC} Would prompt for: %s\n" "$(basename "$target")"
    return
  fi

  while true; do
    printf "  [s]kip / [o]verwrite / [b]ackup-then-overwrite / [d]iff again? "
    read -r answer
    case "$answer" in
      d|D)
        if [ "$classification" = "diverged" ]; then
          print_update_diff "$source" "$target" "full"
        else
          printf "${YELLOW}Broken symlink:${NC} %s -> %s (target missing, nothing to diff)\n" "$target" "$(readlink "$target")"
        fi
        continue
        ;;
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
        (( count_backed_up++ )) || true
        ;;
      *)
        loginfo "Skipped: $(basename "$target")"
        (( count_skipped++ )) || true
        ;;
    esac
    break
  done
}

# ── Walk dotfiles/.claude/ and install every file ─────────────────────────────

loginstall "Claude Code config (symlink install)"

if [ ! -d "$SOURCE_DIR" ]; then
  logerror "Source directory not found: $SOURCE_DIR"
  exit 1
fi

# Read the file list on fd 3, not stdin (fd 0): install_symlink() and
# update_symlink_conflict() prompt interactively via `read` on stdin when a
# conflict needs a decision. A `done < <(find ...)` here would redirect stdin
# for the whole loop body, so those nested `read`s would silently consume
# from the file-list stream instead of the terminal/pipe — the prompt would
# print but the answer would never arrive. Keeping the file list on fd 3
# leaves stdin free for the prompts.
while IFS= read -r -d '' -u 3 source_file; do
  relative="${source_file#"$SOURCE_DIR/"}"
  target_file="$TARGET_DIR/$relative"
  echo "$relative" >> "$EXPECTED_RELATIVE_PATHS_FILE"
  install_symlink "$source_file" "$target_file"
done 3< <(
  find "$SOURCE_DIR" \
    \( -name '__pycache__' -o -name '.ruff_cache' -o -name '.pytest_cache' \
       -o -name 'node_modules' -o -name '.DS_Store' \) -prune -o \
    -type f -print0 | sort -z
)

# ── --update mode: unmanaged files report ──────────────────────────────────────
#
# Report only — files under managed top-level dirs in ~/.claude with no
# corresponding source file. Split into real files (local-only, won't reach
# the other machine) vs symlinks into other repos (owned by other tooling).

count_unmanaged_real=0
count_unmanaged_foreign_symlink=0

if [ "$UPDATE_MODE" = "true" ]; then
  echo ""
  printf "${BLUE}── Unmanaged files under ~/.claude ──${NC}\n"

  unmanaged_real=()
  unmanaged_foreign_symlink=()
  unmanaged_broken_symlink=()

  for managed_dir in "${MANAGED_TOP_LEVEL_DIRS[@]}"; do
    managed_target_dir="$TARGET_DIR/$managed_dir"
    [ -d "$managed_target_dir" ] || continue

    while IFS= read -r -d '' existing_file; do
      relative="${existing_file#"$TARGET_DIR/"}"
      if grep -Fxq "$relative" "$EXPECTED_RELATIVE_PATHS_FILE"; then
        continue
      fi
      if [ -L "$existing_file" ]; then
        # Resolve before judging. A path-string comparison misclassifies every
        # directory symlink: the source tree holds skills/X/SKILL.md as a FILE,
        # while the install holds skills/X as a single LINK, so no expected
        # file path ever matches it. Resolving shows where the link actually
        # lands -- inside the source tree means managed, not foreign.
        resolved_link="$(realpath "$existing_file" 2>/dev/null || true)"
        case "$resolved_link" in
          "$SOURCE_DIR"/*|"$SOURCE_DIR")
            # Managed by this repo via a directory symlink. Nothing to report.
            ;;
          "")
            unmanaged_broken_symlink+=("$relative")
            ;;
          *)
            unmanaged_foreign_symlink+=("$relative -> $resolved_link")
            ;;
        esac
      else
        unmanaged_real+=("$relative")
      fi
    done < <(
      find "$managed_target_dir" \
        \( -name '__pycache__' -o -name '.ruff_cache' -o -name '.pytest_cache' \
           -o -name 'node_modules' -o -name '.DS_Store' \) -prune -o \
        -type f -print0 -o -type l -print0 | sort -z
    )
  done

  if [ "${#unmanaged_real[@]}" -eq 0 ]; then
    printf "  ${GREEN}No unmanaged real files.${NC}\n"
  else
    printf "  ${YELLOW}Real files (local-only, will not reach the other machine):${NC}\n"
    for path in "${unmanaged_real[@]}"; do
      printf "    %s\n" "$path"
    done
  fi

  if [ "${#unmanaged_foreign_symlink[@]}" -gt 0 ]; then
    printf "  ${BLUE}Symlinks into other repos (informational, owned by other tooling):${NC}\n"
    for path in "${unmanaged_foreign_symlink[@]}"; do
      printf "    %s\n" "$path"
    done
  fi

  if [ "${#unmanaged_broken_symlink[@]}" -gt 0 ]; then
    printf "  ${YELLOW}Broken symlinks (target no longer exists):${NC}\n"
    for path in "${unmanaged_broken_symlink[@]}"; do
      printf "    %s\n" "$path"
    done
  fi

  count_unmanaged_real="${#unmanaged_real[@]}"
  count_unmanaged_foreign_symlink="${#unmanaged_foreign_symlink[@]}"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
if [ "$DRY_RUN" = "true" ]; then
  printf "${YELLOW}[DRY-RUN]${NC} No changes made.\n"
elif [ "$UPDATE_MODE" = "true" ]; then
  printf "${GREEN}✓ Done:${NC} %s linked, %s auto-resolved-identical, %s overwritten, %s backed-up, %s skipped, %s foreign-skipped, %s unmanaged (%s real, %s foreign symlinks)\n" \
    "$count_installed" "$count_auto_resolved" "$(( count_updated - count_backed_up ))" \
    "$count_backed_up" "$count_skipped" "$count_foreign_skipped" \
    "$(( count_unmanaged_real + count_unmanaged_foreign_symlink ))" \
    "$count_unmanaged_real" "$count_unmanaged_foreign_symlink"
else
  printf "${GREEN}✓ Done:${NC} %s installed, %s skipped, %s updated\n" \
    "$count_installed" "$count_skipped" "$count_updated"
fi
