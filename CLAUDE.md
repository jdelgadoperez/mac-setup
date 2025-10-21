# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a macOS development environment setup and dotfiles repository. It automates the installation and configuration of development tools, shell customizations, and system settings for a new or existing Mac.

## Architecture

### Installation Flow

The main entry point is `run.sh`, which orchestrates the setup in this order:
1. XCode Command Line Tools (`install-xcode.sh`)
2. Homebrew and packages (`install-brew.sh`)
3. Git configuration (`config-git.sh`)
4. Zsh and Oh My Zsh (`install-zsh.sh`)
5. Dracula theme (`install-dracula.sh`)

### Directory Structure

- **`dotfiles/`**: Source dotfiles that get symlinked to `$HOME`
  - `.zshrc` - Main Zsh configuration with lazy-loading patterns for performance
  - `.config/` - Application configs (starship, ripgrep, 1Password agent)
  - `.gitconfig` - Git configuration
  - `iterm2/` - iTerm2 preferences

- **`custom-zsh/`**: Modular Zsh functionality files sourced by Oh My Zsh
  - `aliases.zsh` - System, navigation, git, and development aliases
  - `development.zsh` - Package management utilities (npm/yarn/pnpm detection, `cleanpkgs`, `updatelibs`)
  - `git-tools.zsh` - Git helpers (`gccd`, `showgitbranch`, `getcommitcount`, etc.)
  - `system-tools.zsh` - System utilities (`cleansys`, `viewports`, `listhelpers`, `brew_installed`)
  - `utilities.zsh` - General helper functions
  - `styles.zsh` - Color definitions and theming
  - `history.zsh` - History configuration
  - `nerdtopia.zsh` - Nerd font and display utilities
  - `zsh-syntax-highlighting.zsh` - Syntax highlighting customization

- **`ai/`**: AI tool configurations (MCP plugins for Claude Desktop)

- **`scripts/`**: macOS system preference automation

- **`shared.sh`**: Common bash utilities used across installation scripts (color definitions, logging functions, directory variables)

- **`env.sh`**: Environment variable definitions (sourced by `shared.sh`)

### Key Design Patterns

**Lazy Loading**: The `.zshrc` uses `zsh-lazyload` to defer initialization of heavy tools (pyenv, pnpm, java, kubernetes) until first use. This keeps shell startup fast.

**Modular Zsh Files**: Custom Zsh functionality is split into focused files under `custom-zsh/` rather than one monolithic config. These are automatically sourced by Oh My Zsh.

**Dotfile Management**: Dotfiles in `dotfiles/` are meant to be symlinked to `$HOME`, not copied. This allows easy version control of system configs.

**Package Manager Detection**: Functions like `getlocktype()` automatically detect whether a project uses npm, yarn, or pnpm by checking for lockfiles.

## Common Commands

### Installation
```bash
# Run full setup (installs everything)
sh ./run.sh

# Run individual installers
sh ./install-xcode.sh
sh ./install-brew.sh true    # Pass 'true' to install apps
sh ./config-git.sh
sh ./install-zsh.sh
sh ./install-dracula.sh
```

### Development Helpers (from custom-zsh/)

```bash
# Clean and rebuild node_modules with auto-detected package manager
cleanpkgs [npm|yarn|pnpm]    # Auto-detects if not specified

# Update all projects, plugins, themes, and tools
updatelibs                   # Normal update
updatelibs clean             # Clean reinstall of all dependencies

# Clone and cd into repo
gccd <git-repo-url>

# Show current branch for all repos in a directory
showgitbranch ~/projects

# System cleanup (caches, logs, docker, etc.)
cleansys

# List all custom helpers
listhelpers aliases          # Show all aliases
listhelpers functions        # Show all custom functions
listhelpers parameters       # Show all custom parameters

# View ports in use
viewports [TCP|UDP|*]

# Show Homebrew formula install times (newest first)
brew_installed
```

### Environment Variables (defined in env.sh)

- `DIR_ROOT` - User home directory root
- `DIR_PROJECTS` - `$DIR_ROOT/projects`
- `DIR_CONFIG` - `$DIR_ROOT/.config`
- `ZSH_CUSTOM` - `$DIR_ROOT/.oh-my-zsh/custom`
- `DIR_DRACULA` - Dracula theme directory
- `GITHUB_RAW` - Base URL for raw GitHub content

## Important Context

### Symlink Setup
The install scripts create symlinks from `dotfiles/` to `$HOME`. When modifying dotfiles, edit the source files in this repo's `dotfiles/` directory.

### Multi-Machine Support
The repository supports both Intel and Apple Silicon Macs via the `getmactype()` function. Homebrew paths are configured for Apple Silicon (`/opt/homebrew`).

### Custom Zsh Files Location
During `install-zsh.sh`, files from `custom-zsh/` are copied to `$ZSH_CUSTOM/` (typically `~/.oh-my-zsh/custom/`), where Oh My Zsh automatically sources them.

### Performance Optimization
The `.zshrc` uses lazy loading for heavy tools. To profile shell startup:
```bash
ZPROF=true zsh    # Shows profiling output
```
