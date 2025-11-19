# Bash configuration for interactive shells
# Note: This user primarily uses zsh. This file is kept for bash compatibility.

# Source .env if it exists
if [ -f "$HOME/.oh-my-zsh/custom/.env" ]; then
  source "$HOME/.oh-my-zsh/custom/.env"
fi

####################
## Development Tools
####################

# Editor configuration
if command -v code &> /dev/null; then
  export EDITOR='code --wait'
elif command -v vim &> /dev/null; then
  export EDITOR='vim'
else
  export EDITOR='nano'
fi

# Dracula theme for BSD grep
export GREP_COLOR="1;38;2;255;85;85"
export RIPGREP_CONFIG_PATH="$HOME/.config/.ripgreprc"

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

# Personal bin
export PATH="$HOME/bin:$PATH"

####################
## Interactive Tools (bash compatible)
####################

# fnm (Fast Node Manager)
if command -v fnm &> /dev/null; then
  eval "$(fnm env --use-on-cd)"
fi

# pyenv (interactive initialization)
if command -v pyenv &> /dev/null; then
  eval "$(pyenv init -)"
fi

# fzf key bindings and fuzzy completion
if command -v fzf &> /dev/null; then
  eval "$(fzf --bash)"
fi

# zoxide (cd replacement)
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init bash --cmd cd)"
fi

# Starship prompt
if command -v starship &> /dev/null; then
  eval "$(starship init bash)"
fi

# 1Password CLI completion
if command -v op &> /dev/null; then
  source <(op completion bash)
  export OP_BIOMETRIC_UNLOCK_ENABLED=true
fi
