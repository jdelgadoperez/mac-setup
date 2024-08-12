#!/bin/bash

source ./env.sh
source ./styles.sh

GITHUB="https://github.com"
GITHUB_RAW="https://raw.githubusercontent.com"
DIR_CONFIG="~/.config"
DIR_PROJECTS="~/projects"
DIR_DRACULA="$DIR_PROJECTS/dracula"
THEME_PRO="dracula-pro"
DIR_DRACULA_PRO="$DIR_PROJECTS/$THEME_PRO"

function createdirsafely() {
  DIR_NAME=$@
  if [ ! -d "$DIR_NAME" ]; then
    echo "${BOLD}Create directory: ${GREEN}${DIR_NAME}${NORMAL}"
    mkdir -p "$DIR_NAME"
  fi
}

function loginstall() {
  echo "${BOLD}========================================================${NORMAL}"
  echo "${BOLD}Installing: ${GREEN}$@${NORMAL}"
}
