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

function getpkgtype() {
  # Node.js
  if [ -f "yarn.lock" ]; then
    echo "yarn"
  elif [ -f "pnpm-lock.yaml" ]; then
    echo "pnpm"
  elif [ -f "package-lock.json" ]; then
    echo "npm"
  # Python
  elif [ -f "poetry.lock" ]; then
    echo "poetry"
  elif [ -f "uv.lock" ]; then
    echo "uv"
  elif [ -f "Pipfile.lock" ]; then
    echo "pipenv"
  elif [ -f "requirements.txt" ]; then
    echo "pip"
  else
    echo "none"
  fi
}

function cleanpkgs() {
  pkgman=$1
  buildCmd="build"

  if [ "$pkgman" = '' ]; then
    PKG_TYPE=$(getpkgtype)
    if [ "$PKG_TYPE" = 'none' ]; then
      pkgman="yarn"
    else;
      pkgman="$PKG_TYPE"
    fi
  fi

  # Node.js package managers
  if [ "$pkgman" = 'yarn' ]; then
    echo -e "${GREEN}Clearing node modules...${NC}"
    clearnodemodules
    echo -e "${GREEN}Node modules cleared${NC}"
    echo ""
    ycc
    yin
  fi

  if [ "$pkgman" = 'npm' ]; then
    echo -e "${GREEN}Clearing node modules...${NC}"
    clearnodemodules
    echo -e "${GREEN}Node modules cleared${NC}"
    echo ""
    npm install
    buildCmd="run build"
  fi

  if [ "$pkgman" = 'pnpm' ]; then
    echo -e "${GREEN}Clearing node modules...${NC}"
    clearnodemodules
    echo -e "${GREEN}Node modules cleared${NC}"
    rm pnpm-lock.yaml
    buildCmd="build:all"
    echo ""
    pnpm install
  fi

  # Python package managers
  if [ "$pkgman" = 'poetry' ]; then
    echo -e "${GREEN}Clearing Python venv...${NC}"
    rm -rf .venv
    echo -e "${GREEN}Python venv cleared${NC}"
    echo ""
    poetry install --no-interaction
    return
  fi

  if [ "$pkgman" = 'uv' ]; then
    echo -e "${GREEN}Clearing Python venv...${NC}"
    rm -rf .venv
    echo -e "${GREEN}Python venv cleared${NC}"
    echo ""
    uv sync
    return
  fi

  if [ "$pkgman" = 'pipenv' ]; then
    echo -e "${GREEN}Clearing Pipenv environment...${NC}"
    pipenv --rm 2>/dev/null || true
    echo -e "${GREEN}Pipenv environment cleared${NC}"
    echo ""
    pipenv install
    return
  fi

  if [ "$pkgman" = 'pip' ]; then
    echo -e "${GREEN}Clearing Python venv...${NC}"
    rm -rf .venv venv
    echo -e "${GREEN}Python venv cleared${NC}"
    echo ""
    python3 -m venv .venv
    .venv/bin/pip install -r requirements.txt
    return
  fi

  # Node.js build step (only for Node projects)
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

  local total=${#dirs[@]}
  local current=0
  local success_count=0
  local skip_count=0
  local fail_count=0

  for dir in "${dirs[@]}"; do
    ((current++))
    echo "${BLUE}==============================================================================${NC}"
    echo "${BLUE}[$current/$total] Update ${LIB_TYPE}: ${CYAN}${dir}${NC}"
    echo "${BLUE}==============================================================================${NC}"
    gotopathsafely $DIR_NAME/$dir

    if git rev-parse --is-inside-work-tree &>/dev/null; then
      echo ""
      echo "${BOLD_MAGENTA}Git branch: ${BOLD_GREEN}$(gbc)${NC}"
      echo ""

      # Git pull with timeout (30 seconds)
      # Use SIGINT for gentler interruption
      echo "${BLUE}⏳ Pulling latest changes...${NC}"
      local TIMEOUT_CMD="timeout"
      if command -v gtimeout &>/dev/null; then
        TIMEOUT_CMD="gtimeout"
      fi

      if $TIMEOUT_CMD --signal=INT 30 git pull --rebase --autostash 2>&1; then
        echo "${GREEN}✅ Git pull successful${NC}"

        PKG_TYPE=$(getpkgtype)

        if [[ -n "$CLEAN_LIBS" ]]; then
          if [[ "$PKG_TYPE" == "none" ]]; then
            echo "${GREEN}No lock file found. Skipping clean operation.${NC}"
          else
            echo "${BLUE}⏳ Cleaning and rebuilding packages...${NC}"
            if cleanpkgs "$PKG_TYPE" 2>&1; then
              ((success_count++))
            else
              echo "${YELLOW}⚠️  Package clean failed, continuing...${NC}"
              ((fail_count++))
            fi
          fi
        else
          if [[ "$PKG_TYPE" == "yarn" ]]; then
            echo "${BLUE}⏳ Installing with yarn...${NC}"
            if yii 2>&1; then
              ((success_count++))
            else
              echo "${YELLOW}⚠️  Yarn install failed, continuing...${NC}"
              ((fail_count++))
            fi
          elif [[ "$PKG_TYPE" == "pnpm" ]]; then
            echo "${BLUE}⏳ Installing with pnpm...${NC}"
            if pnpm install --frozen-lockfile 2>&1; then
              ((success_count++))
            else
              echo "${YELLOW}⚠️  pnpm install failed, continuing...${NC}"
              ((fail_count++))
            fi
          elif [[ "$PKG_TYPE" == "npm" ]]; then
            echo "${BLUE}⏳ Installing with npm...${NC}"
            if npm i --no-package-lock 2>&1; then
              ((success_count++))
            else
              echo "${YELLOW}⚠️  npm install failed, continuing...${NC}"
              ((fail_count++))
            fi
          elif [[ "$PKG_TYPE" == "poetry" ]]; then
            echo "${BLUE}⏳ Installing with poetry...${NC}"
            if poetry install --no-interaction 2>&1; then
              ((success_count++))
            else
              echo "${YELLOW}⚠️  Poetry install failed, continuing...${NC}"
              ((fail_count++))
            fi
          elif [[ "$PKG_TYPE" == "uv" ]]; then
            echo "${BLUE}⏳ Installing with uv...${NC}"
            if uv sync 2>&1; then
              ((success_count++))
            else
              echo "${YELLOW}⚠️  uv sync failed, continuing...${NC}"
              ((fail_count++))
            fi
          elif [[ "$PKG_TYPE" == "pipenv" ]]; then
            echo "${BLUE}⏳ Installing with pipenv...${NC}"
            if pipenv install 2>&1; then
              ((success_count++))
            else
              echo "${YELLOW}⚠️  Pipenv install failed, continuing...${NC}"
              ((fail_count++))
            fi
          elif [[ "$PKG_TYPE" == "pip" ]]; then
            echo "${BLUE}⏳ Installing with pip...${NC}"
            if pip install -r requirements.txt 2>&1; then
              ((success_count++))
            else
              echo "${YELLOW}⚠️  pip install failed, continuing...${NC}"
              ((fail_count++))
            fi
          else
            echo "${GREEN}No package file found. Skipping install.${NC}"
            ((success_count++))
          fi
        fi
      else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
          echo "${YELLOW}⚠️  Git pull timed out (30s) - skipping ${dir}${NC}"
        else
          echo "${YELLOW}⚠️  Git pull failed - skipping ${dir}${NC}"
        fi
        ((fail_count++))
      fi
    else
      echo "${CYAN}Not a git repository - skipping${NC}"
      ((skip_count++))
    fi
    echo ""
  done

  # Summary
  echo "${BLUE}==============================================================================${NC}"
  echo "${BOLD}Summary for ${LIB_TYPE}s:${NC}"
  echo "  ${GREEN}✅ Successful: $success_count${NC}"
  if [[ $skip_count -gt 0 ]]; then
    echo "  ${CYAN}⏭  Skipped: $skip_count${NC}"
  fi
  if [[ $fail_count -gt 0 ]]; then
    echo "  ${YELLOW}⚠️  Failed: $fail_count${NC}"
  fi
  echo "${BLUE}==============================================================================${NC}"
  echo ""
}

function updatelibs() {
  CLEAN_LIBS="$1"
  local start_time=$(date +%s)

  # Detect timeout command (prefer gtimeout from coreutils)
  local TIMEOUT_CMD="timeout"
  if command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
  elif ! command -v timeout &>/dev/null; then
    echo "${YELLOW}⚠️  Warning: timeout command not found. Operations may hang.${NC}"
    echo "${YELLOW}   Install with: brew install coreutils${NC}"
    TIMEOUT_CMD=""
  fi

  echo ""
  echo "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
  echo "${BOLD}${BLUE}🔄 Update All Libraries & Tools${NC}"
  echo "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
  echo ""

  # Node.js
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[1/6] Install latest ${CYAN}node${NC}"
  echo "${BLUE}==============================================================================${NC}"
  if fnm use lts-latest --corepack-enabled --install-if-missing 2>&1; then
    echo "${GREEN}✅ Now on Node $(fnm current)${NC}"
  else
    echo "${YELLOW}⚠️  Failed to update Node.js${NC}"
  fi
  echo ""

  # npm
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[2/6] Update ${CYAN}npm${NC}"
  echo "${BLUE}==============================================================================${NC}"
  if npm update -g 2>&1; then
    echo "${GREEN}✅ npm updated${NC}"
  else
    echo "${YELLOW}⚠️  Failed to update npm${NC}"
  fi
  echo ""

  # Oh My Zsh plugins
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[3/6] Update ${CYAN}Oh My Zsh plugins${NC}"
  echo "${BLUE}==============================================================================${NC}"
  updategitdirectory $ZSH_CUSTOM/plugins "plugin" "$CLEAN_LIBS"

  # Project repositories
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[4/6] Update ${CYAN}project repositories${NC}"
  echo "${BLUE}==============================================================================${NC}"
  updategitdirectory $HOME/projects "lib" "$CLEAN_LIBS"

  # Dracula themes
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[5/6] Update ${CYAN}Dracula themes${NC}"
  echo "${BLUE}==============================================================================${NC}"
  updategitdirectory $HOME/projects/dracula "theme" "$CLEAN_LIBS"

  gohome

  # Homebrew
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[6/6] Update & upgrade ${CYAN}Homebrew${NC}"
  echo "${BLUE}==============================================================================${NC}"

  if [[ -n "$TIMEOUT_CMD" ]]; then
    echo "${BLUE}⏳ Updating Homebrew (timeout: 5 minutes)...${NC}"
    # Use SIGINT for gentler interruption that Homebrew handles better
    if $TIMEOUT_CMD --signal=INT 300 brew update; then
      echo "${GREEN}✅ Homebrew updated${NC}"
      echo ""
      echo "${BLUE}⏳ Upgrading Homebrew packages (timeout: 20 minutes)...${NC}"

      if $TIMEOUT_CMD --signal=INT 1200 brew upgrade; then
        echo "${GREEN}✅ Homebrew packages upgraded${NC}"
      else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
          echo "${YELLOW}⚠️  Homebrew upgrade timed out after 20 minutes${NC}"
        else
          echo "${YELLOW}⚠️  Some Homebrew packages failed to upgrade${NC}"
        fi
      fi
    else
      local exit_code=$?
      if [[ $exit_code -eq 124 ]]; then
        echo "${YELLOW}⚠️  Homebrew update timed out after 5 minutes${NC}"
      else
        echo "${YELLOW}⚠️  Homebrew update failed${NC}"
      fi
    fi
  else
    # No timeout available - run without it
    echo "${BLUE}⏳ Updating Homebrew (no timeout)...${NC}"
    if brew update; then
      echo "${GREEN}✅ Homebrew updated${NC}"
      echo ""
      echo "${BLUE}⏳ Upgrading Homebrew packages...${NC}"
      if brew upgrade; then
        echo "${GREEN}✅ Homebrew packages upgraded${NC}"
      else
        echo "${YELLOW}⚠️  Some Homebrew packages failed to upgrade${NC}"
      fi
    else
      echo "${YELLOW}⚠️  Homebrew update failed${NC}"
    fi
  fi
  echo ""

  # Overall summary
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  local minutes=$((duration / 60))
  local seconds=$((duration % 60))

  echo ""
  echo "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
  echo "${BOLD}${GREEN}✅ Update Complete!${NC}"
  echo "${GREEN}   Total time: ${CYAN}${minutes}m ${seconds}s${NC}"
  echo "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
  echo ""
}
