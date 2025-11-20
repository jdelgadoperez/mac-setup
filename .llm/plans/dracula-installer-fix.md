# Dracula Installer Fix - Implementation Plan

## Problem Summary

The Dorothy CLI Dracula installer had several issues that made the output confusing and didn't properly handle Dracula Pro installation:

1. **Filename mismatch**: The script expected `dracula-pro.zip` but the actual file was named `Dracula PRO Archive.zip`
2. **Confusing output**: No clear indication when themes were already installed
3. **`echo -e` issues**: The `-e` flag was being printed literally instead of interpreted
4. **Poor status reporting**: Didn't clearly communicate success/failure or existing installations
5. **No update mechanism**: Interactive mode was required for Dracula Pro, and no way to force reinstall for updates

## Root Causes

### 1. Strict Filename Requirement
The original code only looked for one specific filename: `dracula-pro.zip`

### 2. echo -e Compatibility
The `echo -e` command doesn't work reliably across different shells (sh vs bash vs zsh). On some systems, it prints the literal `-e` flag.

### 3. Missing Status Checks
The script didn't check if themes were already installed before attempting to install them again.

### 4. No Force Reinstall Option
There was no way to force a reinstall of themes for updates or repairs, even when needed.

## Solutions Implemented

### 1. Flexible File Detection (`install-dracula.sh`)
Added support for multiple filename variations: `dracula-pro.zip`, `Dracula PRO Archive.zip`, and `dracula_pro.zip`

### 2. Replaced echo -e with printf
Changed all instances in both `install-dracula.sh` and `shared.sh` for better portability

### 3. Installation Status Checking
Added checks for existing installations with option to reinstall or keep existing

### 4. Clearer Status Messages
Enhanced output messages to clearly indicate what's installed, what's being skipped, and why

### 5. Improved Dorothy Detection (`dorothy`)
Updated the `is_installed` check for Dracula to verify actual theme files exist

### 6. Added --force Flag
Implemented `--force` / `-f` flag to allow reinstalling themes even when already installed:
- Useful for updating to new Dracula Pro versions
- Allows repairing corrupted theme files
- Works in both interactive and non-interactive modes
- Updates dry-run output to show force behavior

## Testing Results

### After Fix
- Clean output without `-e` flags
- Clear indication when themes are already installed
- Proper detection in `dorothy list`
- Better status reporting in both interactive and non-interactive modes

## Files Modified

1. `install-dracula.sh` - Multiple filename detection, printf conversion, status checking, force reinstall support
2. `shared.sh` - printf conversion for all logging functions
3. `dorothy` - Improved Dracula installation detection, added --force flag support
4. `DOROTHY.md` - New troubleshooting section for Dracula theme, documented --force flag

## User Resolution

Both Dracula themes are already installed:
- Dracula Pro: `~/.oh-my-zsh/custom/themes/dracula-pro.zsh-theme`
- Free Dracula: `~/.oh-my-zsh/custom/themes/dracula.zsh-theme`

To activate Dracula Pro, edit `~/.zshrc` and set `ZSH_THEME="dracula-pro"`, then run `exec zsh`

## Force Reinstall Feature

### Usage
```bash
# Force reinstall Dracula themes
dorothy install dracula --force

# Preview what would be reinstalled
dorothy install dracula --force --dry-run
```

### When to Use --force
- Update to a new version of Dracula Pro (after downloading new zip)
- Repair corrupted or manually modified theme files
- Switch between Dracula theme variants
- Re-apply clean installation after testing changes

### Implementation Details
- Added `FORCE_INSTALL` environment variable exported by Dorothy CLI
- Dracula installer checks `${FORCE_INSTALL:-false}` flag
- Skips "already installed" checks when force is enabled
- Re-extracts Dracula Pro zip and reinstalls theme files
- Works seamlessly with existing interactive/non-interactive modes
- Dry-run mode shows force behavior in preview
