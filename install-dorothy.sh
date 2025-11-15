#!/bin/bash

###############################################################################
# Install Dorothy CLI globally                                               #
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.sh"

BIN_DIR="/usr/local/bin"
DOROTHY_PATH="$SCRIPT_DIR/dorothy"
LINK_PATH="$BIN_DIR/dorothy"

# Check if dorothy exists
if [ ! -f "$DOROTHY_PATH" ]; then
  logerror "Dorothy script not found at: $DOROTHY_PATH"
  exit 1
fi

# Check if /usr/local/bin exists
if [ ! -d "$BIN_DIR" ]; then
  loginfo "Creating $BIN_DIR"
  sudo mkdir -p "$BIN_DIR"
fi

# Remove existing symlink if it exists
if [ -L "$LINK_PATH" ]; then
  loginfo "Removing existing dorothy symlink"
  sudo rm "$LINK_PATH"
elif [ -f "$LINK_PATH" ]; then
  logerror "A file already exists at $LINK_PATH (not a symlink)"
  logerror "Please remove it manually or install dorothy elsewhere"
  exit 1
fi

# Create symlink
loginfo "Installing dorothy to $BIN_DIR"
sudo ln -s "$DOROTHY_PATH" "$LINK_PATH"

# Verify installation
if command -v dorothy &> /dev/null; then
  logsuccess "Dorothy installed successfully!"
  echo ""
  printf "%s\n" "${BLUE}Try running:${NC}"
  printf "  %s - Show help\n" "${GREEN}dorothy help${NC}"
  printf "  %s - List components\n" "${GREEN}dorothy list${NC}"
  printf "  %s - Check system health\n" "${GREEN}dorothy doctor${NC}"
  printf "  %s - Interactive installation\n" "${GREEN}dorothy install -i${NC}"
else
  logerror "Installation failed. Dorothy command not found."
  exit 1
fi
