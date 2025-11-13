#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.sh"

createdirsafely "$DIR_PROJECTS"
createdirsafely "$DIR_DRACULA"
createdirsafely "$DIR_DRACULA_PRO"
createdirsafely "$ZSH_CUSTOM/themes"

CUR_DIR="${PWD}"
printf "Current dir: ${BLUE}${CUR_DIR}${NC}\n"

## Get public dracula themes
loginstall "dracula themes"
REPO_DRACULA="$GITHUB/dracula"
gitclonesafely "$REPO_DRACULA/gitkraken.git" "$DIR_DRACULA/gitkraken"
gitclonesafely "$REPO_DRACULA/sequel-ace.git" "$DIR_DRACULA/sequel-ace"
gitclonesafely "$REPO_DRACULA/visual-studio-code.git" "$DIR_DRACULA/visual-studio-code"
gitclonesafely "$REPO_DRACULA/xcode.git" "$DIR_DRACULA/xcode"
gitclonesafely "$REPO_DRACULA/zsh.git" "$DIR_DRACULA/zsh"
gitclonesafely "$REPO_DRACULA/zsh-syntax-highlighting.git" "$DIR_DRACULA/zsh-syntax-highlighting"
cp "$DIR_DRACULA/zsh-syntax-highlighting/zsh-syntax-highlighting.sh" "$ZSH_CUSTOM/zsh-syntax-highlighting.zsh"

# Install free Dracula theme as fallback
if [ -f "$DIR_DRACULA/zsh/dracula.zsh-theme" ]; then
  cp "$DIR_DRACULA/zsh/dracula.zsh-theme" "$ZSH_CUSTOM/themes/dracula.zsh-theme"
  printf "${GREEN}Free Dracula theme installed as fallback${NC}\n"
fi

## Get dracula pro themes (optional - requires manual download)
loginstall "dracula pro themes (optional)"
printf "${BLUE}Dracula Pro is a paid theme. If you have purchased it:${NC}\n"
printf "${BLUE}1. Download the zip file to ~/Downloads/${NC}\n"
printf "${BLUE}2. Rename it to 'dracula-pro.zip'${NC}\n"
printf "${BLUE}3. Press Enter to continue, or Ctrl+C to skip${NC}\n"
read -r

if [ -f "$DIR_ROOT/Downloads/$THEME_PRO.zip" ]; then
  cd "$DIR_ROOT/Downloads"
  unzip -o "$THEME_PRO.zip" -d "$DIR_DRACULA_PRO"
  cd "$CUR_DIR"

  if [ -f "$DIR_DRACULA_PRO/themes/zsh/$THEME_PRO.zsh-theme" ]; then
    cp "$DIR_DRACULA_PRO/themes/zsh/$THEME_PRO.zsh-theme" "$ZSH_CUSTOM/themes/$THEME_PRO.zsh-theme"
    printf "${GREEN}Dracula Pro theme installed successfully${NC}\n"
  else
    printf "${YELLOW}Warning: Dracula Pro theme file not found in expected location.${NC}\n"
    printf "${YELLOW}Using free Dracula theme instead.${NC}\n"
  fi
else
  printf "${YELLOW}Dracula Pro zip not found. Using free Dracula theme instead.${NC}\n"
fi
