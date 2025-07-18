#!/bin/bash

source ./env.sh

PADDING="-36"
COLOR_OFF="\033[0m" # Text Reset
NC=$COLOR_OFF       # Reset color

# Regular Colors
BLACK="\033[0;30m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
GREEN="\033[0;32m"
MAGENTA="\033[0;35m"
RED="\033[0;31m"
WHITE="\033[0;37m"
YELLOW="\033[0;33m"

# Bold
BOLD_BLACK="\033[1;30m"
BOLD_RED="\033[1;31m"
BOLD_GREEN="\033[1;32m"
BOLD_YELLOW="\033[1;33m"
BOLD_BLUE="\033[1;34m"
BOLD_MAGENTA="\033[1;35m"
BOLD_CYAN="\033[1;36m"
BOLD_WHITE="\033[1;37m"

GITHUB="https://github.com"
GITHUB_RAW="https://raw.githubusercontent.com"
DIR_ROOT="${PWD%%/projects/*}"
DIR_CONFIG="$DIR_ROOT/.config"
DIR_PROJECTS="$DIR_ROOT/projects"
DIR_DRACULA="$DIR_PROJECTS/dracula"
THEME_PRO="dracula-pro"
DIR_DRACULA_PRO="$DIR_PROJECTS/$THEME_PRO"
ZSH_CUSTOM="$DIR_ROOT/.oh-my-zsh/custom"

function createdirsafely() {
  DIR_NAME=$@
  if [ ! -d "$DIR_NAME" ]; then
    echo -e "${BLUE}Create directory: ${GREEN}${DIR_NAME}${NC}"
    mkdir -p "$DIR_NAME"
  fi
}

function loginstall() {
  echo -e "${BLUE}========================================================${NC}"
  echo -e "${BLUE}Installing: ${GREEN}$@${NC}"
}
