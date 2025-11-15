#!/bin/bash

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.sh"

# Check if Xcode Command Line Tools are installed
if ! xcode-select -p &>/dev/null; then
  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} Would install Xcode Command Line Tools\n"
    echo -e "${YELLOW}[DRY-RUN]${NC} Would wait for installation to complete\n"
  else
    loginfo "Xcode Command Line Tools are not installed"
    loginstall "xcode command line tools"

    xcode-select --install

    # Wait for installation to complete
    if [ "${NON_INTERACTIVE:-false}" = "true" ]; then
      loginfo "Waiting for Xcode Command Line Tools installation (non-interactive mode)"
      # Poll until installation is complete (timeout after 10 minutes)
      timeout=600
      elapsed=0
      while ! xcode-select -p &>/dev/null; do
        if [ $elapsed -ge $timeout ]; then
          logerror "Xcode Command Line Tools installation timed out after 10 minutes"
          exit 1
        fi
        sleep 5
        elapsed=$((elapsed + 5))
      done
    else
      # Interactive mode - wait for user confirmation
      echo ""
      echo -e "${BLUE}Please complete the installation in the dialog box that appears.${NC}"
      echo -e "${BLUE}Press Enter when installation is complete...${NC}"
      read -r
    fi

    # Verify installation was successful
    if xcode-select -p &>/dev/null; then
      logsuccess "Xcode Command Line Tools installed successfully"
    else
      logerror "Failed to install Xcode Command Line Tools"
      printf "Please try running: ${GREEN}xcode-select --install${NC}"
      exit 1
    fi
  fi
else
  loginfo "Xcode Command Line Tools are already installed"
fi
