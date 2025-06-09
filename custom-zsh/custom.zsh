######################################################################################
# Aliases
######################################################################################

## System
alias restart="sudo shutdown -r now"
alias flushdns="sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"

## Nav
PROJ_DIR="$HOME/projects"
alias gohome="cd $HOME/"
alias proj="cd $PROJ_DIR"

## Quad terminal
alias quadbox="cd $HOME/Library/Application\ Support/iTerm2/Scripts && python quad_box.py && cd -"

## Git
alias gitpersonal="git config --global user.email '$GIT_PERSONAL_EMAIL'"
alias gbc="gb --show-current"
alias sgbp="showgitbranch $PROJ_DIR"
alias gcmsga="gc --amend -m $@"
alias grfsch="grf show --date=iso | grep 'checkout'"
alias gres="g restore $@"

## Misc
alias cl="clear"
alias npmg="npm $@ -g --depth=0"
alias pkgscripts="jq '.scripts' package.json"
alias clearnodemodules="find . -type d -name node_modules -prune -exec rm -rf {} \;"
alias formatchanges="gd --name-only --diff-filter=ACMRT main...HEAD | grep '\.\(js\|ts\|css\)$' | xargs prettier --write --ignore-path .gitignore"
alias lintfixchanges="gd --name-only --diff-filter=ACMRT main...HEAD | grep '\.\(js\|ts\)$' | xargs -I{} sh -c 'NODE_OPTIONS=\"--max-old-space-size=8192\" eslint --fix \"{}\"'"
alias lspipenv='for venv in $HOME/.local/share/virtualenvs/* ; do basename $venv; cat $venv/.project | sed "s/\(.*\)/\t\1\n/" ; done'
alias rmpipenv="rm -rf $HOME/.local/share/virtualenvs/$@"
alias rmawsenv="unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE"
alias speed="speedtest-cli"

## Open config files
alias openvs="code $@"
alias omzconfig="code $HOME/.oh-my-zsh"
alias zshconfig="code $HOME/.zshrc"
alias starconfig="code $HOME/.config/starship.toml"
alias npmconfig="code $HOME/.npmrc"
alias sshconfig="code $HOME/.ssh/config"
alias hosts="code /etc/hosts"
alias gitconfig="code $HOME/.gitconfig"
alias dbconfig="code /opt/homebrew/etc/my.cnf"
alias dockerconfig="code $HOME/.docker/config.json"
alias itermscripts="code $HOME/Library/Application\ Support/iTerm2/Scripts"

######################################################################################
# Functions
######################################################################################

function ensurepy() {
  if command -v pyenv 1>/dev/null 2>&1 && [[ -z "$PYENV_ROOT" ]]; then
    echo "${BLUE}==============================================================================${NC}"
    echo "${BLUE}Init ${CYAN}pyenv${NC}"
    echo "${BLUE}==============================================================================${NC}"
    pyenv
  fi
}

function cleanpkgs() {
  echo -e "${GREEN}Clearing node modules...${NC}"
  clearnodemodules
  echo -e "${GREEN}Node modules cleared${NC}"
  echo ""
  pkgman=$1
  buildCmd="build"
  prebuildCmd="prebuild"

  if [ "$pkgman" = '' ]; then
    pkgman="yarn"
  fi

  if [ "$pkgman" = 'yarn' ]; then
    ycc
    ensurepy
    yii
  fi

  if [ "$pkgman" = 'npm' ]; then
    echo ""
    npm install
  fi

  if [ "$pkgman" = 'pnpm' ]; then
    rm pnpm-lock.yaml
    buildCmd="build:all"
    prebuildCmd="prebuild:all"
    echo ""
    pnpm install
  fi

  if pkgscripts | jq -e --arg script "$prebuildCmd" 'has($script)' >/dev/null; then
    echo ""
    "$pkgman" "$prebuildCmd"
  fi
  if pkgscripts | jq -e --arg script "$buildCmd" 'has($script)' >/dev/null; then
    echo ""
    "$pkgman" "$buildCmd"
  fi
}

function delete_writable_recursive() {
  local target_dir="$1"
  echo -e "${GREEN}Cleaning: $target_dir${NC}"
  find "$target_dir" -mindepth 1 -exec bash -c '
    for path; do
      if [ -w "$path" ]; then
        echo "Deleting: $path"
        rm -rf "$path"
      else
        echo "Skipped (not permitted): $path"
      fi
    done
  ' bash {} +
}

function cleansys() {
  delete_writable_recursive ~/Library/Caches
  delete_writable_recursive ~/Library/Logs
  delete_writable_recursive "~/Library/Saved Application State"
  delete_writable_recursive ~/Library/Developer/Xcode/DerivedData
  delete_writable_recursive ~/.Trash
  # echo -e "${GREEN}Emptying volume trash...${NC}"
  # sudo rm -rf /Volumes/*/.Trashes
  echo -e "${GREEN}Clearing docker data...${NC}"
  docker image prune -f
  docker container prune -f
  docker volume prune -f
  echo -e "${GREEN}System cleaned${NC}"
}

function createdirsafely() {
  DIR_NAME=$@
  if [ ! -d "$DIR_NAME" ]; then
    mkdir -p "$DIR_NAME"
    echo "Directory created: $GREEN $DIR_NAME $NC"
  fi
}

function gotopathsafely() {
  specific_path="$1"
  current_path=$(pwd)
  if [ "$current_path" != "$specific_path" ]; then
    cd "$specific_path"
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

function showgitbranch() {
  DIR_NAME="$1"
  LIB_TYPE="$2"
  starting_path=$(pwd)
  local original_chpwd=$(declare -f chpwd)
  unset -f chpwd

  if [ ! -d "$DIR_NAME" ]; then
    echo "${RED}Directory not found: ${DIR_NAME}${NC}"
    return 1
  fi

  echo "${BLUE}Checking git branches in ${CYAN}${DIR_NAME}${NC}"
  cd "$DIR_NAME" 2>/dev/null || return 1

  echo "${BLUE}Go to ${CYAN}${DIR_NAME}${NC}"
  gotopathsafely $DIR_NAME
  local dirs=()
  for dir in */; do
    if [ -d "$dir" ]; then
      dirs+=("$dir")
    fi
  done

  for dir in "${dirs[@]}"; do
    echo ""
    gotopathsafely $DIR_NAME/$dir
    if git rev-parse --is-inside-work-tree &>/dev/null; then
      echo "${BLUE}Repo: ${CYAN}${dir}${NC}"
      echo "${BOLD_MAGENTA}Branch: ${BOLD_GREEN}$(gbc)${NC}"
    fi
  done

  if [ "$starting_path" != "$(pwd)" ]; then
    cd $starting_path
  fi
  eval "$original_chpwd"
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
        cleanpkgs "$PKG_TYPE"
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
  ensurepy
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
  gohome
  echo ""
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}Update ${CYAN}homebrew${NC}"
  echo "${BLUE}==============================================================================${NC}"
  brew update
  echo ""
  echo "${BLUE}==============================================================================${NC}"
  echo "${BLUE}Cleanup ${CYAN}homebrew${NC}"
  echo "${BLUE}==============================================================================${NC}"
  brew cleanup
}

function listAlfredWorkflows() {
  for plist in ~/Library/Application\ Support/Alfred/Alfred.alfredpreferences/workflows/*/info.plist; do
    name=$(defaults read "$plist" name 2>/dev/null)
    bundleid=$(defaults read "$plist" bundleid 2>/dev/null)
    echo "$name — $bundleid"
  done
}

function listAlfredWorkflowIds() {
  cd ~/Library/Application\ Support/Alfred/Alfred.alfredpreferences/workflows
  find user.workflow.* -type f -name info.plist | while read -r plist; do
    name=$(/usr/libexec/PlistBuddy -c "Print name" "$plist" 2>/dev/null)
    if [[ -n "$name" ]]; then
      uuid_folder=$(echo "$plist" | cut -d'/' -f1)
      echo "$uuid_folder → $name"
    fi
    cd -
  done
}

function mysqlrm() {
  OLD_VERSION=$1
  # Remove current mysql
  brew services stop $OLD_VERSION
  sleep 10
  sudo killall mysqld
  brew unlink --force $OLD_VERSION
  brew unpin --force $OLD_VERSION
  brew uninstall $OLD_VERSION
  brew cleanup
  brew doctor

  # Remove remaining config
  sudo rm -f /opt/homebrew/etc/my.cnf
  sudo rm -rf /opt/homebrew/etc/my.cnf.d
  sudo rm -rf /opt/homebrew/var/mysql
  sudo rm -rf /opt/homebrew/var/log/mysql*
  sudo rm -rf /opt/homebrew/var/mysql*
  sudo rm -rf /opt/homebrew/Cellar/mysql
  sudo rm -rf /opt/homebrew/Cellar/mysql-client
  sudo rm -rf /opt/homebrew/opt/mysql
  sudo rm -f ~/Library/LaunchAgents/homebrew.mxcl.mysql.plist
  sudo rm -f /Library/Launch{Agents,Daemons}/*mysql*
  sudo rm -f /private/etc/mysql*

  # remove any simlinks that point to old mysql
  cd /opt/homebrew/opt
  ls -latr mysql*
  cd -
}

function mysqladd() {
  NEW_VERSION=$1
  # Update and install new
  brew update
  brew install $NEW_VERSION
  brew link --force $NEW_VERSION
  brew pin $NEW_VERSION
  brew services start $NEW_VERSION
  sleep 10
  brew services list
}

function mysqlreplace() {
  OLD_VERSION=$1
  NEW_VERSION=$2
  # Remove current mysql
  mysqlrm $OLD_VERSION
  # Update and install new
  mysqladd $NEW_VERSION
}

function viewports() {
  # COMMAND, PID, USER, FD, TYPE, DEVICE, SIZE/OFF, NODE NAME
  types=$1
  if [ "$types" = '*' ]; then
    sudo lsof -i -n -P
  else
    if [ -z "$types" ]; then
      types="TCP"
    fi
    sudo lsof -i -n -P | grep "$types"
  fi
}

function listhelpers() {
  local target_dir="${2:-$ZSH_CUSTOM}" # Default to $ZSH_CUSTOM if no directory specified
  target_dir=$(realpath "$target_dir") # Get absolute path

  case "$1" in
  aliases)
    alias | cut -d'=' -f1 | sed 's/alias //' | grep -v '^_' | sort | column
    ;;
  functions)
    local func
    local output=()
    # Get all function names without leading underscore
    for func in $(declare -F | cut -d' ' -f3 | grep -v '^_'); do
      local funcinfo=$(type "$func" 2>/dev/null)
      if [[ $funcinfo == *"is a function"* ]]; then
        local source_file=$(type "$func" | grep -oP 'from \K.*' 2>/dev/null)
        if [[ -n "$source_file" ]]; then
          source_file=$(realpath "$source_file" 2>/dev/null)
          # Only include functions from the target directory
          if [[ $source_file == $target_dir* ]]; then
            output+=("$func :: ${source_file#$target_dir/}")
          fi
        fi
      fi
    done
    if ((${#output[@]})); then
      printf '%s\n' "${output[@]}" | sort | column -t -s '::'
    else
      echo "No functions found in $target_dir"
    fi
    ;;
  parameters)
    local output=()
    while IFS= read -r param; do
      if [[ -n "$param" ]]; then
        # Get the source file for this parameter
        local source_file=$(grep -l "^[[:space:]]*${param}=" "$target_dir"/* 2>/dev/null)
        if [[ -n "$source_file" ]]; then
          source_file=$(realpath "$source_file" 2>/dev/null)
          if [[ $source_file == $target_dir* ]]; then
            output+=("$param :: ${source_file#$target_dir/}")
          fi
        fi
      fi
    done < <(declare -p | cut -d' ' -f3 | cut -d= -f1 | grep -v '^_' | sort)

    if ((${#output[@]})); then
      printf '%s\n' "${output[@]}" | sort | column -t -s '::'
    else
      echo "No parameters found in $target_dir"
    fi
    ;;
  *)
    echo "Usage: listhelpers [aliases|functions|parameters] [directory]"
    echo "Examples:"
    echo "  listhelpers aliases"
    echo "  listhelpers functions $ZSH_CUSTOM"
    echo "  listhelpers parameters"
    return 1
    ;;
  esac
}

function dadjoke() {
  curl -s -H "Accept: text/plain" https://icanhazdadjoke.com/
}

function getabspath() {
  absolute_path=$(realpath $1)
  echo "Absolute path: ${absolute_path}"
}

function timestamp_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

function getmactype() {
  MY_MAC_CHIP=$(sysctl -n machdep.cpu.brand_string)
  MY_MAC_TYPE=""
  if [[ "$MY_MAC_CHIP" == *"Intel"* ]]; then
    MY_MAC_TYPE="Intel"
  elif [[ "$MY_MAC_CHIP" == *"Apple"* ]]; then
    MY_MAC_TYPE="Apple Silicon"
  else
    MY_MAC_TYPE="Unknown processor: $MY_MAC_CHIP"
  fi
  echo $MY_MAC_CHIP
  echo $MY_MAC_TYPE
}

function getcommitcount() {
  # Check if inside a Git repository
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Not inside a Git repository."
    exit 1
  fi

  # Get the author from arguments
  if [ -z "$1" ]; then
    echo "You must provide an author email or name."
    exit 1
  fi
  AUTHOR="$1"

  # Count commits by the specified author
  commit_count=$(git log --author="$AUTHOR" --pretty=oneline | wc -l)

  echo "Total commits by '$AUTHOR': $commit_count"
}

function getcommits() {
  # Check if inside a Git repository
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Not inside a Git repository."
    exit 1
  fi

  # Get the author from arguments
  if [ -z "$1" ]; then
    echo "You must provide an author email or name."
    exit 1
  fi
  AUTHOR="$1"

  # Count commits by the specified author
  git log --author="$AUTHOR" --pretty=oneline

  echo "Got all commits by '$AUTHOR'"
}

function getorgcommitcount() {
  AUTHOR="$1"
  ORG="$2"

  local original_chpwd=$(declare -f chpwd)
  unset -f chpwd

  total_commits=0
  total_repos=0

  local dirs=()
  for dir in */; do
    if [ -d "$dir" ]; then
      dirs+=("$dir")
    fi
  done

  for dir in "${dirs[@]}"; do
    echo "Processing $dir..."
    cd "$dir" || continue
    repo_commit_count=$(git log --author="$AUTHOR" --pretty=oneline | wc -l)
    total_commits=$((total_commits + repo_commit_count))
    if [[ $repo_commit_count -gt 0 ]]; then
      total_repos=$((total_repos + 1))
    fi
    cd ..
  done

  echo "Total commits of $total_commits by '$AUTHOR' in $total_repos repos in the '$ORG' org"
  eval "$original_chpwd"
}
