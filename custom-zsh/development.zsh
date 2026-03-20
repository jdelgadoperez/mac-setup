######################################################################################
# Development Environment
# Package management, environment setup, and development tools
######################################################################################

# Generic function to ensure a service is running
# Usage: ensure_service "Service Name" "check_command" "app_name" [sleep_interval] [prerequisite_function]
function ensure_service() {
  local service_name="$1"
  local check_cmd="$2"
  local app_name="$3"
  local sleep_interval="${4:-1}"
  local prerequisite_fn="$5"

  if eval "$check_cmd" > /dev/null 2>&1; then
    echo "🟢 ${service_name} is already running."
  else
    echo "🟡 ${service_name} is not running."

    if [[ -n "$prerequisite_fn" ]]; then
      eval "$prerequisite_fn"
    fi

    if [[ -n "$app_name" ]]; then
      echo "🟡 Launching ${service_name}..."
      open -a "$app_name"
    fi

    echo "⏳ Waiting for ${service_name} to be ready..."
    while ! eval "$check_cmd" > /dev/null 2>&1; do
      sleep "$sleep_interval"
    done
    echo "✅ ${service_name} is ready."
  fi
}

function ensureorbstack() {
  ensure_service "OrbStack" "pgrep -f 'OrbStack'" "OrbStack" 1
}

function ensurerancher() {
  ensure_service "Rancher" "pgrep -f 'Rancher Desktop'" "Rancher Desktop" 1
}

function ensuredocker() {
  local runtime_fn=""
  if [ -d "/Applications/OrbStack.app" ]; then
    runtime_fn="ensureorbstack"
  elif [ -d "/Applications/Rancher Desktop.app" ]; then
    runtime_fn="ensurerancher"
  fi

  ensure_service "Docker daemon" "docker info" "" 2 "$runtime_fn"
}

function ensurememorybank() {
  echo ""
  echo "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
  echo "${BOLD}${BLUE}🧠 Memory Bank${NC}"
  echo "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
  echo ""

  # Check CLI is available
  if ! command -v memory-bank &>/dev/null; then
    echo "${RED}❌ memory-bank CLI not found on PATH${NC}"
    echo "${YELLOW}   Install with: uv pip install -e ~/projects/memory-bank${NC}"
    return 1
  fi
  echo "${GREEN}✅ memory-bank CLI available${NC}"

  # Ingest latest Claude Code history
  echo ""
  echo "${BLUE}⏳ Ingesting Claude Code history...${NC}"
  if memory-bank ingest claude-code 2>&1; then
    echo "${GREEN}✅ Ingest complete${NC}"
  else
    echo "${YELLOW}⚠️  Ingest failed (check ~/.memory-bank/ingest.log)${NC}"
  fi

  # Start UI in background if not already running
  echo ""
  echo "${BLUE}⏳ Checking UI server...${NC}"
  if memory-bank ui status 2>&1 | grep -qi "running"; then
    echo "${GREEN}🟢 UI server already running${NC}"
  else
    echo "${BLUE}⏳ Starting UI server in background...${NC}"
    if memory-bank ui -B start 2>&1; then
      echo "${GREEN}✅ UI server started${NC}"
    else
      echo "${YELLOW}⚠️  Failed to start UI server${NC}"
    fi
  fi

  echo ""
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
    else
      pkgman="$PKG_TYPE"
    fi
  fi

  case "$pkgman" in
    # Node.js package managers
    yarn)
      echo -e "${GREEN}Clearing node modules...${NC}"
      clearnodemodules
      echo -e "${GREEN}Node modules cleared${NC}"
      echo ""
      ycc
      yin
      ;;
    npm)
      echo -e "${GREEN}Clearing node modules...${NC}"
      clearnodemodules
      echo -e "${GREEN}Node modules cleared${NC}"
      echo ""
      npm install
      buildCmd="run build"
      ;;
    pnpm)
      echo -e "${GREEN}Clearing node modules...${NC}"
      clearnodemodules
      echo -e "${GREEN}Node modules cleared${NC}"
      rm pnpm-lock.yaml
      buildCmd="build:all"
      echo ""
      pnpm install
      ;;
    # Python package managers
    poetry)
      echo -e "${GREEN}Clearing Python venv...${NC}"
      rm -rf .venv
      echo -e "${GREEN}Python venv cleared${NC}"
      echo ""
      poetry install --no-interaction
      return
      ;;
    uv)
      echo -e "${GREEN}Clearing Python venv...${NC}"
      rm -rf .venv
      echo -e "${GREEN}Python venv cleared${NC}"
      echo ""
      uv sync
      return
      ;;
    pipenv)
      echo -e "${GREEN}Clearing Pipenv environment...${NC}"
      pipenv --rm 2>/dev/null || true
      echo -e "${GREEN}Pipenv environment cleared${NC}"
      echo ""
      pipenv install
      return
      ;;
    pip)
      echo -e "${GREEN}Clearing Python venv...${NC}"
      rm -rf .venv venv
      echo -e "${GREEN}Python venv cleared${NC}"
      echo ""
      python3 -m venv .venv
      .venv/bin/pip install -r requirements.txt
      return
      ;;
  esac

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
  local failed_repos=()

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
              failed_repos+=("${dir%/}")
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
              failed_repos+=("${dir%/}")
            fi
          elif [[ "$PKG_TYPE" == "pnpm" ]]; then
            echo "${BLUE}⏳ Installing with pnpm...${NC}"
            if pnpm install --frozen-lockfile 2>&1; then
              ((success_count++))
            else
              echo "${YELLOW}⚠️  pnpm install failed, continuing...${NC}"
              ((fail_count++))
              failed_repos+=("${dir%/}")
            fi
          elif [[ "$PKG_TYPE" == "npm" ]]; then
            echo "${BLUE}⏳ Installing with npm...${NC}"
            if npm i --no-package-lock 2>&1; then
              ((success_count++))
            else
              echo "${YELLOW}⚠️  npm install failed, continuing...${NC}"
              ((fail_count++))
              failed_repos+=("${dir%/}")
            fi
          elif [[ "$PKG_TYPE" == "poetry" ]]; then
            echo "${BLUE}⏳ Installing with poetry...${NC}"
            if poetry install --no-interaction 2>&1; then
              ((success_count++))
            else
              echo "${YELLOW}⚠️  Poetry install failed, continuing...${NC}"
              ((fail_count++))
              failed_repos+=("${dir%/}")
            fi
          elif [[ "$PKG_TYPE" == "uv" ]]; then
            echo "${BLUE}⏳ Installing with uv...${NC}"
            if uv sync 2>&1; then
              ((success_count++))
            else
              echo "${YELLOW}⚠️  uv sync failed, continuing...${NC}"
              ((fail_count++))
              failed_repos+=("${dir%/}")
            fi
          elif [[ "$PKG_TYPE" == "pipenv" ]]; then
            echo "${BLUE}⏳ Installing with pipenv...${NC}"
            if pipenv install 2>&1; then
              ((success_count++))
            else
              echo "${YELLOW}⚠️  Pipenv install failed, continuing...${NC}"
              ((fail_count++))
              failed_repos+=("${dir%/}")
            fi
          elif [[ "$PKG_TYPE" == "pip" ]]; then
            echo "${BLUE}⏳ Installing with pip...${NC}"
            if pip install -r requirements.txt 2>&1; then
              ((success_count++))
            else
              echo "${YELLOW}⚠️  pip install failed, continuing...${NC}"
              ((fail_count++))
              failed_repos+=("${dir%/}")
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
        failed_repos+=("${dir%/}")
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
    for repo in "${failed_repos[@]}"; do
      echo "     ${YELLOW}- ${repo}${NC}"
    done
  fi
  echo "${BLUE}==============================================================================${NC}"
  echo ""

  # Append to global array for callers to aggregate
  UPDATE_FAILED_REPOS+=("${failed_repos[@]}")
}

function updatelibs() {
  CLEAN_LIBS="$1"
  local start_time=$(date +%s)
  UPDATE_FAILED_REPOS=()

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
  echo "${BLUE}[1/7] Install latest ${CYAN}node${NC}"
  echo "${BLUE}==============================================================================${NC}"
  if fnm use lts-latest --corepack-enabled --install-if-missing 2>&1; then
    echo "${GREEN}✅ Now on Node $(fnm current)${NC}"
  else
    echo "${YELLOW}⚠️  Failed to update Node.js${NC}"
  fi
  echo ""

  # npm
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[2/7] Update ${CYAN}npm${NC}"
  echo "${BLUE}==============================================================================${NC}"
  if npm update -g 2>&1; then
    echo "${GREEN}✅ npm updated${NC}"
  else
    echo "${YELLOW}⚠️  Failed to update npm${NC}"
  fi
  echo ""

  # Oh My Zsh plugins
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[3/7] Update ${CYAN}Oh My Zsh plugins${NC}"
  echo "${BLUE}==============================================================================${NC}"
  updategitdirectory $ZSH_CUSTOM/plugins "plugin" "$CLEAN_LIBS"

  # Project repositories
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[4/7] Update ${CYAN}project repositories${NC}"
  echo "${BLUE}==============================================================================${NC}"
  updategitdirectory $HOME/projects "lib" "$CLEAN_LIBS"

  # Dracula themes
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[5/7] Update ${CYAN}Dracula themes${NC}"
  echo "${BLUE}==============================================================================${NC}"
  updategitdirectory $HOME/projects/dracula "theme" "$CLEAN_LIBS"

  gohome

  # Homebrew
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[6/7] Update & upgrade ${CYAN}Homebrew${NC}"
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

  # Memory Bank
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[7/7] Ensure ${CYAN}Memory Bank${NC}"
  echo "${BLUE}==============================================================================${NC}"
  ensurememorybank

  # Overall summary
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  local minutes=$((duration / 60))
  local seconds=$((duration % 60))

  echo ""
  if [[ ${#UPDATE_FAILED_REPOS[@]} -gt 0 ]]; then
    echo "${BOLD}${YELLOW}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo "${BOLD}${YELLOW}⚠️  Update Complete (with ${#UPDATE_FAILED_REPOS[@]} failed repo(s))${NC}"
    echo "${YELLOW}   Failed repos:${NC}"
    for repo in "${UPDATE_FAILED_REPOS[@]}"; do
      echo "${YELLOW}     - ${repo}${NC}"
    done
    echo "${GREEN}   Total time: ${CYAN}${minutes}m ${seconds}s${NC}"
    echo "${BOLD}${YELLOW}═══════════════════════════════════════════════════════════════════════════════${NC}"
  else
    echo "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo "${BOLD}${GREEN}✅ Update Complete!${NC}"
    echo "${GREEN}   Total time: ${CYAN}${minutes}m ${seconds}s${NC}"
    echo "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
  fi
  echo ""
}
