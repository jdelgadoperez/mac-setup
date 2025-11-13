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

# fnm - interactive shell initialization
eval "$(fnm env --use-on-cd)"

# 1Password
source $HOME/.config/op/plugins.sh
eval "$(op completion zsh)"
compdef _op op
export OP_BIOMETRIC_UNLOCK_ENABLED=true

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

if [[ "$ZPROF" = true ]]; then
  zprof
fi
