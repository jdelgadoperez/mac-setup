#!/bin/bash

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.sh"

# Warn if claude CLI is not installed, but still set up config
if ! command -v claude &> /dev/null; then
  printf "${YELLOW}Warning:${NC} claude CLI not found — install it via Homebrew or npm first\n"
  printf "  brew install claude\n"
  printf "Config will be symlinked now and will take effect once claude is installed.\n\n"
fi

loginstall "setup Claude Code configuration"

CLAUDE_DOTFILES="$SCRIPT_DIR/dotfiles/.claude"
CLAUDE_DIR="$DIR_ROOT/.claude"

createdirsafely "$CLAUDE_DIR/commands"
createdirsafely "$CLAUDE_DIR/commands/review"
createdirsafely "$CLAUDE_DIR/hooks"
createdirsafely "$CLAUDE_DIR/scripts"
createdirsafely "$CLAUDE_DIR/skills"
createdirsafely "$CLAUDE_DIR/agents"
createdirsafely "$CLAUDE_DIR/rules"

declare -A CLAUDE_FILE_LINKS=(
  ["$CLAUDE_DOTFILES/CLAUDE.md"]="$CLAUDE_DIR/CLAUDE.md"
  ["$CLAUDE_DOTFILES/settings.json"]="$CLAUDE_DIR/settings.json"
  ["$CLAUDE_DOTFILES/hooks/context-bar.js"]="$CLAUDE_DIR/hooks/context-bar.js"
  ["$CLAUDE_DOTFILES/hooks/context-monitor.js"]="$CLAUDE_DIR/hooks/context-monitor.js"
  ["$CLAUDE_DOTFILES/hooks/statusline-command.sh"]="$CLAUDE_DIR/hooks/statusline-command.sh"
  ["$CLAUDE_DOTFILES/scripts/review-tool.py"]="$CLAUDE_DIR/scripts/review-tool.py"
  ["$CLAUDE_DOTFILES/rules/context7.md"]="$CLAUDE_DIR/rules/context7.md"
)

REVIEW_COMMANDS=("code-review-core.md" "pr.md" "prs.md" "re-review-pr.md")

CLAUDE_SKILLS=(
  "api-documenter"
  "bug-swarm"
  "code-reviewer"
  "context7"
  "dependency-auditor"
  "find-docs"
  "git-commit-helper"
  "multi-commit"
  "readme-updater"
  "review-prs"
  "secret-scanner"
  "security-auditor"
  "ship"
  "test-generator"
)

CLAUDE_AGENT_CATEGORIES=(
  "ai"
  "architecture"
  "backend"
  "developer-experience"
  "frontend"
  "infrastructure"
  "language-specialists"
  "quality"
  "security"
)

symlink_claude_entry() {
  local source="$1"
  local target="$2"

  if [ "${DRY_RUN:-false}" = "true" ]; then
    printf "${YELLOW}[DRY-RUN]${NC} Would symlink: %s -> %s\n" "$target" "$source"
  else
    if [ -e "$target" ] || [ -L "$target" ]; then
      rm -rf "$target"
    fi
    ln -s "$source" "$target"
    loginfo "Symlinked: $(basename "$target")"
  fi
}

for source in "${!CLAUDE_FILE_LINKS[@]}"; do
  symlink_claude_entry "$source" "${CLAUDE_FILE_LINKS[$source]}"
done

for cmd in "${REVIEW_COMMANDS[@]}"; do
  symlink_claude_entry "$CLAUDE_DOTFILES/commands/review/$cmd" "$CLAUDE_DIR/commands/review/$cmd"
done

for skill in "${CLAUDE_SKILLS[@]}"; do
  symlink_claude_entry "$CLAUDE_DOTFILES/skills/$skill" "$CLAUDE_DIR/skills/$skill"
done

for category in "${CLAUDE_AGENT_CATEGORIES[@]}"; do
  symlink_claude_entry "$CLAUDE_DOTFILES/agents/$category" "$CLAUDE_DIR/agents/$category"
done

logsuccess "Claude Code configuration symlinked"
