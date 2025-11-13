#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.sh"

cp "$SCRIPT_DIR/dotfiles/.gitconfig" ~/
git config --global user.name $GIT_PERSONAL_NAME
git config --global user.email $GIT_PERSONAL_EMAIL
