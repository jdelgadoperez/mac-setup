function generatehomebrewinstaller() {
  local output_file="${1:-install_homebrew_packages.zsh}"
  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  print "Generating Homebrew installation commands script: $output_file"
  print "Analyzing current Homebrew installation..."

  # Check if Homebrew is installed using zsh command check
  if ! (($+commands[brew])); then
    print "Error: Homebrew is not installed or not in PATH"
    return 1
  fi

  # Start creating the output script
  cat >"$output_file" <<EOF
#!/usr/bin/env zsh

# Homebrew Installation Commands
# Generated on: $timestamp
# Run this script on a new machine to install all your Homebrew packages

# ZSH options
setopt ERR_EXIT PIPE_FAIL

print "🍺 Installing Homebrew packages from your previous setup..."
print "Generated on: $timestamp"
print ""

# Install Homebrew if not present
if ! (( \$+commands[brew] )); then
    print "📦 Installing Homebrew..."
    /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for the current session
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "\$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "\$(/usr/local/bin/brew shellenv)"
    fi
else
    print "✅ Homebrew is already installed"
fi

# Update Homebrew
print "🔄 Updating Homebrew..."
brew update
print ""

EOF

  # Add taps
  print "Analyzing Homebrew taps..."
  local taps=$(brew tap)
  local tap_count=0

  if [[ -n "$taps" ]]; then
    print "# Add custom taps" >>"$output_file"
    print "print \"📋 Adding custom taps...\"" >>"$output_file"

    while IFS= read -r tap; do
      if [[ -n "$tap" && "$tap" != "homebrew/core" && "$tap" != "homebrew/cask" ]]; then
        print "brew tap $tap" >>"$output_file"
        ((tap_count++))
      fi
    done <<<"$taps"

    print "print \"\"" >>"$output_file"
    print "" >>"$output_file"
  fi

  # Add formulae (only top-level packages, not dependencies)
  print "Analyzing Homebrew formulae (top-level packages only)..."
  local formulae=$(brew leaves)
  local formula_count=0

  if [[ -n "$formulae" ]]; then
    print "# Install formulae (top-level packages only - dependencies will be installed automatically)" >>"$output_file"
    print "print \"🔧 Installing formulae (top-level packages)...\"" >>"$output_file"

    while IFS= read -r formula; do
      if [[ -n "$formula" ]]; then
        print "brew install $formula" >>"$output_file"
        ((formula_count++))
      fi
    done <<<"$formulae"

    print "print \"\"" >>"$output_file"
    print "" >>"$output_file"
  fi

  # Add casks
  print "Analyzing Homebrew casks..."
  local casks=$(brew list --cask 2>/dev/null)
  local cask_count=0

  if [[ -n "$casks" ]]; then
    print "# Install casks" >>"$output_file"
    print "print \"📱 Installing casks...\"" >>"$output_file"

    while IFS= read -r cask; do
      if [[ -n "$cask" ]]; then
        print "brew install --cask $cask" >>"$output_file"
        ((cask_count++))
      fi
    done <<<"$casks"

    print "print \"\"" >>"$output_file"
    print "" >>"$output_file"
  fi

  # Add cleanup
  cat >>"$output_file" <<'EOF'
# Cleanup
print "🧹 Cleaning up..."
brew cleanup

print "✅ All Homebrew packages installed!"
print "🩺 Run 'brew doctor' to check for any issues."
EOF

  # Make the script executable
  chmod +x "$output_file"

  # Generate summary
  print ""
  print "✅ Homebrew installation script generated: $output_file"
  print ""
  print "📊 Summary:"
  print "  - Custom taps: $tap_count"
  print "  - Formulae: $formula_count"
  print "  - Casks: $cask_count"
  print ""
  print "🚀 To use this script on a new machine:"
  print "  1. Copy $output_file to the new machine"
  print "  2. Run: chmod +x $output_file"
  print "  3. Run: ./$output_file"
  print ""
  print "💡 The script contains simple 'brew install' commands that you can also run individually."
}
