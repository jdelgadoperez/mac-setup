#!/bin/bash

# Apply plist settings
defaults import NSGlobalDomain macos-global.plist
defaults import com.apple.finder macos-finder.plist
defaults import com.apple.dock macos-dock.plist
defaults import com.apple.AppleMultitouchTrackpad macos-trackpad.plist
defaults import com.apple.keyboard macos-keyboard.plist
defaults import com.apple.screencapture macos-screencapture.plist

# Apply pmset (power management)
sudo pmset restoredefaults
while read -r line; do
  setting=$(echo "$line" | awk '{print $1}')
  value=$(echo "$line" | awk '{print $2}')
  sudo pmset -a "$setting" "$value"
done < <(grep -E '^\S+\s+\d+' macos-pmset.txt)

# Set hostname
sudo scutil --set HostName "$(cat macos-hostname.txt)"

# Gatekeeper status (optional, requires manual enable/disable)
echo "⚠️ Gatekeeper status saved as: $(cat macos-gatekeeper.txt)"
echo "Enable/disable with: sudo spctl --master-enable|--master-disable"

# Restart apps to apply
killall Finder
killall Dock

echo "✅ macOS settings applied."
