#!/bin/bash

###############################################################################
# Homebrew setup                                                              #
# ref: https://github.com/mathiasbynens/dotfiles/blob/master/brew.sh          #
###############################################################################

source ./shared.sh

INSTALL_APPS="${1:-false}"

# Install Homebrew
if ! [ -x "$(command -v brew)" ]; then
  loginstall "homebrew"
  sh -c "$(curl -fsSL $GITHUB_RAW/Homebrew/install/HEAD/install.sh)"
fi

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

# Save Homebrew’s installed location.
BREW_PREFIX=$(brew --prefix)

# Install more recent versions of some macOS tools.
loginstall "newer macOS tools"

# Install GNU core utilities (those that come with macOS are outdated).
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew install coreutils
ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"

# Install some other useful utilities like `sponge`.
brew install moreutils

# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
brew install findutils

# Install GNU `sed`, overwriting the built-in `sed`.
brew install gnu-sed --with-default-names

# Languages
## Install a modern version of preferred languages
loginstall "languages"
brew install bash bash-completion2 node python
brew install go golangci-lint php java

# Term utils
loginstall "term tools and utils"
brew install bat cmake cmake-docs eza fd fzf
brew install starship thefuck xz zoxide jq yq
brew install grep ripgrep gnupg openssl openssh
brew install btop dust navi
brew install screen gmp imagemagick webp

# Tools
loginstall "infra tools"
brew install docker docker-compose
brew install awscli localstack warrensbox/tap/tfswitch terraform terraform-docs
brew install kubectl kubectx kustomize derailed/k9s/k9s k3d

loginstall "dev tools"
brew install git-lfs gh
brew install fnm pyenv readline wget zlib zx
brew install sqlite3 mailpit neovim

# Ensure terminal font is installed
if ! fc-list | grep -qi "Fira Code Nerd Font"; then
  loginstall "nerd font"
  brew install --cask font-fira-code-nerd-font
fi

# Apps
echo -e "${BLUE}Install apps: ${GREEN}$INSTALL_APPS${NC}"
if [ $INSTALL_APPS == 'true' ]; then
  loginstall "apps"
  brew install --cask 1password
  brew install --cask alfred
  brew install --cask android-studio
  brew install --cask arc
  brew install --cask background-music
  brew install devutils
  brew install --cask discord
  brew install --cask flipper
  brew install --cask gitkraken
  brew install --cask gitkraken-cli
  brew install --cask google-chrome
  brew install --cask gpg-suite-no-mail
  brew install --cask iterm2
  brew install --cask keyclu
  brew install --cask notion
  brew install --cask notion-calendar
  brew install --cask orbstack
  brew install --cask pgadmin4
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
fi

# 1Password cli
loginstall "1password cli"
brew install --cask 1password-cli
op signin

# Remove outdated versions from the cellar.
brew cleanup -s
