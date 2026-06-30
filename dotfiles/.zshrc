if [[ "$ZPROF" = true ]]; then
  zmodload zsh/zprof
fi

# Suppress zoxide's init-order doctor check. Our zoxide init is genuinely last,
# but Claude Code's spawned shell triggers a false-positive warning.
export _ZO_DOCTOR=0

# Path to your oh-my-zsh installation.
# Unset first to prevent conflicts with inherited ZSH variable during `exec zsh`
unset ZSH
export ZSH="$HOME/.oh-my-zsh"

# Source custom files
if [ -f "$ZSH/custom/.env" ]; then
  source "$ZSH/custom/.env"
fi
if [ -f "$ZSH/custom/styles.zsh" ]; then
  source "$ZSH/custom/styles.zsh"
fi

####################
## Oh My ZSH
####################
ZSH_THEME="dracula-pro" # backup: awesomepanda
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src
plugins=(git you-should-use zsh-lazyload)
plugins+=(zsh-syntax-highlighting zsh-history-substring-search zsh-autosuggestions)

# Skip insecure-directory audit on every startup (~40ms saved)
# ZSH_DISABLE_COMPFIX=true
# Pin to a stable filename — prevents cache rebuild when hostname changes
ZSH_COMPDUMP="$HOME/.zcompdump"

source $ZSH/oh-my-zsh.sh

####################
# User configuration
####################

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

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
# Skip --use-on-cd in Claude Code to prevent hang when cd-ing into dirs with .nvmrc
if [[ -n "$CLAUDECODE" ]]; then
  eval "$(fnm env)"
else
  eval "$(fnm env --use-on-cd)"
fi

# 1Password - lazy loaded
function loadOp() {
  # source $HOME/.config/op/plugins.sh
  if command -v op &>/dev/null; then
    eval "$(op completion zsh)"
    compdef _op op
  fi
  export OP_BIOMETRIC_UNLOCK_ENABLED=true
}
lazyload op -- 'loadOp'

# Dracula theme for BSD grep
export GREP_COLOR="1;38;2;255;85;85"
export RIPGREP_CONFIG_PATH="$HOME/.config/.ripgreprc"

####################
## Development Tools
####################

  # bun
function loadBun(){
  # bun completions
  [ -s "/Users/jessdelgadoperez/.bun/_bun" ] && source "/Users/jessdelgadoperez/.bun/_bun"

  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
}
lazyload bun -- 'loadBun'

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
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/shims:$PATH"

# Ruby
export GEM_HOME="$HOME/.gem/ruby/2.6.0"
export PATH="$GEM_HOME/bin:$PATH"

# Terraform
export PATH="$HOME/.terraform.versions:$PATH"

# Ansible config
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export no_proxy="*"

# Personal bin
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"

export GPG_TTY=$(tty)

# Source machine-specific overrides
if [ -f "$HOME/.zshrc.local" ]; then
  source "$HOME/.zshrc.local"
fi

if [[ "$ZPROF" = true ]]; then
  zprof
fi

# Enable zoxide, override `cd` — must be the LAST init line in this file
eval "$(zoxide init zsh --cmd cd)"
