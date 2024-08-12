#!/bin/bash

source shared.sh

# Install Homebrew
if ! [ -x "$(command -v brew)" ]; then
  loginstall "homebrew"
  sh -c "$(curl -fsSL $GITHUB_RAW/Homebrew/install/HEAD/install.sh)"
fi

# Languages
loginstall "languages"
brew install go golangci-lint node python

# Term utils
loginstall "term utils"
brew install bat cmake eza fd fzf jq starship yq zoxide

# Tools
loginstall "dev tools"
brew install gnupg openssl fnm pyenv readline sqlite3 xz zlib zx
brew install docker docker-compose git-lfs gh 

# 1Password
loginstall "1password"
brew install --cask 1password 1password-cli
op signin

# Apps
loginstall "apps"
brew install --cask alfred
brew install --cask alt-tab
brew install --cask arc
brew install --cask background-music
brew install --cask discord
brew install --cask fantastical
brew install --cask gitkraken
brew install --cask gpg-suite-no-mail
brew install --cask keyclu
brew install --cask notion
brew install --cask notion-calendar
brew install --cask pocket-casts
brew install --cask rectangle
brew install --cask rocket
brew install --cask setapp 
brew install --cask slack
brew install --cask spotify
brew install --cask steam
brew install --cask surfshark
brew install --cask visual-studio-code
brew install --cask zoom
brew tap teamookla/speedtest
