# 1Password SSH Agent
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"

# fnm
export PATH="~/Library/Application Support/fnm:$PATH"

# GitHub packages
export NPM_TOKEN=$GIT_NPM_TOKEN

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

# Ensure bin
export PATH="$HOME/bin:$PATH"
