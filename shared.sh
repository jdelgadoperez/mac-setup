#!/bin/bash

source ./env.sh
source ./custom-zsh/styles.zsh

ROOT_DIR="${PWD%%/projects/*}"
GITHUB="https://github.com"
GITHUB_RAW="https://raw.githubusercontent.com"
DIR_CONFIG="$ROOT_DIR/.config"
DIR_PROJECTS="$ROOT_DIR/projects"
DIR_DRACULA="$DIR_PROJECTS/dracula"
THEME_PRO="dracula-pro"
DIR_DRACULA_PRO="$DIR_PROJECTS/$THEME_PRO"

function createdirsafely() {
  DIR_NAME=$@
  if [ ! -d "$DIR_NAME" ]; then
    echo "${BLUE}Create directory: ${GREEN}${DIR_NAME}${NC}"
    mkdir -p "$DIR_NAME"
  fi
}

function loginstall() {
  echo "${BLUE}========================================================${NC}"
  echo "${BLUE}Installing: ${GREEN}$@${NC}"
}
