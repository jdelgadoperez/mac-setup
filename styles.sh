#!/bin/bash

PADDING="-36"

BOLD=$(tput bold)
NORMAL=$(tput sgr0) # Reset all styles
COLOR_OFF='\033[0m' # Text Reset
NC=$COLOR_OFF       # Reset color
COLOR_END="\e[0m"

# Regular Colors
BLACK='\033[0;30m'   
BLUE='\033[0;34m'    
CYAN='\033[0;36m'    
GREEN='\033[0;32m'    
MAGENTA='\033[0;35m'
PURPLE='\033[0;35m'   
RED='\033[0;31m'   
WHITE='\033[0;37m'
YELLOW='\033[0;33m'

# Bold
BOLD_BLACK='\033[1;30m'    
BOLD_RED='\033[1;31m'      
BOLD_GREEN='\033[1;32m'    
BOLD_YELLOW='\033[1;33m'   
BOLD_BLUE='\033[1;34m'     
BOLD_PURPLE='\033[1;35m'   
BOLD_CYAN='\033[1;36m'     
BOLD_WHITE='\033[1;37m'    

GITHUB="https://github.com"
GITHUB_RAW="https://raw.githubusercontent.com"
DIR_CONFIG="~/.config"
DIR_PROJECTS="~/projects"
DIR_DRACULA="$DIR_PROJECTS/dracula"
THEME_PRO="dracula-pro"
DIR_DRACULA_PRO="$DIR_PROJECTS/$THEME_PRO"
