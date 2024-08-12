#!/bin/bash

source ./shared.sh

# Update and install Zsh if not already installed
if ! [ -x "$(command -v zsh)" ]; then
  echo "${BOLD_YELLOW}ZSH is not installed${NORMAL}"
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
  echo "${BOLD}Changing default shell to ${CYAN}zsh${NORMAL}"
  chsh -s "$(which zsh)"
fi

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  loginstall "oh my zsh"
  sh -c "$(curl -fsSL $GITHUB_RAW/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Clone plugins
loginstall "zsh plugins"
REPO_ZSH_USERS="$GITHUB/zsh-users/"
git clone $REPO_ZSH_USERS/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone $REPO_ZSH_USERS/zsh-completions.git $ZSH_CUSTOM/plugins/zsh-completions
git clone $REPO_ZSH_USERS/zsh-history-substring-search.git $ZSH_CUSTOM/plugins/zsh-history-substring-search
git clone $REPO_ZSH_USERS/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
git clone $GITHUB/Aloxaf/fzf-tab $ZSH_CUSTOM/plugins/fzf-tab
git clone $GITHUB/MichaelAquilina/zsh-you-should-use.git $ZSH_CUSTOM/plugins/you-should-use
git clone $GITHUB/qoomon/zsh-lazyload $ZSH_CUSTOM/plugins/zsh-lazyload

# Copy custom config files
cd ~/
createdirsafely ".config"

gh auth login

loginstall "zsh customizations"
gh gist clone $GIST_ROOT
cp $GIST_ROOT/.zshrc ~/.zshrc
cp $GIST_ROOT/starship.toml $CONFIG/starship.toml
rm -rf $GIST_ROOT

gh gist clone $GIST_CUSTOM
cp $GIST_CUSTOM/fzf-preview.sh $ZSH_CUSTOM/fzf-preview.sh
cp $GIST_CUSTOM/history.zsh $ZSH_CUSTOM/history.zsh
cp $GIST_CUSTOM/custom.zsh $ZSH_CUSTOM/custom.zsh
cp $GIST_CUSTOM/nerdtopia.zsh $ZSH_CUSTOM/nerdtopia.zsh
rm -rf $GIST_CUSTOM
