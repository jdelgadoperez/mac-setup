#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.sh"

sh "$SCRIPT_DIR/install-xcode.sh"
sh "$SCRIPT_DIR/install-brew.sh" false
sh "$SCRIPT_DIR/config-git.sh"
sh "$SCRIPT_DIR/install-zsh.sh"
exec zsh

sh "$SCRIPT_DIR/install-dracula.sh"
exec zsh
