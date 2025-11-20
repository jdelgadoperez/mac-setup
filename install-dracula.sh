#!/bin/bash

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.sh"

if [ "${DRY_RUN:-false}" = "true" ]; then
  printf "${YELLOW}[DRY-RUN]${NC} Would create directories for Dracula themes\n"
  printf "${YELLOW}[DRY-RUN]${NC} Would clone 6 Dracula theme repositories\n"

  if [ "${FORCE_INSTALL:-false}" = "true" ]; then
    printf "${YELLOW}[DRY-RUN]${NC} Would reinstall free Dracula Zsh theme (--force)\n"
  else
    printf "${YELLOW}[DRY-RUN]${NC} Would install free Dracula Zsh theme\n"
  fi

  if [ "${FORCE_INSTALL:-false}" = "true" ]; then
    printf "${YELLOW}[DRY-RUN]${NC} Would reinstall Dracula Pro theme (--force)\n"
  elif [ "${NON_INTERACTIVE:-false}" != "true" ]; then
    printf "${YELLOW}[DRY-RUN]${NC} Would prompt for Dracula Pro installation (optional)\n"
  else
    printf "${YELLOW}[DRY-RUN]${NC} Would check for Dracula Pro installation\n"
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
  if [ -f "$ZSH_CUSTOM/themes/dracula.zsh-theme" ] && [ "${FORCE_INSTALL:-false}" != "true" ]; then
    loginfo "Free Dracula Zsh theme already installed"
  else
    if [ "${FORCE_INSTALL:-false}" = "true" ] && [ -f "$ZSH_CUSTOM/themes/dracula.zsh-theme" ]; then
      loginfo "Reinstalling free Dracula Zsh theme (--force flag)"
    fi
    cp "$DIR_DRACULA/zsh/dracula.zsh-theme" "$ZSH_CUSTOM/themes/dracula.zsh-theme"
    logsuccess "Free Dracula Zsh theme installed"
  fi
fi

## Get dracula pro themes (optional - requires manual download)

# Check if Dracula Pro theme is already installed
REINSTALL_PRO=false
if [ -f "$ZSH_CUSTOM/themes/$THEME_PRO.zsh-theme" ]; then
  if [ "${FORCE_INSTALL:-false}" = "true" ]; then
    loginfo "Dracula Pro theme already installed, but --force flag detected"
    loginfo "Will reinstall Dracula Pro theme"
    REINSTALL_PRO=true
  elif [ "${NON_INTERACTIVE:-false}" = "true" ]; then
    logsuccess "Dracula Pro theme is already installed"
    logsuccess "Dracula themes installation complete"
    exit 0
  else
    loginfo "Dracula Pro theme already installed at $ZSH_CUSTOM/themes/$THEME_PRO.zsh-theme"
    echo ""
    read -p "${BLUE}Reinstall Dracula Pro theme? (y/N):${NC} " reinstall
    if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
      logsuccess "Keeping existing Dracula Pro theme"
      logsuccess "Dracula themes installation complete"
      exit 0
    fi
    REINSTALL_PRO=true
  fi
fi

# Look for Dracula Pro zip with different possible names
DRACULA_ZIP=""
if [ -f "$DIR_ROOT/Downloads/$THEME_PRO.zip" ]; then
  DRACULA_ZIP="$DIR_ROOT/Downloads/$THEME_PRO.zip"
elif [ -f "$DIR_ROOT/Downloads/Dracula PRO Archive.zip" ]; then
  DRACULA_ZIP="$DIR_ROOT/Downloads/Dracula PRO Archive.zip"
elif [ -f "$DIR_ROOT/Downloads/dracula_pro.zip" ]; then
  DRACULA_ZIP="$DIR_ROOT/Downloads/dracula_pro.zip"
fi

# If zip file found, install it regardless of interactive mode
if [ -n "$DRACULA_ZIP" ]; then
  loginstall "dracula pro themes (optional)"
  loginfo "Found Dracula Pro archive: $(basename "$DRACULA_ZIP")"
  cd "$DIR_ROOT/Downloads"
  unzip -o "$DRACULA_ZIP" -d "$DIR_DRACULA_PRO"
  cd "$CUR_DIR"

  if [ -f "$DIR_DRACULA_PRO/themes/zsh/$THEME_PRO.zsh-theme" ]; then
    cp "$DIR_DRACULA_PRO/themes/zsh/$THEME_PRO.zsh-theme" "$ZSH_CUSTOM/themes/$THEME_PRO.zsh-theme"
    logsuccess "Dracula Pro theme installed successfully"
    loginfo "Theme file location: $ZSH_CUSTOM/themes/$THEME_PRO.zsh-theme"
  else
    loginfo "Dracula Pro theme file not found in expected location"
    loginfo "Expected: $DIR_DRACULA_PRO/themes/zsh/$THEME_PRO.zsh-theme"
    loginfo "Using free Dracula theme instead"
  fi
elif [ "${NON_INTERACTIVE:-false}" = "false" ]; then
  # Only prompt in interactive mode if zip not found
  loginstall "dracula pro themes (optional)"
  echo ""
  printf "${BLUE}Dracula Pro is a paid theme. If you have purchased it:${NC}\n"
  printf "  ${GREEN}1.${NC} Download the zip file to ~/Downloads/\n"
  printf "  ${GREEN}2.${NC} It can be named 'dracula-pro.zip' or 'Dracula PRO Archive.zip'\n"
  printf "  ${GREEN}3.${NC} Press Enter to continue, or Ctrl+C to skip\n"
  echo ""
  read -r

  loginfo "Dracula Pro zip not found in ~/Downloads/"
  loginfo "Looked for: dracula-pro.zip, Dracula PRO Archive.zip, dracula_pro.zip"
  loginfo "Using free Dracula theme instead"
else
  # Non-interactive mode and no zip found
  loginfo "Dracula Pro zip not found in ~/Downloads/ (non-interactive mode)"
  loginfo "Looked for: dracula-pro.zip, Dracula PRO Archive.zip, dracula_pro.zip"
  loginfo "Using free Dracula theme instead"
fi

logsuccess "Dracula themes installation complete"
