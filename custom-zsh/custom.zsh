######################################################################################
# Aliases
######################################################################################

## System
alias cat=bat
alias lsz="eza --icons=always --color=always --git"
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

function updategitdirectory() {
  DIR_NAME="$1"
  LIB_TYPE="$2"
  echo "${BOLD}========================================================${NC}"
  echo "${BOLD}Go to ${CYAN}${DIR_NAME}${NC}"
  echo "${BOLD}========================================================${NC}"
  gotopathsafely $DIR_NAME
  echo ""
  local dirs=()
  for dir in */; do
    if [ -d "$dir" ]; then
      dirs+=("$dir")
    fi
  done

  for dir in "${dirs[@]}"; do
    echo "${BOLD}========================================================${NC}"
    echo "${BOLD}Update ${LIB_TYPE}: ${CYAN}${dir}${NC}"
    echo "${BOLD}========================================================${NC}"
    gotopathsafely $DIR_NAME/$dir
    if git rev-parse --is-inside-work-tree &>/dev/null; then
      echo ""
      echo "${BOLD_MAGENTA}Git branch: ${BOLD_GREEN}$(git branch --show-current)${NC}"
      echo ""
      gpr
    fi
    echo ""
  done
}

function updatelibs() {
  echo "${BOLD}========================================================${NC}"
  echo "${BOLD}Install latest ${CYAN}node${NC}"
  echo "${BOLD}========================================================${NC}"
  fnm use lts-latest --corepack-enabled --install-if-missing
  echo ""
  echo "${BOLD}========================================================${NC}"
  echo "${BOLD}Update ${CYAN}npm${NC}"
  echo "${BOLD}========================================================${NC}"
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
  echo "${BOLD}========================================================${NC}"
  echo "${BOLD}Update ${CYAN}homebrew${NC}"
  echo "${BOLD}========================================================${NC}"
  brew update
  echo ""
  echo "${BOLD}========================================================${NC}"
  echo "${BOLD}Cleanup ${CYAN}homebrew${NC}"
  echo "${BOLD}========================================================${NC}"
  brew cleanup
}

function openvs() {
  open -a 'Visual Studio Code' $@
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

######################################################################################
# Hooks
######################################################################################

function chpwd() {
  lsz -a
}
