#!/bin/bash

source ./shared.sh

cp ./dotfiles/.gitconfig ~/
git config --global user.name $GIT_PERSONAL_NAME
git config --global user.email $GIT_PERSONAL_EMAIL
