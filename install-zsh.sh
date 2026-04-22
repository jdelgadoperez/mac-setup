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
