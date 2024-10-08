#!/bin/bash

# Customize fzf
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
  cd) fzf --preview 'eza --tree --color=always {} | head -200' "$@ " ;;
  export | unset) fzf --preview "eval 'echo \$'{}" "$@" ;;
  ssh) fzf --preview 'dig {}' "$@" ;;
  cat | bat) fzf --preview 'bat -n --color=always --style=numbers {}' "$@ " ;;
  *) fzf --preview '$FZF_PREVIEW {}' "$@" ;;
  esac
}
