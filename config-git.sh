#!/bin/bash

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.sh"

# Validate required environment variables
if [ -z "$GIT_PERSONAL_NAME" ] || [ -z "$GIT_PERSONAL_EMAIL" ]; then
  logerror "Missing required environment variables for Git configuration"
  printf "\n"
  printf "${YELLOW}Please create a .env file with the following variables:${NC}\n"
  printf "  ${GREEN}GIT_PERSONAL_NAME${NC}=\"Your Name\"\n"
  printf "  ${GREEN}GIT_PERSONAL_EMAIL${NC}=\"your@email.com\"\n"
  printf "\n"
  printf "${BLUE}You can copy the example file:${NC}\n"
  printf "  cp .env.example .env\n"
  printf "\n"
  exit 1
fi

loginfo "Configuring Git"

GITCONFIG_SOURCE="$SCRIPT_DIR/dotfiles/.gitconfig"
GITCONFIG_TARGET="$HOME/.gitconfig"
GITCONFIG_LOCAL="$HOME/.gitconfig.local"

OP_SSH_SIGN="/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
ALLOWED_SIGNERS="$HOME/.ssh/allowed_signers"

if [ "${DRY_RUN:-false}" = "true" ]; then
  printf "${YELLOW}[DRY-RUN]${NC} Would create symlink: .gitconfig -> %s\n" "$GITCONFIG_SOURCE"
  printf "${YELLOW}[DRY-RUN]${NC} Would write .gitconfig.local with:\n"
  printf "${YELLOW}[DRY-RUN]${NC}   user.name = %s\n" "$GIT_PERSONAL_NAME"
  printf "${YELLOW}[DRY-RUN]${NC}   user.email = %s\n" "$GIT_PERSONAL_EMAIL"
  if [ -n "${GIT_SIGNING_KEY:-}" ]; then
    printf "${YELLOW}[DRY-RUN]${NC}   user.signingkey = %s\n" "$GIT_SIGNING_KEY"
  fi
  if [ -f "$OP_SSH_SIGN" ]; then
    printf "${YELLOW}[DRY-RUN]${NC}   gpg.ssh.program = %s\n" "$OP_SSH_SIGN"
  fi
  if [ -f "$ALLOWED_SIGNERS" ]; then
    printf "${YELLOW}[DRY-RUN]${NC}   gpg.ssh.allowedSignersFile = %s\n" "$ALLOWED_SIGNERS"
  fi
else
  # Symlink shared .gitconfig
  if [ -e "$GITCONFIG_TARGET" ] || [ -L "$GITCONFIG_TARGET" ]; then
    rm -f "$GITCONFIG_TARGET"
  fi
  ln -s "$GITCONFIG_SOURCE" "$GITCONFIG_TARGET"
  logsuccess "Symlinked .gitconfig"

  # Create .gitconfig.local only if it doesn't already exist
  if [ -f "$GITCONFIG_LOCAL" ]; then
    loginfo ".gitconfig.local already exists, skipping (edit manually or delete to regenerate)"
  else
    {
      echo "[user]"
      echo "    name = $GIT_PERSONAL_NAME"
      echo "    email = $GIT_PERSONAL_EMAIL"
      if [ -n "${GIT_SIGNING_KEY:-}" ]; then
        echo "    signingkey = $GIT_SIGNING_KEY"
      fi

      if [ -f "$OP_SSH_SIGN" ]; then
        echo "[gpg \"ssh\"]"
        echo "    program = \"$OP_SSH_SIGN\""
      fi

      if [ -f "$ALLOWED_SIGNERS" ]; then
        # Append allowedSignersFile under [gpg "ssh"] if not already written
        if [ ! -f "$OP_SSH_SIGN" ]; then
          echo "[gpg \"ssh\"]"
        fi
        echo "    allowedSignersFile = \"$ALLOWED_SIGNERS\""
      fi
    } > "$GITCONFIG_LOCAL"

    logsuccess "Created .gitconfig.local with user: $GIT_PERSONAL_NAME <$GIT_PERSONAL_EMAIL>"
  fi
fi
