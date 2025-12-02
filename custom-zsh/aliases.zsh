######################################################################################
# Aliases
# All system, navigation, git, development, and configuration aliases
######################################################################################

## System
alias cl="clear"
alias flushdns="sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
alias restart="sudo shutdown -r now"
alias speed="speedtest"

## Navigation
PROJ_DIR="$HOME/projects"
alias gohome="cd $HOME/"
alias navicheats="cd ~/.local/share/navi/cheats"
alias proj="cd $PROJ_DIR"
alias quadbox="cd $HOME/Library/Application\ Support/iTerm2/Scripts && python quad_box.py && cd -"

## Git
alias gitpersonal="git config --global user.email '$GIT_PERSONAL_EMAIL'"
alias gbc="gb --show-current"
alias gcmsga="gc --amend -m $@"
alias gres="g restore $@"
alias grfsch="grf show --date=iso | grep 'checkout'"
alias gsft="grhs HEAD~1"
alias sgbp="showgitbranch $PROJ_DIR"

## Development tools
alias clearawscache="rm -rf $HOME/.aws/cli/cache && rm -rf $HOME/.aws/sso/cache"
alias clearnodemodules="find . -type d -name node_modules -prune -exec rm -rf {} \;"
alias formatchanges="gd --name-only --diff-filter=ACMRT main...HEAD | grep '\.\(js\|ts\|css\)$' | xargs prettier --write --ignore-path .gitignore"
alias lintfixchanges="gd --name-only --diff-filter=ACMRT main...HEAD | grep '\.\(js\|ts\)$' | xargs -I{} sh -c 'NODE_OPTIONS=\"--max-old-space-size=8192\" eslint --fix \"{}\"'"
alias lspipenv='for venv in $HOME/.local/share/virtualenvs/* ; do basename $venv; cat $venv/.project | sed "s/\(.*\)/\t\1\n/" ; done'
alias npmg="npm $@ -g --depth=0"
alias pkgscripts="jq '.scripts' package.json"
alias rmawsenv="unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE"
alias rmpipenv="rm -rf $HOME/.local/share/virtualenvs/$@"
alias clearaws="clearawscache && rmawsenv"

## Open config files
alias awsconfig="code ~/.aws"
alias brewconfig="code /opt/homebrew/etc/my.cnf"
alias dbconfig="code /opt/homebrew/etc/my.cnf"
alias dockerconfig="code $HOME/.docker/config.json"
alias gitconfig="code $HOME/.gitconfig"
alias hosts="code /etc/hosts"
alias itermscripts="code $HOME/Library/Application\ Support/iTerm2/Scripts"
alias npmconfig="code $HOME/.npmrc"
alias omzconfig="code $HOME/.oh-my-zsh"
alias quadconfig="cd $HOME/Library/Application\ Support/iTerm2/Scripts && code quadbox.py && cd -"
alias sshconfig="code $HOME/.ssh/config"
alias starconfig="code $HOME/.config/starship.toml"
alias zshconfig="code $HOME/.zshrc"
alias claudecodeconfig="code $HOME/.claude.json"
alias claudeconfig="code $HOME/Library/Application Support/Claude/claude_desktop_config.json"
