#!/bin/bash

source ./shared.sh

# Check if Xcode Command Line Tools are installed
if ! xcode-select -p &>/dev/null; then
  echo "${BOLD_YELLOW}Xcode Command Line Tools are not installed${NORMAL}"
  loginstall "xcode"
  xcode-select --install

  # Wait for the user to complete the installation
  echo "${BOLD}Please complete the installation in the dialog box that appears, then press Enter to continue.${NORMAL}"
  read -r

  # Re-check if installation was successful
  if xcode-select -p &>/dev/null; then
    echo "${BOLD_GREEN}Xcode Command Line Tools have been successfully installed.${NORMAL}"
  else
    echo "${BOLD_RED}Failed to install Xcode Command Line Tools.${NORMAL}"
    exit 1
  fi
else
  echo "${BOLD}Xcode Command Line Tools are already installed.${NORMAL}"
fi
