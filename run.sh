#!/bin/bash

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.sh"

###############################################################################
# Legacy Setup Script (Runs full or partial installation)                    #
###############################################################################

# Default: install everything if no arguments provided
INSTALL_XCODE=true
INSTALL_BREW=true
INSTALL_GIT=true
INSTALL_ZSH=true
INSTALL_DRACULA=true
INSTALL_APPS="${INSTALL_APPS:-false}"  # Use env var or default to false

show_help() {
  cat << EOF
${BLUE}Mac Setup - Legacy Installation Script${NC}

${YELLOW}USAGE:${NC}
  sh ./run.sh [components...] [options]

${YELLOW}COMPONENTS:${NC}
  ${GREEN}all${NC}          - Install everything (default)
  ${GREEN}xcode${NC}        - XCode Command Line Tools
  ${GREEN}brew${NC}         - Homebrew and packages
  ${GREEN}git${NC}          - Git configuration
  ${GREEN}zsh${NC}          - Zsh and Oh My Zsh
  ${GREEN}dracula${NC}      - Dracula theme

${YELLOW}OPTIONS:${NC}
  ${GREEN}--apps${NC}       - Install GUI applications via Homebrew
  ${GREEN}--help${NC}       - Show this help message

${YELLOW}ENVIRONMENT VARIABLES:${NC}
  ${GREEN}INSTALL_APPS${NC} - Set to 'true' to install GUI apps (default: false)

${YELLOW}EXAMPLES:${NC}
  sh ./run.sh                    # Install everything (no apps)
  sh ./run.sh --apps             # Install everything (with apps)
  sh ./run.sh xcode brew git     # Install only xcode, brew, and git
  sh ./run.sh brew --apps        # Install only brew (with apps)
  INSTALL_APPS=true sh ./run.sh  # Install everything (with apps via env var)

${YELLOW}NOTE:${NC}
  For a better experience, use: ${GREEN}dorothy install${NC}
EOF
}

# Parse arguments
if [ $# -gt 0 ]; then
  # If arguments provided, disable all by default
  INSTALL_XCODE=false
  INSTALL_BREW=false
  INSTALL_GIT=false
  INSTALL_ZSH=false
  INSTALL_DRACULA=false

  # Parse each argument
  for arg in "$@"; do
    case $arg in
      --help|-h)
        show_help
        exit 0
        ;;
      --apps)
        INSTALL_APPS=true
        ;;
      all)
        INSTALL_XCODE=true
        INSTALL_BREW=true
        INSTALL_GIT=true
        INSTALL_ZSH=true
        INSTALL_DRACULA=true
        ;;
      xcode)
        INSTALL_XCODE=true
        ;;
      brew)
        INSTALL_BREW=true
        ;;
      git)
        INSTALL_GIT=true
        ;;
      zsh)
        INSTALL_ZSH=true
        ;;
      dracula)
        INSTALL_DRACULA=true
        ;;
      *)
        logerror "Unknown component: $arg"
        printf "Run 'sh ./run.sh --help' for usage information\n"
        exit 1
        ;;
    esac
  done
fi

# Show installation plan
echo ""
printf "%s\n" "${BLUE}Installation Plan:${NC}"
[ "$INSTALL_XCODE" = "true" ] && printf "  %s XCode Command Line Tools\n" "${GREEN}✓${NC}"
[ "$INSTALL_BREW" = "true" ] && printf "  %s Homebrew and packages\n" "${GREEN}✓${NC}"
[ "$INSTALL_APPS" = "true" ] && printf "  %s GUI Applications\n" "${GREEN}✓${NC}"
[ "$INSTALL_GIT" = "true" ] && printf "  %s Git configuration\n" "${GREEN}✓${NC}"
[ "$INSTALL_ZSH" = "true" ] && printf "  %s Zsh and Oh My Zsh\n" "${GREEN}✓${NC}"
[ "$INSTALL_DRACULA" = "true" ] && printf "  %s Dracula theme\n" "${GREEN}✓${NC}"
echo ""

# Confirm installation
read -p "${BLUE}Proceed with installation? (y/N):${NC} " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo -e "Installation cancelled."
  exit 0
fi

echo ""

# Run selected installations
[ "$INSTALL_XCODE" = "true" ] && sh "$SCRIPT_DIR/install-xcode.sh"
[ "$INSTALL_BREW" = "true" ] && sh "$SCRIPT_DIR/install-brew.sh" "$INSTALL_APPS"
[ "$INSTALL_GIT" = "true" ] && sh "$SCRIPT_DIR/config-git.sh"

# Install Zsh and switch to it
if [ "$INSTALL_ZSH" = "true" ]; then
  sh "$SCRIPT_DIR/install-zsh.sh"

  # Only exec zsh if we installed it and user wants to continue
  if [ "$INSTALL_DRACULA" = "true" ]; then
    echo ""
    printf "%s\n" "${BLUE}Zsh installed. Switching to Zsh to continue...${NC}"
    printf "%s\n" "${YELLOW}After switching, run: sh ./install-dracula.sh${NC}"
    exec zsh
  else
    echo ""
    logsuccess "Installation complete!"
    echo ""
    printf "%s\n" "${BLUE}Next steps:${NC}"
    printf "  1. Restart your terminal or run: %s\n" "${GREEN}exec zsh${NC}"
    printf "  2. Optionally run: %s\n" "${GREEN}sh ./install-dracula.sh${NC}"
  fi
else
  # Install Dracula without switching shells
  [ "$INSTALL_DRACULA" = "true" ] && sh "$SCRIPT_DIR/install-dracula.sh"

  echo ""
  logsuccess "Installation complete!"
fi
