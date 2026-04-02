# Homebrew - auto-detect architecture (Apple Silicon vs Intel)
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  # Apple Silicon
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x "/usr/local/bin/brew" ]]; then
  # Intel
  eval "$(/usr/local/bin/brew shellenv)"
fi

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
