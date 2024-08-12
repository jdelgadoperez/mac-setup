#!/bin/bash

source ./shared.sh

# Clone themes
cd ~/
createdirsafely "projects"
cd projects
createdirsafely "dracula"

## Get public dracula themes
loginstall "dracula themes"
REPO_DRACULA="$GITHUB/dracula"
git clone $REPO_DRACULA/gitkraken.git $DIR_DRACULA/gitkraken
git clone $REPO_DRACULA/visual-studio-code.git $DIR_DRACULA/visual-studio-code
git clone $REPO_DRACULA/xcode.git $DIR_DRACULA/xcode
git clone $REPO_DRACULA/zsh.git $DIR_DRACULA/zsh
git clone $REPO_DRACULA/zsh-syntax-highlighting.git $DIR_DRACULA/zsh-syntax-highlighting
cp $DIR_DRACULA/zsh-syntax-highlighting/zsh-syntax-highlighting.sh $ZSH_CUSTOM/zsh-syntax-highlighting.zsh

## Get dracula pro themes
loginstall "dracula pro themes"
curl -ofsSL $THEME_PRO.zip $THEME_PRO_URL
unzip $THEME_PRO.zip
cp $THEME_PRO/themes/zsh/$THEME_PRO.zsh-theme $ZSH_CUSTOM/themes/$THEME_PRO.zsh-theme
