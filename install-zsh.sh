#!/bin/bash

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.sh"

# Check for Homebrew dependency on macOS
if [[ "$OSTYPE" == "darwin"* ]] && ! command -v brew &> /dev/null; then
  logerror "Homebrew is required but not installed"
  printf "Please run: ${GREEN}dorothy install brew${NC}"
  exit 1
fi

# Update and install Zsh if not already installed
if ! command -v zsh &> /dev/null; then
  loginfo "Zsh is not installed"
  loginstall "zsh"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install zsh
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sudo apt update
    sudo apt install -y zsh
  fi
  logsuccess "Zsh installed"
else
  loginfo "Zsh is already installed"
fi

# Change default shell to Zsh
if [ "$SHELL" != "$(which zsh)" ]; then
  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} Would change default shell to zsh\n"
  else
    loginfo "Changing default shell to zsh"
    chsh -s "$(which zsh)"
    logsuccess "Default shell changed to zsh"
  fi
else
  loginfo "Already using zsh as default shell"
fi

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} Would install Oh My Zsh\n"
  else
    loginstall "oh my zsh"
    sh -c "$(curl -fsSL $GITHUB_RAW/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    logsuccess "Oh My Zsh installed"
  fi
else
  loginfo "Oh My Zsh is already installed"
fi

# Clone plugins
loginstall "zsh plugins"

if [ "${DRY_RUN:-false}" = "true" ]; then
  printf "${YELLOW}[DRY-RUN]${NC} Would clone 7 Zsh plugins to %s\n" "$ZSH_CUSTOM/plugins/"
else
  REPO_ZSH_USERS="$GITHUB/zsh-users"

  gitclonesafely "$REPO_ZSH_USERS/zsh-autosuggestions.git" "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  gitclonesafely "$REPO_ZSH_USERS/zsh-completions.git" "$ZSH_CUSTOM/plugins/zsh-completions"
  gitclonesafely "$REPO_ZSH_USERS/zsh-history-substring-search.git" "$ZSH_CUSTOM/plugins/zsh-history-substring-search"
  gitclonesafely "$REPO_ZSH_USERS/zsh-syntax-highlighting.git" "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  gitclonesafely "$GITHUB/Aloxaf/fzf-tab" "$ZSH_CUSTOM/plugins/fzf-tab"
  gitclonesafely "$GITHUB/MichaelAquilina/zsh-you-should-use.git" "$ZSH_CUSTOM/plugins/you-should-use"
  gitclonesafely "$GITHUB/qoomon/zsh-lazyload" "$ZSH_CUSTOM/plugins/zsh-lazyload"

  logsuccess "Zsh plugins installed"
fi

# Symlink dotfiles and custom config files
createdirsafely "$DIR_ROOT/.config"

loginstall "setup zsh customizations"

# Define files to symlink
declare -A DOTFILE_LINKS=(
  ["$SCRIPT_DIR/dotfiles/.zshrc"]="$DIR_ROOT/.bash_profile"
  ["$SCRIPT_DIR/dotfiles/.zshrc"]="$DIR_ROOT/.bashrc"
  ["$SCRIPT_DIR/dotfiles/.zshrc"]="$DIR_ROOT/.zprofile"
  ["$SCRIPT_DIR/dotfiles/.zshrc"]="$DIR_ROOT/.zshrc"
  ["$SCRIPT_DIR/dotfiles/.config/starship.toml"]="$DIR_CONFIG/starship.toml"
)

# Custom zsh files to symlink
CUSTOM_ZSH_FILES=(
  "aliases.zsh"
  "development.zsh"
  "fzf-preview.sh"
  "git-tools.zsh"
  "history.zsh"
  "migration.zsh"
  "nerdtopia.zsh"
  "styles.zsh"
  "system-tools.zsh"
  "utilities.zsh"
  "zsh-syntax-highlighting.zsh"
)

# Symlink dotfiles
for source in "${!DOTFILE_LINKS[@]}"; do
  target="${DOTFILE_LINKS[$source]}"

  if [ "${DRY_RUN:-false}" = "true" ]; then
    printf "${YELLOW}[DRY-RUN]${NC} Would symlink: %s -> %s\n" "$(basename "$target")" "$source"
  else
    # Remove existing file or symlink
    if [ -e "$target" ] || [ -L "$target" ]; then
      rm -f "$target"
    fi

    # Create symlink
    ln -s "$source" "$target"
    loginfo "Symlinked: $(basename "$target")"
  fi
done

# Symlink custom zsh files
for file in "${CUSTOM_ZSH_FILES[@]}"; do
  source="$SCRIPT_DIR/custom-zsh/$file"
  target="$ZSH_CUSTOM/$file"

  if [ "${DRY_RUN:-false}" = "true" ]; then
    printf "${YELLOW}[DRY-RUN]${NC} Would symlink: %s -> %s\n" "$file" "$source"
  else
    # Remove existing file or symlink
    if [ -e "$target" ] || [ -L "$target" ]; then
      rm -f "$target"
    fi

    # Create symlink
    ln -s "$source" "$target"
    loginfo "Symlinked: $file"
  fi
done

logsuccess "Zsh customizations configured"

# Symlink Claude Code configuration
loginstall "setup Claude Code configuration"

CLAUDE_DOTFILES="$SCRIPT_DIR/dotfiles/.claude"
CLAUDE_DIR="$DIR_ROOT/.claude"

createdirsafely "$CLAUDE_DIR/commands"
createdirsafely "$CLAUDE_DIR/hooks"
createdirsafely "$CLAUDE_DIR/scripts"
createdirsafely "$CLAUDE_DIR/skills"
createdirsafely "$CLAUDE_DIR/agents"
createdirsafely "$CLAUDE_DIR/rules"

# Single-file symlinks
declare -A CLAUDE_FILE_LINKS=(
  ["$CLAUDE_DOTFILES/CLAUDE.md"]="$CLAUDE_DIR/CLAUDE.md"
  ["$CLAUDE_DOTFILES/settings.json"]="$CLAUDE_DIR/settings.json"
  ["$CLAUDE_DOTFILES/hooks/context-bar.js"]="$CLAUDE_DIR/hooks/context-bar.js"
  ["$CLAUDE_DOTFILES/hooks/context-monitor.js"]="$CLAUDE_DIR/hooks/context-monitor.js"
  ["$CLAUDE_DOTFILES/hooks/statusline-command.sh"]="$CLAUDE_DIR/hooks/statusline-command.sh"
  ["$CLAUDE_DOTFILES/scripts/review-tool.py"]="$CLAUDE_DIR/scripts/review-tool.py"
  ["$CLAUDE_DOTFILES/rules/context7.md"]="$CLAUDE_DIR/rules/context7.md"
)

# Review commands
REVIEW_COMMANDS=("code-review-core.md" "pr.md" "prs.md" "re-review-pr.md")

# Skills to symlink (each is a directory)
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

# Agent categories to symlink (each is a directory)
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

createdirsafely "$CLAUDE_DIR/commands/review"
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
