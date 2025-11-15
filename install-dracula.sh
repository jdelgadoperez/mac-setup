#!/bin/bash

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.sh"

if [ "${DRY_RUN:-false}" = "true" ]; then
  echo -e "${YELLOW}[DRY-RUN]${NC} Would create directories for Dracula themes\n"
  echo -e "${YELLOW}[DRY-RUN]${NC} Would clone 6 Dracula theme repositories\n"
  echo -e "${YELLOW}[DRY-RUN]${NC} Would install free Dracula Zsh theme\n"
  if [ "${NON_INTERACTIVE:-false}" != "true" ]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} Would prompt for Dracula Pro installation (optional)\n"
  fi
  exit 0
fi

createdirsafely "$DIR_PROJECTS"
createdirsafely "$DIR_DRACULA"
createdirsafely "$DIR_DRACULA_PRO"
createdirsafely "$ZSH_CUSTOM/themes"

CUR_DIR="${PWD}"
loginfo "Working directory: $CUR_DIR"

## Get public dracula themes
loginstall "dracula themes"
REPO_DRACULA="$GITHUB/dracula"

gitclonesafely "$REPO_DRACULA/gitkraken.git" "$DIR_DRACULA/gitkraken"
gitclonesafely "$REPO_DRACULA/sequel-ace.git" "$DIR_DRACULA/sequel-ace"
gitclonesafely "$REPO_DRACULA/visual-studio-code.git" "$DIR_DRACULA/visual-studio-code"
gitclonesafely "$REPO_DRACULA/xcode.git" "$DIR_DRACULA/xcode"
gitclonesafely "$REPO_DRACULA/zsh.git" "$DIR_DRACULA/zsh"
gitclonesafely "$REPO_DRACULA/zsh-syntax-highlighting.git" "$DIR_DRACULA/zsh-syntax-highlighting"

# Symlink syntax highlighting
if [ -f "$DIR_DRACULA/zsh-syntax-highlighting/zsh-syntax-highlighting.sh" ]; then
  ln -sf "$DIR_DRACULA/zsh-syntax-highlighting/zsh-syntax-highlighting.sh" "$ZSH_CUSTOM/zsh-syntax-highlighting.zsh"
  loginfo "Symlinked zsh-syntax-highlighting"
fi

# Install free Dracula theme as fallback
if [ -f "$DIR_DRACULA/zsh/dracula.zsh-theme" ]; then
  cp "$DIR_DRACULA/zsh/dracula.zsh-theme" "$ZSH_CUSTOM/themes/dracula.zsh-theme"
  logsuccess "Free Dracula Zsh theme installed"
fi

## Get dracula pro themes (optional - requires manual download)
if [ "${NON_INTERACTIVE:-false}" = "true" ]; then
  # Skip Dracula Pro in non-interactive mode
  loginfo "Skipping Dracula Pro installation (non-interactive mode)"
else
  loginstall "dracula pro themes (optional)"
  echo ""
  echo -e "${BLUE}Dracula Pro is a paid theme. If you have purchased it:${NC}"
  printf "  ${GREEN}1.${NC} Download the zip file to ~/Downloads/\n"
  printf "  ${GREEN}2.${NC} Rename it to 'dracula-pro.zip'\n"
  printf "  ${GREEN}3.${NC} Press Enter to continue, or Ctrl+C to skip\n"
  echo ""
  read -r

  if [ -f "$DIR_ROOT/Downloads/$THEME_PRO.zip" ]; then
    cd "$DIR_ROOT/Downloads"
    unzip -o "$THEME_PRO.zip" -d "$DIR_DRACULA_PRO"
    cd "$CUR_DIR"

    if [ -f "$DIR_DRACULA_PRO/themes/zsh/$THEME_PRO.zsh-theme" ]; then
      cp "$DIR_DRACULA_PRO/themes/zsh/$THEME_PRO.zsh-theme" "$ZSH_CUSTOM/themes/$THEME_PRO.zsh-theme"
      logsuccess "Dracula Pro theme installed successfully"
    else
      loginfo "Dracula Pro theme file not found in expected location"
      loginfo "Using free Dracula theme instead"
    fi
  else
    loginfo "Dracula Pro zip not found. Using free Dracula theme instead"
  fi
fi

logsuccess "Dracula themes installation complete"
