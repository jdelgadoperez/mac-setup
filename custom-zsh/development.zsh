######################################################################################
# Development Environment
# Package management, environment setup, and development tools
######################################################################################

# Project-local node_modules/.bin on PATH (borrowed from kentcdodds/dotfiles).
# Relative PATH entries resolve against the current directory at lookup time, so
# adding ./node_modules/.bin and several parent levels lets you run project
# binaries (eslint, vitest, tsc, prettier, ...) directly from any subdirectory —
# no `npx` and no `package.json` script needed. Prefers the closest one first.
# NOTE: this puts repo-local binaries ahead of globals; only affects Node projects,
# but be mindful when running bare commands inside untrusted repos.
if [[ ":$PATH:" != *":./node_modules/.bin:"* ]]; then
  # Anonymous function keeps the loop vars out of the interactive shell scope.
  () {
    local nm="./node_modules/.bin"
    local up="../"
    local i
    for i in {1..7}; do
      nm="${nm}:${up}node_modules/.bin"
      up="../${up}"
    done
    export PATH="${nm}:${PATH}"
  }
fi

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
    echo "${YELLOW}   Install with: uv tool install -e ~/projects/memory-bank${NC}"
    return 1
  fi
  echo "${GREEN}✅ memory-bank CLI available${NC}"

  # Ingest latest Claude Code history
  # Routes through UI server API if running, otherwise uses direct DB access
  # Output is redirected to the log file to prevent rich's spinner from doing
  # terminal I/O while updatelibs runs as a background job (which causes SIGTSTP spam)
  echo ""
  echo "${BLUE}⏳ Ingesting Claude Code history...${NC}"
  if memory-bank ingest claude-code >> ~/.memory-bank/ingest.log 2>&1; then
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
    pnpm)
      echo -e "${GREEN}Clearing node modules...${NC}"
      clearnodemodules
      echo -e "${GREEN}Node modules cleared${NC}"
      rm pnpm-lock.yaml
      buildCmd="build:all"
      echo ""
      pnpm install
      ;;
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

      # Clear stale .git/index.lock if no git process owns this repo
      local GIT_DIR_PATH="$(git rev-parse --git-dir 2>/dev/null)"
      local LOCK_FILE="$GIT_DIR_PATH/index.lock"
      if [ -f "$LOCK_FILE" ]; then
        local REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
        if pgrep -f "git.*$REPO_ROOT" >/dev/null 2>&1; then
          echo "${YELLOW}⚠️  Active git process detected for $REPO_ROOT — leaving index.lock in place${NC}"
        else
          local LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || stat -c %Y "$LOCK_FILE" 2>/dev/null) ))
          echo "${YELLOW}⚠️  Stale .git/index.lock found (age: ${LOCK_AGE}s, no active git process) — removing${NC}"
          rm -f "$LOCK_FILE"
        fi
      fi

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
          if [[ "$PKG_TYPE" == "pnpm" ]]; then
            echo "${BLUE}⏳ Installing with pnpm...${NC}"
            if pnpm install --frozen-lockfile 2>&1; then
              ((success_count++))
            else
              echo "${YELLOW}⚠️  pnpm install failed, continuing...${NC}"
              ((fail_count++))
              failed_repos+=("${dir%/}")
            fi
          elif [[ "$PKG_TYPE" == "yarn" ]]; then
            echo "${BLUE}⏳ Installing with yarn...${NC}"
            if yii 2>&1; then
              ((success_count++))
            else
              echo "${YELLOW}⚠️  Yarn install failed, continuing...${NC}"
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

function updateclaudeplugins() {
  local TIMEOUT_CMD=""
  if command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
  elif command -v timeout &>/dev/null; then
    TIMEOUT_CMD="timeout"
  fi

  local CLAUDE_BIN
  CLAUDE_BIN=$(whence -p claude 2>/dev/null)
  CLAUDE_BIN="${CLAUDE_BIN:-claude}"

  echo "${BLUE}   ⏳ Fetching plugin list...${NC}"

  local raw_output
  if [[ -n "$TIMEOUT_CMD" ]]; then
    raw_output=$($TIMEOUT_CMD 60 "$CLAUDE_BIN" plugin list < /dev/null 2>/dev/null)
  else
    raw_output=$("$CLAUDE_BIN" plugin list < /dev/null 2>/dev/null)
  fi

  if [[ $? -ne 0 || -z "$raw_output" ]]; then
    echo "${YELLOW}   ⚠️  Could not fetch plugin list (timed out or unavailable)${NC}"
    return
  fi

  local plugins=()
  local current_plugin=""
  local is_enabled=false

  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*❯[[:space:]](.+)$ ]]; then
      if [[ -n "$current_plugin" && "$is_enabled" == true ]]; then
        plugins+=("$current_plugin")
      fi
      current_plugin="${match[1]}"
      is_enabled=false
    elif [[ "$line" =~ "Status".*"✔" ]]; then
      is_enabled=true
    fi
  done <<< "$raw_output"

  if [[ -n "$current_plugin" && "$is_enabled" == true ]]; then
    plugins+=("$current_plugin")
  fi

  if [[ ${#plugins[@]} -eq 0 ]]; then
    echo "${YELLOW}   ⚠️  No enabled plugins found${NC}"
    return
  fi

  local total=${#plugins[@]}
  local updated=0
  local failed=0
  local index=0

  for plugin in "${plugins[@]}"; do
    ((index++))
    echo "${BLUE}   [${index}/${total}] ${CYAN}${plugin}${BLUE} — updating...${NC}"
    if [[ -n "$TIMEOUT_CMD" ]]; then
      $TIMEOUT_CMD 60 "$CLAUDE_BIN" plugin update "$plugin" < /dev/null > /dev/null 2>&1
    else
      "$CLAUDE_BIN" plugin update "$plugin" < /dev/null > /dev/null 2>&1
    fi
    if [[ $? -eq 0 ]]; then
      echo "${GREEN}         ✔ updated${NC}"
      ((updated++))
    else
      echo "${YELLOW}         ⚠️  failed${NC}"
      ((failed++))
    fi
  done

  echo ""
  if [[ $failed -eq 0 ]]; then
    echo "${GREEN}   ✅ ${updated}/${total} plugins updated — restart Claude Code to apply${NC}"
  else
    echo "${YELLOW}   ⚠️  ${updated}/${total} updated, ${failed} failed — restart Claude Code to apply${NC}"
  fi
}

function startotel() {
  local compose_file="/Users/jessdelgadoperez/projects/drata/claude-code-otel-dist/docker-compose.yml"

  echo ""
  echo "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
  echo "${BOLD}${BLUE}📡 Start OTEL Stack${NC}"
  echo "${BLUE}   Compose file: ${CYAN}${compose_file}${NC}"
  echo "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
  echo ""

  local services
  services=$(docker compose -f "$compose_file" config --services 2>/dev/null)
  local total
  total=$(echo "$services" | grep -c .)
  local running
  running=$(docker compose -f "$compose_file" ps --status running --format json 2>/dev/null | wc -l | tr -d ' ')

  if [[ "$running" -ge "$total" && "$total" -gt 0 ]]; then
    echo "${GREEN}✓ OTEL stack already running${NC} ${CYAN}(${running}/${total} services)${NC}"
  else
    echo "${BLUE}▸ Stack not fully up:${NC} ${CYAN}${running}/${total} services running${NC}"
    echo ""

    # Pre-clean orphan containers holding our fixed container_names but not tracked by this compose project.
    # docker-compose.yml uses `container_name: <name>` literals, so a stale container from a prior
    # project name (e.g. when the compose-file path changed) collides with `up -d`.
    echo "${BLUE}▸ Checking for orphan containers with conflicting names...${NC}"
    local project
    project=$(docker compose -f "$compose_file" ps --format json 2>/dev/null | python3 -c 'import json,sys
try:
  data=sys.stdin.read().strip()
  if not data: sys.exit(0)
  for line in data.splitlines():
    obj=json.loads(line)
    print(obj.get("Project","")); break
except Exception: pass' 2>/dev/null)

    local removed_count=0
    local svc
    for svc in ${(f)services}; do
      local owner
      owner=$(docker inspect --format '{{ index .Config.Labels "com.docker.compose.project" }}' "$svc" 2>/dev/null)
      if [[ -n "$owner" && -n "$project" && "$owner" != "$project" ]]; then
        echo "${YELLOW}  ⚠ Removing orphan '${svc}'${NC} ${CYAN}(project='${owner}', expected='${project}')${NC}"
        docker rm -f "$svc" >/dev/null 2>&1 && ((removed_count++))
      elif [[ -n "$owner" && -z "$project" ]]; then
        echo "${YELLOW}  ⚠ Removing stale '${svc}'${NC} ${CYAN}(project='${owner}')${NC}"
        docker rm -f "$svc" >/dev/null 2>&1 && ((removed_count++))
      fi
    done

    if [[ "$removed_count" -eq 0 ]]; then
      echo "${GREEN}  ✓ No conflicting containers found${NC}"
    else
      echo "${GREEN}  ✓ Removed ${removed_count} conflicting container(s)${NC}"
    fi
    echo ""

    echo "${BLUE}▸ Starting compose stack...${NC}"
    if ! docker compose -f "$compose_file" up -d; then
      echo ""
      echo "${YELLOW}⚠ compose up failed — force-removing named containers and retrying...${NC}"
      for svc in ${(f)services}; do
        docker rm -f "$svc" >/dev/null 2>&1
      done
      echo ""
      echo "${BLUE}▸ Retrying compose up...${NC}"
      if docker compose -f "$compose_file" up -d; then
        echo "${GREEN}✓ Stack started on retry${NC}"
      else
        echo "${RED}✗ Stack failed to start${NC}"
      fi
    else
      echo "${GREEN}✓ Stack started${NC}"
    fi
  fi
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

  local TIMESTAMP_FILE="${HOME}/.cache/shell-update-timestamps/updatelibs"

  echo ""
  echo "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
  echo "${BOLD}${BLUE}🔄 Update All Libraries & Tools${NC}"
  if [[ -f "$TIMESTAMP_FILE" ]]; then
    echo "${BLUE}   Last run: ${CYAN}$(cat "$TIMESTAMP_FILE")${NC}"
  else
    echo "${BLUE}   Last run: ${CYAN}Never${NC}"
  fi
  echo "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
  echo ""

  # Node.js
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[1/9] Install latest ${CYAN}node${NC}"
  echo "${BLUE}==============================================================================${NC}"
  if fnm use lts-latest --corepack-enabled --install-if-missing 2>&1; then
    echo "${GREEN}✅ Now on Node $(fnm current)${NC}"
  else
    echo "${YELLOW}⚠️  Failed to update Node.js${NC}"
  fi
  echo ""

  # npm
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[2/9] Update ${CYAN}npm${NC}"
  echo "${BLUE}==============================================================================${NC}"
  if npm update -g 2>&1; then
    echo "${GREEN}✅ npm updated${NC}"
  else
    echo "${YELLOW}⚠️  Failed to update npm${NC}"
  fi
  echo ""

  # Oh My Zsh plugins
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[3/9] Update ${CYAN}Oh My Zsh plugins${NC}"
  echo "${BLUE}==============================================================================${NC}"
  updategitdirectory $ZSH_CUSTOM/plugins "plugin" "$CLEAN_LIBS"

  # Project repositories
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[4/9] Update ${CYAN}project repositories${NC}"
  echo "${BLUE}==============================================================================${NC}"
  updategitdirectory $HOME/projects "lib" "$CLEAN_LIBS"

  # Dracula themes
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[5/9] Update ${CYAN}Dracula themes${NC}"
  echo "${BLUE}==============================================================================${NC}"
  updategitdirectory $HOME/projects/dracula "theme" "$CLEAN_LIBS"

  gohome

  # Homebrew
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[6/9] Update & upgrade ${CYAN}Homebrew${NC}"
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

  # Claude
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[7/9] Update ${CYAN}Claude${NC}"
  echo "${BLUE}==============================================================================${NC}"
  claude update
  echo ""
  updateclaudeplugins
  echo ""

  # Memory Bank
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[8/9] Ensure ${CYAN}Memory Bank${NC}"
  echo "${BLUE}==============================================================================${NC}"
  ensuredocker
  ensurememorybank
  echo ""

  # OTEL Stack
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}[9/9] Ensure ${CYAN}OTEL Stack${NC}"
  echo "${BLUE}==============================================================================${NC}"
  startotel

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
  mkdir -p "$(dirname "$TIMESTAMP_FILE")"
  date > "$TIMESTAMP_FILE"
}

function lastupdated() {
  local updatelibs_file="${HOME}/.cache/shell-update-timestamps/updatelibs"
  local updatedrat_file="${HOME}/.cache/shell-update-timestamps/updatedrat"

  echo ""
  echo "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
  echo "${BOLD}${BLUE}🕐 Last Update Timestamps${NC}"
  echo "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"

  if [[ -f "$updatelibs_file" ]]; then
    echo "${BLUE}  updatelibs:  ${CYAN}$(cat "$updatelibs_file")${NC}"
  else
    echo "${BLUE}  updatelibs:  ${YELLOW}Never${NC}"
  fi

  if [[ -f "$updatedrat_file" ]]; then
    echo "${BLUE}  updatedrat:  ${CYAN}$(cat "$updatedrat_file")${NC}"
  else
    echo "${BLUE}  updatedrat:  ${YELLOW}Never${NC}"
  fi

  echo "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
  echo ""
}
