# run.sh Improvements Summary

**Date**: 2025-11-14
**Status**: ✅ Complete

---

## Changes Made

### 1. Made run.sh Steps Optional ✅

**Before:**
```bash
# Hard-coded, runs everything sequentially
sh "$SCRIPT_DIR/install-xcode.sh"
sh "$SCRIPT_DIR/install-brew.sh" false
sh "$SCRIPT_DIR/config-git.sh"
sh "$SCRIPT_DIR/install-zsh.sh"
sh "$SCRIPT_DIR/install-dracula.sh"
```

**After:**
- ✅ Component selection via arguments
- ✅ Help menu (`--help`)
- ✅ Installation plan preview
- ✅ User confirmation before proceeding
- ✅ Flexible component combinations

**Usage Examples:**
```bash
# Install everything (default behavior)
sh ./run.sh

# Install only specific components
sh ./run.sh xcode brew git

# Install with GUI apps
sh ./run.sh --apps
sh ./run.sh brew --apps

# Show help
sh ./run.sh --help
```

---

### 2. Improved --apps Flag Handling ✅

**Problem:**
- `run.sh` hard-coded `false` for install-brew.sh
- Dorothy couldn't properly pass `--apps` flag to scripts
- No environment variable fallback

**Solution:**

#### Updated install-brew.sh
```bash
# Before
INSTALL_APPS="${1:-false}"

# After (supports both argument and env var)
INSTALL_APPS="${1:-${INSTALL_APPS:-false}}"
```

This means `install-brew.sh` now accepts apps flag in **3 ways**:
1. **Argument**: `sh ./install-brew.sh true`
2. **Environment variable**: `INSTALL_APPS=true sh ./install-brew.sh`
3. **Dorothy export**: `./dorothy install brew --apps`

#### Updated Dorothy
```bash
# Export INSTALL_APPS for scripts that need it
if [ "$install_apps" = "true" ]; then
  export INSTALL_APPS=true
fi

# Pass as argument for backward compatibility
sh "$SCRIPT_DIR/install-brew.sh" "$install_apps"
```

#### Updated run.sh
```bash
# Support --apps flag
INSTALL_APPS="${INSTALL_APPS:-false}"  # Default from env var

for arg in "$@"; do
  case $arg in
    --apps)
      INSTALL_APPS=true
      ;;
  esac
done

# Pass to install-brew.sh
sh "$SCRIPT_DIR/install-brew.sh" "$INSTALL_APPS"
```

---

## Features Added

### run.sh New Features

1. **Component Selection**
   - Choose specific components: `xcode`, `brew`, `git`, `zsh`, `dracula`
   - Or install `all` (default when no args provided)

2. **Options**
   - `--apps` - Install GUI applications
   - `--help` - Show usage information

3. **Environment Variables**
   - `INSTALL_APPS` - Set to `true` to install GUI apps

4. **Installation Plan**
   - Shows what will be installed before proceeding
   - User confirmation required (y/N)

5. **Error Handling**
   - `set -e` and `set -o pipefail` for fail-fast behavior
   - Helpful error messages for unknown components

6. **Smart Zsh Handling**
   - Only switches to zsh if needed for subsequent installations
   - Provides clear next steps if partial installation

---

## Testing Results ✅

### Test 1: Help Menu
```bash
$ sh ./run.sh --help
Mac Setup - Legacy Installation Script

USAGE:
  sh ./run.sh [components...] [options]

COMPONENTS:
  all          - Install everything (default)
  xcode        - XCode Command Line Tools
  brew         - Homebrew and packages
  git          - Git configuration
  zsh          - Zsh and Oh My Zsh
  dracula      - Dracula theme

OPTIONS:
  --apps       - Install GUI applications via Homebrew
  --help       - Show this help message
...
```

### Test 2: Dorothy with --apps
```bash
$ ./dorothy install brew --apps --dry-run
Installation Plan:
  [DRY RUN] brew
  ✓ GUI applications

→ Homebrew is already installed
[DRY-RUN] Would update Homebrew
[DRY-RUN] Would upgrade Homebrew packages
[DRY-RUN] Would install ~60 Homebrew packages
[DRY-RUN] Would install GUI applications  ← Works!
[DRY-RUN] Would install 1Password CLI
[DRY-RUN] Would run brew cleanup
```

### Test 3: Environment Variable
```bash
$ INSTALL_APPS=true DRY_RUN=true sh ./install-brew.sh
→ Homebrew is already installed
[DRY-RUN] Would update Homebrew
[DRY-RUN] Would upgrade Homebrew packages
[DRY-RUN] Would install ~60 Homebrew packages
[DRY-RUN] Would install GUI applications  ← Works!
[DRY-RUN] Would install 1Password CLI
[DRY-RUN] Would run brew cleanup
```

---

## Files Modified

1. ✅ **run.sh** - Complete rewrite with component selection
2. ✅ **install-brew.sh** - Environment variable fallback support
3. ✅ **dorothy** - Export INSTALL_APPS for scripts

---

## Usage Comparison

### Before
```bash
# Only one way to run:
sh ./run.sh              # Installs everything, no apps
sh ./install-brew.sh true  # Apps, but manual script call
```

### After
```bash
# Many flexible options:
sh ./run.sh                    # Install everything, no apps
sh ./run.sh --apps             # Install everything, with apps
sh ./run.sh xcode brew         # Selective install
sh ./run.sh brew --apps        # Brew with apps only
INSTALL_APPS=true sh ./run.sh  # Via environment variable

# Dorothy improvements:
./dorothy install brew --apps  # Now properly passes apps flag!
```

---

## Backward Compatibility ✅

All changes are **fully backward compatible**:

- ✅ `sh ./run.sh` still works (installs everything, no apps)
- ✅ `sh ./install-brew.sh false` still works (argument takes precedence)
- ✅ `sh ./install-brew.sh true` still works
- ✅ Existing Dorothy commands unchanged (`--apps` flag enhanced)

---

## Benefits

### For Users
1. **Flexibility** - Choose exactly what to install
2. **Clarity** - See installation plan before proceeding
3. **Safety** - Confirmation required before executing
4. **Convenience** - Multiple ways to specify apps flag

### For Dorothy CLI
1. **Proper Integration** - `--apps` flag now works correctly
2. **Consistency** - Environment variables work across all entry points
3. **Maintainability** - Cleaner code with better separation of concerns

### For CI/CD
1. **Scriptable** - Can be called with specific components
2. **Environment Variables** - Easy to configure via env vars
3. **Non-Interactive** - Works with Dorothy's `NON_INTERACTIVE` mode

---

## Examples

### Example 1: First-Time Setup (No Apps)
```bash
sh ./run.sh
# Shows: xcode, brew, git, zsh, dracula
# Confirm: y
# Installs everything without GUI apps
```

### Example 2: First-Time Setup (With Apps)
```bash
sh ./run.sh --apps
# Shows: xcode, brew, git, zsh, dracula, GUI applications
# Confirm: y
# Installs everything including 1Password, VS Code, etc.
```

### Example 3: Just Homebrew with Apps
```bash
sh ./run.sh brew --apps
# Shows: brew, GUI applications
# Confirm: y
# Installs only Homebrew and apps
```

### Example 4: Multiple Components, No Apps
```bash
sh ./run.sh xcode brew git
# Shows: xcode, brew, git
# Confirm: y
# Installs only those three components
```

### Example 5: Via Environment Variable
```bash
INSTALL_APPS=true sh ./run.sh
# Shows: xcode, brew, git, zsh, dracula, GUI applications
# Confirm: y
# Installs everything with apps
```

### Example 6: Dorothy with Apps (New!)
```bash
./dorothy install brew --apps
# Dorothy exports INSTALL_APPS=true
# Shows brew with GUI applications in plan
# Properly installs apps!
```

---

## Recommendations

### For run.sh Users
- Use `sh ./run.sh --help` to see all options
- Use component selection for partial installations
- Use `--apps` flag when you want GUI applications

### For Dorothy Users
- Prefer `dorothy install` for better UX
- Use `--apps` flag for GUI applications
- Use `--dry-run` to preview before installing

### For CI/CD
```bash
# Set environment variables
export NON_INTERACTIVE=true
export INSTALL_APPS=false
export DRY_RUN=false

# Run specific components
sh ./run.sh xcode brew git zsh
# or
./dorothy install xcode brew git zsh
```

---

## Next Steps (Optional)

### Potential Future Enhancements
1. Add `--skip-confirmation` flag for run.sh
2. Add progress indicators during installation
3. Add installation time estimates
4. Support for .runrc configuration file
5. Parallel component installation (where safe)

---

## Conclusion

The improvements to `run.sh` and the `--apps` flag handling significantly enhance the flexibility and usability of the mac-setup repository. Users now have:

- ✅ Full control over what gets installed
- ✅ Clear visibility into installation plans
- ✅ Multiple ways to specify GUI app installation
- ✅ Consistent behavior across run.sh, Dorothy, and direct script calls
- ✅ Complete backward compatibility

These changes complement the earlier optimizations and make the repository more professional and user-friendly while maintaining its simplicity and Bash-based approach.
