######################################################################################
# Aliases
######################################################################################

## System
alias restart="sudo shutdown -r now"
alias flushdns="sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"

## Nav
alias gohome="cd $HOME/"
alias proj="cd $HOME/projects"

## Quad terminal
alias quadbox="cd $HOME/Library/Application\ Support/iTerm2/Scripts && python quadbox.py && cd -"
alias quadconfig="cd $HOME/Library/Application\ Support/iTerm2/Scripts && openvs quadbox.py && cd -"

## Git and auth
alias gitpersonal="git config --global user.email '$GIT_PERSONAL_EMAIL'"

## Misc
alias npmg="npm $@ -g --depth=0"
alias clearnodemodules="find . -type d -name node_modules -prune -exec rm -rf {} \;"
alias formatchanges="gd --name-only --diff-filter=ACMRT main...HEAD | grep '\.\(js\|ts\|css\)$' | xargs prettier --write --ignore-path .gitignore"
alias lspipenv='for venv in $HOME/.local/share/virtualenvs/* ; do basename $venv; cat $venv/.project | sed "s/\(.*\)/\t\1\n/" ; done'
alias rmpipenv="rm -rf $HOME/.local/share/virtualenvs/$@"

## Open config files
alias omzconfig="openvs ~/.oh-my-zsh"
alias zshconfig="openvs ~/.zshrc"
alias starconfig="openvs ~/.config/starship.toml"
alias npmconfig="openvs ~/.npmrc"
alias sshconfig="openvs ~/.ssh/config"
alias hosts="openvs /etc/hosts"
alias gitconfig="openvs ~/.gitconfig"
alias brewconfig="openvs /opt/homebrew/etc/my.cnf"
alias dockerconfig="openvs ~/.docker/config.json"

######################################################################################
# Functions
######################################################################################

## Global helpers
function ensurepy() {
  if command -v pyenv 1>/dev/null 2>&1 && [[ -z "$PYENV_ROOT" ]]; then
    pyenv
  fi
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

function updategitdirectory() {
  DIR_NAME="$1"
  LIB_TYPE="$2"

  echo "${BLUE}========================================================${NC}"
  echo "${BLUE}Go to ${CYAN}${DIR_NAME}${NC}"
  echo "${BLUE}========================================================${NC}"
  gotopathsafely $DIR_NAME
  echo ""
  local dirs=()
  for dir in */; do
    if [ -d "$dir" ]; then
      dirs+=("$dir")
    fi
  done

  for dir in "${dirs[@]}"; do
    echo "${BLUE}========================================================${NC}"
    echo "${BLUE}Update ${LIB_TYPE}: ${CYAN}${dir}${NC}"
    echo "${BLUE}========================================================${NC}"
    gotopathsafely $DIR_NAME/$dir
    if git rev-parse --is-inside-work-tree &>/dev/null; then
      echo ""
      echo "${BOLD_MAGENTA}Git branch: ${BOLD_GREEN}$(git branch --show-current)${NC}"
      echo ""
      gpr
      echo ""
      PKG_TYPE=$(getlocktype)
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
    echo ""
  done
}

function updatelibs() {
  echo "${BOLD_BLUE}========================================================${NC}"
  echo "${BOLD_BLUE}Install latest ${CYAN}node${NC}"
  echo "${BOLD_BLUE}========================================================${NC}"
  fnm use lts-latest --corepack-enabled --install-if-missing
  echo ""
  echo "${BOLD_BLUE}========================================================${NC}"
  echo "${BOLD_BLUE}Update ${CYAN}npm${NC}"
  echo "${BOLD_BLUE}========================================================${NC}"
  npm update -g
  echo ""
  updategitdirectory $ZSH_CUSTOM/plugins "plugin"
  echo ""
  updategitdirectory $HOME/projects "lib"
  echo ""
  updategitdirectory $HOME/projects/dracula-pro/themes "theme"
  echo ""
  gohome
  echo ""
  echo "${BOLD_BLUE}========================================================${NC}"
  echo "${BOLD_BLUE}Update ${CYAN}homebrew${NC}"
  echo "${BOLD_BLUE}========================================================${NC}"
  brew update
  echo ""
  echo "${BOLD_BLUE}========================================================${NC}"
  echo "${BOLD_BLUE}Cleanup ${CYAN}homebrew${NC}"
  echo "${BOLD_BLUE}========================================================${NC}"
  brew cleanup
}

function openvs() {
  open -a 'Visual Studio Code' $@
}

function mysqlrm() {
  OLD_VERSION=$1
  # Remove current mysql
  brew services stop $OLD_VERSION
  sleep 10
  sudo killall mysqld
  brew unlink $OLD_VERSION
  brew unpin $OLD_VERSION
  brew uninstall $OLD_VERSION
  brew cleanup
  # Remove remaining config
  sudo rm /opt/homebrew/etc/my.cnf
  sudo rm /opt/homebrew/etc/my.cnf.d
  sudo rm -rf /opt/homebrew/var/mysql
  sudo rm -rf /opt/homebrew/var/log/mysql*
  sudo rm -rf /opt/homebrew/var/mysql*
  sudo rm -rf /opt/homebrew/Cellar/mysql
  sudo rm -rf /opt/homebrew/opt/mysql
  sudo rm -f ~/Library/LaunchAgents/homebrew.mxcl.mysql.plist
  sudo rm -f /Library/LaunchDaemons/com.oracle.oss.mysql.mysqld.plist
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
    local target_file="${2:-.zsh_custom_tools}"
    case "$1" in
        aliases)
            print -rl -- ${(ko)aliases:#_*}
            ;;
        functions)
            local func
            for func in ${(ko)functions:#_*}; do
                local funcinfo=$(whence -v $func)
                local defined_file="${funcinfo#*from }"
                [[ $defined_file == *$target_file* ]] && echo "$func :: $defined_file"
            done
            ;;
        parameters)
            print -rl -- ${(ko)parameters:#_*}
            ;;
        *)
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
