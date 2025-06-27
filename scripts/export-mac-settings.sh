#!/bin/bash

# Global macOS UI/UX settings
defaults read NSGlobalDomain >macos-global.plist

# Finder settings
defaults read com.apple.finder >macos-finder.plist

# Dock settings
defaults read com.apple.dock >macos-dock.plist

# Trackpad
defaults read com.apple.AppleMultitouchTrackpad >macos-trackpad.plist

# Keyboard
defaults read com.apple.keyboard >macos-keyboard.plist

# Power management
pmset -g custom >macos-pmset.txt

# Network hostname
scutil --get HostName >macos-hostname.txt

# Screenshot settings
defaults read com.apple.screencapture >macos-screencapture.plist

# Gatekeeper (e.g., app install permissions)
spctl --status >macos-gatekeeper.txt

echo "✅ Settings exported."
