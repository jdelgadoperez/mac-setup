#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.sh"

# Update and install Zsh if not already installed
if ! [ -x "$(command -v zsh)" ]; then
  printf "${YELLOW}ZSH is not installed${NC}\n"
  loginstall "zsh"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # Install Zsh on macOS
    brew install zsh
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Install Zsh on Linux
    sudo apt update
    sudo apt install -y zsh
  fi
fi

# Change default shell to Zsh
if [ "$SHELL" != "$(which zsh)" ]; then
  printf "${BLUE}Changing default shell to ${CYAN}zsh${NC}\n"
  chsh -s "$(which zsh)"
fi

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  loginstall "oh my zsh"
  sh -c "$(curl -fsSL $GITHUB_RAW/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Clone plugins
loginstall "zsh plugins"
REPO_ZSH_USERS="$GITHUB/zsh-users"

gitclonesafely "$REPO_ZSH_USERS/zsh-autosuggestions.git" "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
gitclonesafely "$REPO_ZSH_USERS/zsh-completions.git" "$ZSH_CUSTOM/plugins/zsh-completions"
gitclonesafely "$REPO_ZSH_USERS/zsh-history-substring-search.git" "$ZSH_CUSTOM/plugins/zsh-history-substring-search"
gitclonesafely "$REPO_ZSH_USERS/zsh-syntax-highlighting.git" "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
gitclonesafely "$GITHUB/Aloxaf/fzf-tab" "$ZSH_CUSTOM/plugins/fzf-tab"
gitclonesafely "$GITHUB/MichaelAquilina/zsh-you-should-use.git" "$ZSH_CUSTOM/plugins/you-should-use"
gitclonesafely "$GITHUB/qoomon/zsh-lazyload" "$ZSH_CUSTOM/plugins/zsh-lazyload"

# Copy custom config files
createdirsafely "$DIR_ROOT/.config"

loginstall "setup zsh customizations"
cp "$SCRIPT_DIR/dotfiles/.zshrc" "$DIR_ROOT/.bash_profile"
cp "$SCRIPT_DIR/dotfiles/.zshrc" "$DIR_ROOT/.bashrc"
cp "$SCRIPT_DIR/dotfiles/.zshrc" "$DIR_ROOT/.zprofile"
cp "$SCRIPT_DIR/dotfiles/.zshrc" "$DIR_ROOT/.zshrc"
cp "$SCRIPT_DIR/dotfiles/.config/starship.toml" "$DIR_CONFIG/starship.toml"
cp "$SCRIPT_DIR/custom-zsh/aliases.zsh" "$ZSH_CUSTOM/aliases.zsh"
cp "$SCRIPT_DIR/custom-zsh/development.zsh" "$ZSH_CUSTOM/development.zsh"
cp "$SCRIPT_DIR/custom-zsh/fzf-preview.sh" "$ZSH_CUSTOM/fzf-preview.sh"
cp "$SCRIPT_DIR/custom-zsh/git-tools.zsh" "$ZSH_CUSTOM/git-tools.zsh"
cp "$SCRIPT_DIR/custom-zsh/history.zsh" "$ZSH_CUSTOM/history.zsh"
cp "$SCRIPT_DIR/custom-zsh/migration.zsh" "$ZSH_CUSTOM/migration.zsh"
cp "$SCRIPT_DIR/custom-zsh/nerdtopia.zsh" "$ZSH_CUSTOM/nerdtopia.zsh"
cp "$SCRIPT_DIR/custom-zsh/styles.zsh" "$ZSH_CUSTOM/styles.zsh"
cp "$SCRIPT_DIR/custom-zsh/system-tools.zsh" "$ZSH_CUSTOM/system-tools.zsh"
cp "$SCRIPT_DIR/custom-zsh/utilities.zsh" "$ZSH_CUSTOM/utilities.zsh"
cp "$SCRIPT_DIR/custom-zsh/zsh-syntax-highlighting.zsh" "$ZSH_CUSTOM/zsh-syntax-highlighting.zsh"
