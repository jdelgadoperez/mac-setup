#!/bin/bash

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.sh"

# Validate required environment variables
if [ -z "$GIT_PERSONAL_NAME" ] || [ -z "$GIT_PERSONAL_EMAIL" ]; then
  logerror "Missing required environment variables for Git configuration"
  printf "\n"
  printf "${YELLOW}Please create a .env file with the following variables:${NC}"
  printf "  ${GREEN}GIT_PERSONAL_NAME${NC}=\"Your Name\"\n"
  printf "  ${GREEN}GIT_PERSONAL_EMAIL${NC}=\"your@email.com\"\n"
  printf "\n"
  printf "${BLUE}You can copy the example file:${NC}"
  printf "  cp .env.example .env\n"
  printf "\n"
  exit 1
fi

loginfo "Configuring Git"

# Symlink .gitconfig
GITCONFIG_SOURCE="$SCRIPT_DIR/dotfiles/.gitconfig"
GITCONFIG_TARGET="$HOME/.gitconfig"

if [ "${DRY_RUN:-false}" = "true" ]; then
  printf "${YELLOW}[DRY-RUN]${NC} Would create symlink: .gitconfig -> %s\n" "$GITCONFIG_SOURCE"
  printf "${YELLOW}[DRY-RUN]${NC} Would set git user.name: %s\n" "$GIT_PERSONAL_NAME"
  printf "${YELLOW}[DRY-RUN]${NC} Would set git user.email: %s\n" "$GIT_PERSONAL_EMAIL"
else
  # Remove existing file or symlink if it exists
  if [ -e "$GITCONFIG_TARGET" ] || [ -L "$GITCONFIG_TARGET" ]; then
    rm -f "$GITCONFIG_TARGET"
  fi

  # Create symlink
  ln -s "$GITCONFIG_SOURCE" "$GITCONFIG_TARGET"
  logsuccess "Symlinked .gitconfig"

  # Configure git user
  git config --global user.name "$GIT_PERSONAL_NAME"
  git config --global user.email "$GIT_PERSONAL_EMAIL"
  logsuccess "Configured Git user: $GIT_PERSONAL_NAME <$GIT_PERSONAL_EMAIL>"
fi
