#!/bin/bash

source ./shared.sh

createdirsafely $DIR_PROJECTS
createdirsafely $DIR_DRACULA
createdirsafely $DIR_DRACULA_PRO

CUR_DIR="${PWD}"
echo -e "Current dir: ${BLUE}${CUR_DIR}${NC}"

## Get public dracula themes
loginstall "dracula themes"
REPO_DRACULA="$GITHUB/dracula"
git clone $REPO_DRACULA/gitkraken.git $DIR_DRACULA/gitkraken
git clone $REPO_DRACULA/sequel-ace.git $DIR_DRACULA/sequel-ace
git clone $REPO_DRACULA/visual-studio-code.git $DIR_DRACULA/visual-studio-code
git clone $REPO_DRACULA/xcode.git $DIR_DRACULA/xcode
git clone $REPO_DRACULA/zsh.git $DIR_DRACULA/zsh
git clone $REPO_DRACULA/zsh-syntax-highlighting.git $DIR_DRACULA/zsh-syntax-highlighting
cp $DIR_DRACULA/zsh-syntax-highlighting/zsh-syntax-highlighting.sh $ZSH_CUSTOM/zsh-syntax-highlighting.zsh

## Get dracula pro themes
loginstall "dracula pro themes"
cd $DIR_ROOT/Downloads
echo -e "${BLUE}Go to downloads${COLOR_OFF}"
pwd

if [ ! -f "$DIR_ROOT/Downloads/$THEME_PRO.zip" ]; then
  echo -e "${BLUE}CMD + Click the following link in order to download the archive. Once downloaded, press Enter to continue:${COLOR_OFF} ${THEME_PRO_URL}"
  read -r # Waits for Enter
  echo -e "${BLUE}Continuing dracula pro install${COLOR_OFF}"
  mv Archive.zip $THEME_PRO.zip
fi

unzip $DIR_ROOT/Downloads/$THEME_PRO.zip -d $DIR_DRACULA_PRO
cp $DIR_DRACULA_PRO/themes/zsh/$THEME_PRO.zsh-theme $ZSH_CUSTOM/themes/$THEME_PRO.zsh-theme
cd $CUR_DIR
