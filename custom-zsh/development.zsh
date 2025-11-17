######################################################################################
# Development Environment
# Package management, environment setup, and development tools
######################################################################################

function ensurerancher() {
  local cmd=("$@")
  if pgrep -f "Rancher Desktop" > /dev/null; then
    echo "🟢 Rancher is already running."
  else
    echo "🟡 Rancher is not running. Launching now..."
    open -a "Rancher Desktop"
    echo "⏳ Waiting for Rancher to launch..."
    while ! pgrep -f "Rancher Desktop" > /dev/null; do
      sleep 1
    done
    echo "✅ Rancher launched."
  fi
}

function ensuredocker() {
  local cmd=("$@")
  if docker info > /dev/null 2>&1; then
    echo "🟢 Docker daemon is already running."
  else
    echo "🟡 Docker daemon is not available."
    ensurerancher
    echo "⏳ Waiting for Docker daemon to be ready..."
    while ! docker info > /dev/null 2>&1; do
      sleep 2
    done
    echo "✅ Docker daemon is ready."
  fi
}

function getlocktype() {
  if [ -f "yarn.lock" ]; then
    echo "yarn"
  elif [ -f "pnpm-lock.yaml" ]; then
    echo "pnpm"
  elif [ -f "package-lock.json" ]; then
    echo "npm"
  else
    echo "none"
  fi
}

function cleanpkgs() {
  echo -e "${GREEN}Clearing node modules...${NC}"
  clearnodemodules
  echo -e "${GREEN}Node modules cleared${NC}"
  echo ""
  pkgman=$1
  buildCmd="build"

  if [ "$pkgman" = '' ]; then
    PKG_TYPE=$(getlocktype)
    if [ "$PKG_TYPE" = 'none' ]; then
      pkgman="yarn"
    else;
      pkgman="$PKG_TYPE"
    fi
  fi

  if [ "$pkgman" = 'yarn' ]; then
    ycc
    yin
  fi

  if [ "$pkgman" = 'npm' ]; then
    echo ""
    npm install
    buildCmd="run build"
  fi

  if [ "$pkgman" = 'pnpm' ]; then
    rm pnpm-lock.yaml
    buildCmd="build:all"
    echo ""
    pnpm install
  fi

  if pkgscripts | jq -e --arg script "$buildCmd" 'has($script)' >/dev/null; then
    echo ""
    "$pkgman" "$buildCmd"
  fi
}

function updategitdirectory() {
  DIR_NAME="$1"
  LIB_TYPE="$2"
  CLEAN_LIBS="$3"

  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}Go to ${CYAN}${DIR_NAME}${NC}"
  echo "${BLUE}==============================================================================${NC}"
  gotopathsafely $DIR_NAME
  echo ""
  local dirs=()
  for dir in */; do
    if [ -d "$dir" ]; then
      dirs+=("$dir")
    fi
  done

  for dir in "${dirs[@]}"; do
    echo "${BLUE}==============================================================================${NC}"
    echo "${BLUE}Update ${LIB_TYPE}: ${CYAN}${dir}${NC}"
    echo "${BLUE}==============================================================================${NC}"
    gotopathsafely $DIR_NAME/$dir
    if git rev-parse --is-inside-work-tree &>/dev/null; then
      echo ""
      echo "${BOLD_MAGENTA}Git branch: ${BOLD_GREEN}$(gbc)${NC}"
      echo ""
      gpra
      echo ""
      PKG_TYPE=$(getlocktype)

      if [[ -n "$CLEAN_LIBS" ]]; then
        if [[ "$PKG_TYPE" == "none" ]]; then
          echo "${GREEN}No lock file found. Skipping clean operation.${NC}"
        else
          cleanpkgs "$PKG_TYPE"
        fi
      else
        if [[ "$PKG_TYPE" == "yarn" ]]; then
          yii
        elif [[ "$PKG_TYPE" == "pnpm" ]]; then
          pnpm install --frozen-lockfile
        elif [[ "$PKG_TYPE" == "npm" ]]; then
          npm i --no-package-lock
        else
          echo "${GREEN}No lock file found. Skipping install.${NC}"
        fi
      fi
    else
      echo "${GREEN}Not a repo so nothing to pull.${NC}"
    fi
    echo ""
  done
}

function updatelibs() {
  CLEAN_LIBS="$1"
  echo ""
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}Install latest ${CYAN}node${NC}"
  echo "${BLUE}==============================================================================${NC}"
  fnm use lts-latest --corepack-enabled --install-if-missing
  echo "now on ${CYAN}$(fnm current)${NC}"
  echo ""
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}Update ${CYAN}npm${NC}"
  echo "${BLUE}==============================================================================${NC}"
  npm update -g
  echo ""
  updategitdirectory $ZSH_CUSTOM/plugins "plugin" "$CLEAN_LIBS"
  echo ""
  updategitdirectory $HOME/projects "lib" "$CLEAN_LIBS"
  echo ""
  updategitdirectory $HOME/projects/dracula "theme" "$CLEAN_LIBS"
  echo ""
  updategitdirectory $HOME/projects/sandbox "project" "$CLEAN_LIBS"
  echo ""
  gohome
  echo ""
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}Update & upgrade: ${CYAN}homebrew${NC}"
  echo "${BLUE}==============================================================================${NC}"
  brew update
  brew upgrade
}
