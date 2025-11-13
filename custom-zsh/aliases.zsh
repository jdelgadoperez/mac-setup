######################################################################################
# Aliases
# All system, navigation, git, development, and configuration aliases
######################################################################################

## System
alias restart="sudo shutdown -r now"
alias flushdns="sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
alias cl="clear"
alias speed="speedtest $@"

## Navigation
PROJ_DIR="$HOME/projects"
alias gohome="cd $HOME/"
alias proj="cd $PROJ_DIR"
alias quadbox="cd $HOME/Library/Application\ Support/iTerm2/Scripts && python quad_box.py && cd -"

## Git
alias gitpersonal="git config --global user.email '$GIT_PERSONAL_EMAIL'"
alias gbc="gb --show-current"
alias sgbp="showgitbranch $PROJ_DIR"
alias gcmsga="gc --amend -m $@"
alias grfsch="grf show --date=iso | grep 'checkout'"
alias gres="g restore $@"
alias gsft="grhs HEAD~1"

## Development tools
alias npmg="npm $@ -g --depth=0"
alias pkgscripts="jq '.scripts' package.json"
alias clearnodemodules="find . -type d -name node_modules -prune -exec rm -rf {} \;"
alias formatchanges="gd --name-only --diff-filter=ACMRT main...HEAD | grep '\.\(js\|ts\|css\)$' | xargs prettier --write --ignore-path .gitignore"
alias lintfixchanges="gd --name-only --diff-filter=ACMRT main...HEAD | grep '\.\(js\|ts\)$' | xargs -I{} sh -c 'NODE_OPTIONS=\"--max-old-space-size=8192\" eslint --fix \"{}\"'"
alias lspipenv='for venv in $HOME/.local/share/virtualenvs/* ; do basename $venv; cat $venv/.project | sed "s/\(.*\)/\t\1\n/" ; done'
alias rmpipenv="rm -rf $HOME/.local/share/virtualenvs/$@"
alias rmawsenv="unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE"
alias clearawscache="rm -rf $HOME/.aws/cli/cache"
alias navicheats="cd ~/.local/share/navi/cheats"

## Open config files
alias omzconfig="code $HOME/.oh-my-zsh"
alias zshconfig="code $HOME/.zshrc"
alias starconfig="code $HOME/.config/starship.toml"
alias npmconfig="code $HOME/.npmrc"
alias sshconfig="code $HOME/.ssh/config"
alias hosts="code /etc/hosts"
alias gitconfig="code $HOME/.gitconfig"
alias dbconfig="code /opt/homebrew/etc/my.cnf"
alias dockerconfig="code $HOME/.docker/config.json"
alias itermscripts="code $HOME/Library/Application\ Support/iTerm2/Scripts"
alias awsconfig="code ~/.aws"
alias brewconfig="code /opt/homebrew/etc/my.cnf"

## Quad terminal
alias quadconfig="cd $HOME/Library/Application\ Support/iTerm2/Scripts && code quadbox.py && cd -"
