if [[ "$ZPROF" = true ]]; then
  zmodload zsh/zprof
fi

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Source custom files
if [ -f "$ZSH/custom/styles.zsh" ]; then
  source "$ZSH/custom/styles.zsh"
fi
if [ -f "$ZSH/custom/.env" ]; then
  source "$ZSH/custom/.env"
fi

####################
## Oh My ZSH
####################
ZSH_THEME="dracula-pro" # backup: awesomepanda
plugins=()
plugins=(1password git dotenv fnm pyenv pipenv terraform you-should-use z zsh-lazyload)
plugins+=(zsh-syntax-highlighting zsh-autosuggestions zsh-history-substring-search)
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src
source $ZSH/oh-my-zsh.sh

####################
# User configuration
####################

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

# Enable zoxide, override `cd`
eval "$(zoxide init zsh --cmd cd)"

# Starship
eval "$(starship init zsh)"

# Enable fzf extensions
FZF_TAB_PLUGIN=$ZSH_CUSTOM/plugins/fzf-tab/fzf-tab.plugin.zsh
FZF_PREVIEW=$ZSH_CUSTOM/fzf-preview.sh
if test -f "$FZF_TAB_PLUGIN"; then
  source $FZF_TAB_PLUGIN
else
  echo "fzf-tab is not installed, install it from https://github.com/Aloxaf/fzf-tab and set FZF_TAB_PLUGIN"
fi

# 1Password
source $HOME/.config/op/plugins.sh
eval "$(op completion zsh)"
compdef _op op
export OP_BIOMETRIC_UNLOCK_ENABLED=true

# Dracula theme for BSD grep
export GREP_COLOR="1;38;2;255;85;85"
export RIPGREP_CONFIG_PATH="$HOME/.config/.ripgreprc"

####################
## Development Tools
####################

# fnm - interactive shell initialization
eval "$(fnm env --use-on-cd)"

# OrbStack - command-line tools and integration (if installed)
if [ -f "$HOME/.orbstack/shell/init.zsh" ]; then
  source ~/.orbstack/shell/init.zsh 2>/dev/null || :
fi

# Java - lazy loaded
function loadJava() {
  export JAVA_HOME=$(/usr/libexec/java_home)
  export PATH="/usr/local/opt/openjdk/bin:$PATH"
  export PATH="$HOME/.jenv/bin:$PATH"
  eval "$(jenv init -)"
}
lazyload java -- 'loadJava'

# Kubernetes - lazy loaded
function loadK8s() {
  # ref: https://kubecolor.github.io/setup/shells/zsh/
  # This needs to be added before "compdef kubecolor=kubectl"
  source <(kubectl completion zsh)
  # Make "kubecolor" borrow the same completion logic as "kubectl"
  compdef kubecolor=kubectl
}
lazyload kubectl -- 'loadK8s'

# Basher - lazy loaded
function loadBasher() {
  export PATH="$HOME/.basher/bin:$PATH" ##basher5ea843
  eval "$(basher init - zsh)"           ##basher5ea843
}
lazyload basher -- 'loadBasher'

# Editor configuration
if command -v code &> /dev/null; then
  export EDITOR='code --wait'
elif command -v vim &> /dev/null; then
  export EDITOR='vim'
else
  export EDITOR='nano'
fi

# Python tools
export LANG=en_US.UTF-8

# Ruby
export GEM_HOME="$HOME/.gem/ruby/2.6.0"
export PATH="$GEM_HOME/bin:$PATH"

# Terraform
export PATH="$HOME/.terraform.versions:$PATH"

# Ansible config
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export no_proxy="*"

# MySQL
export PATH="/opt/homebrew/opt/mysql@8.4/bin:$PATH"

# Personal bin
export PATH="$HOME/bin:$PATH"

if [[ "$ZPROF" = true ]]; then
  zprof
fi
