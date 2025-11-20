# Force Flag Implementation for Dorothy CLI

## Overview

Added `--force` / `-f` flag to Dorothy CLI to enable forced reinstallation of components, with initial implementation for Dracula themes. This addresses the need to update themes without requiring interactive mode.

## Problem Statement

**Original Issue:** "It should also have the option to override the already installed theme as well, for updates"

When Dracula Pro was already installed, there was no way to:
- Update to a newer version (after downloading new Dracula Pro zip)
- Repair corrupted theme files
- Force a clean reinstall without manual intervention

## Solution

Implemented a `--force` flag that:
1. Works with any component (extensible design)
2. Functions in both interactive and non-interactive modes
3. Propagates through environment variables to child scripts
4. Provides clear messaging about forced operations

## Usage Examples

```bash
# Force reinstall Dracula themes
dorothy install dracula --force

# Preview what would be reinstalled
dorothy install dracula --force --dry-run
```

## When to Use --force

1. **Theme Updates**: After downloading a new Dracula Pro zip file
2. **Repair Corrupted Files**: If theme files were manually edited
3. **Clean Reinstall**: After testing changes or troubleshooting
4. **Switching Variants**: Ensure latest theme variant is installed

## Files Modified

1. `dorothy` - Added --force flag support and help text
2. `install-dracula.sh` - Respect FORCE_INSTALL environment variable
3. `DOROTHY.md` - Documented --force flag usage

## Testing Results

✅ Normal install skips when already installed
✅ Dry-run with --force shows force behavior
✅ Actual force install reinstalls both themes
✅ Help text properly documents the flag

## Future Extensibility

The pattern can be applied to other components by checking `${FORCE_INSTALL:-false}`
