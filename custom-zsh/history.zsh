export HISTFILE=$HOME/.zsh_history # Save the history in your home directory as .zsh_history
export HISTSIZE=50000
export SAVEHIST=$HISTSIZE
setopt share_history               # Share history between sessions
setopt hist_expire_dups_first      # Remove duplicates first when HISTSIZE is met
setopt hist_ignore_dups            # If the same command is issued multiple times in a row, ignore the dupes
setopt hist_verify                 # Allow editing the command before executing upon retrieval from thie history
setopt hist_ignore_space           # Do not add commands prefixed with a space to the history
