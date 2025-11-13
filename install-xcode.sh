#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.sh"

# Check if Xcode Command Line Tools are installed
if ! xcode-select -p &>/dev/null; then
  printf "${YELLOW}Xcode Command Line Tools are not installed${NC}\n"
  loginstall "xcode"
  xcode-select --install

  # Wait for the user to complete the installation
  printf "${BLUE}Please complete the installation in the dialog box that appears, then press Enter to continue.${NC}\n"
  read -r

  # Re-check if installation was successful
  if xcode-select -p &>/dev/null; then
    printf "${GREEN}Xcode Command Line Tools have been successfully installed.${NC}\n"
  else
    printf "${RED}Failed to install Xcode Command Line Tools.${NC}\n"
    exit 1
  fi
else
  printf "${BLUE}Xcode Command Line Tools are already installed.${NC}\n"
fi
