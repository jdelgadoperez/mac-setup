if [[ "$ZPROF" = true ]]; then
  zmodload zsh/zprof
fi

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

source $ZSH/custom/styles.zsh

# homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

####################
## Oh My ZSH
####################
ZSH_THEME="dracula-pro" # backup: awesomepanda
plugins=(1password git dotenv fnm kubectl yarn you-should-use z zsh-lazyload)
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

# fnm
export PATH="~/Library/Application Support/fnm:$PATH"
eval "$(fnm env --use-on-cd)"

## python tools
function loadPyTooling() {
  export LANG=en_US.UTF-8
  export PYENV_ROOT="$HOME/.pyenv"
  [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
  alias python="$(pyenv which python)"
  alias pip="$(pyenv which pip)"
  ## pipenv
  eval "$(_PIPENV_COMPLETE=zsh_source pipenv)"
}
lazyload pyenv -- 'loadPyTooling'

# ruby
export GEM_HOME="$HOME/.gem/ruby/2.6.0"
export PATH="$GEM_HOME/bin:$PATH"

# pnpm
function loadPnpm() {
  export PNPM_HOME="~/Library/pnpm"
  case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
  esac
  export PATH="./node_modules/.bin:$PATH"
}
lazyload pnpm -- 'loadPnpm'

# 1Password
function loadop() {
  source $HOME/.config/op/plugins.sh
  eval "$(op completion zsh)"
  compdef _op op
  export OP_BIOMETRIC_UNLOCK_ENABLED=true
}
lazyload op -- 'loadop'

# for GitHub packages
export NPM_TOKEN=$GIT_NPM_TOKEN

# for GitHub packages
# export NPM_TOKEN=<token>

# temporal
lazyload temporal -- 'source <(temporal completion zsh)'

function loadJava() {
  export JAVA_HOME=$(/usr/libexec/java_home)
  export PATH="/usr/local/opt/openjdk/bin:$PATH"
  export PATH="$HOME/.jenv/bin:$PATH"
  eval "$(jenv init -)"
}
lazyload java -- 'loadJava'

if [[ "$ZPROF" = true ]]; then
  zprof
fi
