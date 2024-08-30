#!/bin/bash

source ./shared.sh

# Check if Xcode Command Line Tools are installed
if ! xcode-select -p &>/dev/null; then
  echo "${YELLOW}Xcode Command Line Tools are not installed${NC}"
  loginstall "xcode"
  xcode-select --install

  # Wait for the user to complete the installation
  echo "${BLUE}Please complete the installation in the dialog box that appears, then press Enter to continue.${NC}"
  read -r

  # Re-check if installation was successful
  if xcode-select -p &>/dev/null; then
    echo "${GREEN}Xcode Command Line Tools have been successfully installed.${NC}"
  else
    echo "${RED}Failed to install Xcode Command Line Tools.${NC}"
    exit 1
  fi
else
  echo "${BLUE}Xcode Command Line Tools are already installed.${NC}"
fi
