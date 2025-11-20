# Dorothy CLI Reference

Your friendly macOS development environment setup assistant.

## Installation

```bash
sh ./install-dorothy.sh
```

This creates a symlink in `/usr/local/bin/dorothy` making it accessible globally.

## Commands

### `dorothy install`

Install components with flexible options:

```bash
dorothy install                    # Full setup (prompts for confirmation)
dorothy install --interactive      # Guided installation
dorothy install --dry-run          # Preview without executing
dorothy install brew zsh           # Install specific components
dorothy install brew --apps        # Install brew + GUI applications
dorothy install dracula --force    # Force reinstall Dracula theme
dorothy install --help             # Show install help
```

**Available Components:**
- `xcode` - XCode Command Line Tools
- `brew` - Homebrew and packages
- `git` - Git configuration
- `zsh` - Zsh and Oh My Zsh
- `dracula` - Dracula theme for iTerm2
- `dotfiles` - Symlink dotfiles to $HOME

**Options:**
- `-i, --interactive` - Interactive mode with prompts
- `-d, --dry-run` - Preview changes without executing
- `-f, --force` - Force reinstall even if already installed (useful for updates)
- `--apps` - Include GUI applications (1Password, VS Code, etc.)
- `--no-apps` - Skip GUI applications (default)

**When to use --force:**
- Update Dracula theme to latest version from a new zip file
- Repair corrupted or modified theme files
- Switch between Dracula theme variants
- Re-apply installation after manual changes

### `dorothy update`

Update all managed tools and dependencies:

```bash
dorothy update                     # Update everything
dorothy update --dry-run           # Preview updates
dorothy update --clean             # Clean reinstall of dependencies
```

Updates:
- Homebrew packages
- Oh My Zsh
- Custom Zsh files
- Project dependencies (via `updatelibs` if available)

**Note:** For theme updates, use `dorothy install dracula --force` after downloading a new Dracula Pro zip file.

### `dorothy list`

List all components and their installation status:

```bash
dorothy list
```

Shows:
- ✓ Installed components (green)
- ✗ Not installed components (red)

### `dorothy sync`

Sync dotfiles by creating symlinks from `dotfiles/` to `$HOME`:

```bash
dorothy sync                       # Sync dotfiles
dorothy sync --dry-run             # Preview what would be synced
```

### `dorothy doctor`

Check system health and diagnose issues:

```bash
dorothy doctor
```

Checks:
- XCode Command Line Tools
- Homebrew (version and outdated packages)
- Git (installation and configuration)
- Zsh and Oh My Zsh
- Default shell
- Dotfiles symlinks
- Starship prompt

Provides suggestions for fixing issues.

### `dorothy help`

Show help information:

```bash
dorothy help                       # General help
dorothy install --help             # Install command help
dorothy update --help              # Update command help
```

### `dorothy version`

Show version information:

```bash
dorothy version
```

## Global Options

These options work with any command:

- `-i, --interactive` - Run in interactive mode with prompts
- `-d, --dry-run` - Preview changes without executing
- `-h, --help` - Show help for a specific command
- `-v, --version` - Show version information

## Examples

### First-time Setup

**Interactive (recommended for beginners):**
```bash
dorothy install --interactive
```

**Preview before installing:**
```bash
dorothy install --dry-run
```

**Full install with GUI apps:**
```bash
dorothy install --apps
```

### Selective Installation

**Just the essentials:**
```bash
dorothy install xcode brew git
```

**Development environment only:**
```bash
dorothy install brew zsh dotfiles
```

**Install brew with apps:**
```bash
dorothy install brew --apps
```

### Maintenance

**Check system health:**
```bash
dorothy doctor
```

**Update everything:**
```bash
dorothy update
```

**Sync dotfiles after editing:**
```bash
dorothy sync
```

### Advanced Usage

**Preview a full install with apps:**
```bash
dorothy install --dry-run --apps
```

**Clean update (reinstall dependencies):**
```bash
dorothy update --clean
```

**Preview dotfiles sync:**
```bash
dorothy sync --dry-run
```

## Architecture

Dorothy is a lightweight Bash CLI that:
1. Sources `shared.sh` for common utilities and colors
2. Provides subcommand routing for clean UX
3. Wraps existing installation scripts with better ergonomics
4. Adds interactive mode, dry-run, and health checks
5. Enables component selection and status tracking

It doesn't replace the existing scripts - it enhances them with:
- Better discoverability (help menus)
- Safety (dry-run mode, confirmations)
- Diagnostics (doctor command)
- Convenience (interactive mode, selective install)

## Troubleshooting

**Command not found after installation:**
```bash
# Check if symlink exists
ls -la /usr/local/bin/dorothy

# Ensure /usr/local/bin is in PATH
echo $PATH | grep /usr/local/bin

# Re-run installation
sh ./install-dorothy.sh
```

**"No such file or directory" when running dorothy:**
This was fixed in the latest version. If you see this error, the dorothy script couldn't find `shared.sh`. The fix ensures the script properly resolves symlinks to find its actual location.

```bash
# Re-install dorothy to get the fix
sh ./install-dorothy.sh

# Or if already installed, the symlink will use the updated script automatically
```

**Permission errors:**
```bash
# Make dorothy executable
chmod +x ./dorothy

# Re-install globally
sh ./install-dorothy.sh
```

**Component detection issues:**
- Run `dorothy doctor` to see what's detected
- Some components may show as "not installed" if installed in non-standard locations
- The detection logic is in the `is_installed()` function in `dorothy`

**Dracula theme installation issues:**

The Dracula installer supports both the free theme and Dracula Pro. Common issues:

1. **Dracula Pro not installing - wrong filename:**
   - The installer looks for: `dracula-pro.zip`, `Dracula PRO Archive.zip`, or `dracula_pro.zip`
   - Download location must be: `~/Downloads/`
   - If your file has a different name, rename it to one of the above

2. **Checking if Dracula Pro is installed:**
   ```bash
   ls -la ~/.oh-my-zsh/custom/themes/ | grep dracula
   # Should show dracula-pro.zsh-theme (Pro) or dracula.zsh-theme (free)
   ```

3. **Dracula Pro already extracted:**
   - If `~/projects/dracula-pro/` exists with theme files, run `dorothy install dracula`
   - The installer will detect the existing installation and offer to reinstall
   - Theme file location: `~/projects/dracula-pro/themes/zsh/dracula-pro.zsh-theme`

4. **Manual Dracula Pro installation:**
   ```bash
   # If you have the zip file but installer didn't work:
   cd ~/Downloads
   unzip "Dracula PRO Archive.zip" -d ~/projects/dracula-pro
   cp ~/projects/dracula-pro/themes/zsh/dracula-pro.zsh-theme ~/.oh-my-zsh/custom/themes/
   ```

5. **Activating the theme:**
   - Edit `~/.zshrc` and set: `ZSH_THEME="dracula-pro"` (or `"dracula"` for free)
   - Run: `exec zsh` to reload

6. **Confusing output during installation:**
   - The installer now provides clearer messages about what's already installed
   - In interactive mode, it will prompt before reinstalling existing themes
   - In non-interactive mode, it skips Pro installation but reports if already installed

7. **Forcing a reinstall or update:**
   ```bash
   # Force reinstall both free and Pro themes
   dorothy install dracula --force
   
   # This will:
   # - Reinstall free Dracula theme even if already present
   # - Re-extract and reinstall Dracula Pro if zip file is available
   # - Update themes to latest version from zip archive
   ```

## Development

The Dorothy CLI is a single Bash script located at `./dorothy`.

Key sections:
- Lines 9-16: Symlink resolution (critical for global installation)
- Lines 24-128: Help documentation
- Lines 130-169: Component management (detection, listing, selection)
- Lines 171-239: Installation functions
- Lines 241-599: Command handlers (install, update, list, sync, doctor)
- Lines 601-650: Main entry point and argument parsing

**Important Technical Details:**

The script uses a robust symlink resolution pattern (lines 9-16) to ensure it can find its dependencies (`shared.sh`, installation scripts) even when installed globally via symlink:

```bash
# Resolve the actual script directory, following symlinks
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
```

This allows:
- Global installation via `/usr/local/bin/dorothy` symlink
- Script can always find its actual location
- Dependencies (shared.sh, install scripts) are properly sourced

To modify:
1. Edit `./dorothy`
2. Test with `./dorothy <command>`
3. If globally installed, changes take effect immediately (it's a symlink)
