#!/bin/bash

source ./shared.sh
sh ./install-xcode.sh
sh ./install-brew.sh true
sh ./setup-git.sh
sh ./install-zsh.sh
exec zsh
sh ./install-dracula.sh
exec zsh
