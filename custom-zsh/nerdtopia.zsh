######################################################################################
# Nerdtopia
## ref:
### https://www.daveyshafik.com/archives/70863-finding-terminal-utopia.html
### https://gist.github.com/dshafik/67fe3e0ba5096a00c91cccb0792a884b#file-zshrc
######################################################################################
alias cat=bat
alias lsz="eza --icons=always --color=always --git"
alias kubectl=kubecolor

# Enable history navigation using the up and down keys
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Enable using fzf preview with eza when using tab completion with `cd`
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:*' fzf-preview '$FZF_PREVIEW $realpath'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --all --tree --color=always --icons=always --git $realpath | head -200'
zstyle ':fzf-tab:*' switch-group '<' '>'

# Enable auto-complete of aliases
setopt complete_aliases

# Enable comments
setopt interactive_comments

# Tool Exports
export BAT_THEME="Monokai Extended Bright"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always {}'"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"
export FZF_DEFAULT_OPTS='--color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9 --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9 --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6 --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4'

function batdiff() {
  local diff_filter=${1:-d} # Default to "d" if no parameter is provided
  git diff --name-only --relative --diff-filter="$diff_filter" | xargs bat --diff
}

function batdiffbranch() {
  local branch1=${1:-main}
  local branch2=${2:-HEAD} # Default to HEAD if only one branch is provided
  git diff --name-only "$branch1...$branch2" | xargs bat --diff
}

# https://blog.mattclemente.com/2020/06/26/oh-my-zsh-slow-to-load/#how-to-test-your-shell-load-time
function timezsh() {
  shell=${1-$SHELL}
  for i in $(seq 1 10); do /usr/bin/time $shell -i -c exit; done
}

# https://blog.tarkalabs.com/optimize-zsh-fce424fcfd5#5038
function profzsh() {
  shell=${1-$SHELL}
  ZPROF=true $shell -i -c exit
}

######################################################################################
# Hooks
######################################################################################

function chpwd() {
  lsz -a
  echo ""
}
