# Mac Setup

Automated macOS development environment configuration and dotfiles management. Transforms a fresh Mac into a fully-configured development workstation with one command.

## Prerequisites

- macOS (Intel or Apple Silicon)
- Admin access (some steps require `sudo`)
- Internet connection

No other tools need to be installed beforehand — the setup scripts bootstrap everything from a clean Mac.

## Quick Start

### Using Dorothy CLI (Recommended)

Dorothy is a friendly CLI that makes setup easier with interactive prompts, dry-run mode, and component selection.

**Install Dorothy:**
```bash
sh ./install-dorothy.sh
```

**Quick Examples:**
```bash
dorothy install --interactive    # Guided installation with prompts
dorothy install --dry-run        # Preview what would be installed
dorothy install brew zsh         # Install only specific components
dorothy update                   # Update all tools
dorothy doctor                   # Check system health
dorothy list                     # Show available components
```

**Available Commands:**
- `dorothy install` - Install components (full setup or selective)
- `dorothy update` - Update all managed tools and dependencies
- `dorothy sync` - Sync dotfiles (create symlinks)
- `dorothy local` - Manage machine-specific override files not tracked in git
- `dorothy list` - List available components and installation status
- `dorothy doctor` - System health check and diagnostics
- `dorothy help` - Show detailed help

**Options:**
- `-i, --interactive` - Interactive mode with guided prompts
- `-d, --dry-run` - Preview changes without executing
- `--apps` - Include GUI applications (1Password, VS Code, etc.)

### Using Scripts Directly (Alternative)

Run the complete setup:

```bash
sh ./run.sh
```

Or run individual installers:

```bash
sh ./install-xcode.sh       # XCode Command Line Tools
sh ./install-brew.sh true   # Homebrew + packages (pass 'true' to install GUI apps)
sh ./config-git.sh          # Git configuration
sh ./install-zsh.sh         # Zsh + Oh My Zsh + plugins
sh ./install-dracula.sh     # Dracula theme for multiple apps
```

### After Installation

1. **Restart your shell** (or open a new terminal window) to load the new configuration:
   ```bash
   exec zsh
   ```
2. **Set up machine-specific config** (git identity, local overrides):
   ```bash
   dorothy local init    # Creates ~/.gitconfig.local, ~/.zshrc.local, etc.
   dorothy local edit git  # Add your name, email, and signing key
   ```
3. **Verify everything is healthy:**
   ```bash
   dorothy doctor
   ```

## What Gets Installed

### Development Tools & Languages

**Languages & Version Managers:**
- Node.js (via `fnm`)
- Python (via `pyenv`)
- Ruby (via `rbenv`)
- Go, PHP, Java

**Terminal Tools:**
- `bat`, `eza` - Enhanced cat/ls with syntax highlighting
- `fzf`, `zoxide` - Fuzzy finder and smart directory navigation
- `ripgrep`, `fd` - Fast search tools
- `starship` - Cross-shell prompt
- `btop`, `dust` - System monitoring and disk usage
- `jq`, `yq` - JSON/YAML processing

**Development Infrastructure:**
- Docker Desktop
- Terraform
- Kubernetes tools (`kubectl`, `k9s`, `kustomize`)
- AWS CLI

**Claude Code:**
- Claude Code CLI and personal configuration (settings, hooks, slash commands)

**Optional GUI Apps** (when `INSTALL_APPS=true`):
- 1Password, Alfred, Arc Browser
- Discord, Slack, Spotify
- VS Code, iTerm2, Ghostty, and more

### Shell Environment

**Zsh with Oh My Zsh** featuring:
- Performance-optimized with lazy loading for heavy tools
- Starship prompt with Dracula theme
- 10+ plugins: autosuggestions, syntax highlighting, fzf-tab, zoxide, etc.
- Custom helper functions for development workflows

**Dotfiles** symlinked to `$HOME`:
- `.zshrc` / `.bashrc` / `.zprofile` - Shell configuration
- `.gitconfig` - Git with GPG signing via 1Password
- `.config/starship.toml` - Prompt theme
- `.config/.ripgreprc` - Search tool config
- `.config/ghostty/` - Ghostty terminal config
- iTerm2 preferences

### Custom Zsh Functions

Modular functionality organized in `custom-zsh/`:

**Development Helpers:**
- `cleanpkgs` - Auto-detect package manager (npm/yarn/pnpm) and clean install
- `updatelibs` - Update all projects, plugins, and system tools
- `pkgscripts` - Display package.json scripts

**Git Tools:**
- `gccd <repo>` - Clone and cd into repo
- `showgitbranch <dir>` - Show current branch for all repos in directory
- `getcommitcount <author>` - Count commits by author
- `clone_org_repos <org> <repos...>` - Batch clone from organization

**System Utilities:**
- `cleansys` - Deep cleanup (caches, logs, docker, trash)
- `viewports [TCP|UDP]` - Display ports in use
- `listhelpers [aliases|functions|parameters]` - List all custom helpers
- `brew_installed` - Show Homebrew install times (newest first)
- `mysqlreplace <old> <new>` - MySQL version management

**Quick Access Aliases:**
- `proj` - Jump to projects directory
- `zshconfig`, `gitconfig`, `sshconfig` - Edit configs
- `formatchanges`, `lintfixchanges` - Format/lint git changes only

See `custom-zsh/` directory for complete list of functions and aliases.

## Repository Structure

```
mac-setup/
├── dorothy                   # Main CLI tool (install via install-dorothy.sh)
├── install-dorothy.sh        # Install Dorothy globally
├── run.sh                    # Legacy orchestrator script
├── install-*.sh              # Individual installation scripts
├── config-git.sh             # Git configuration
├── shared.sh                 # Common utilities and colors
├── env.sh                    # Environment variable loader
│
├── dotfiles/                 # Dotfiles to symlink to $HOME
│   ├── .zshrc
│   ├── .gitconfig
│   ├── .config/
│   └── iterm2/
│
├── custom-zsh/               # Modular Zsh functions (copied to ~/.oh-my-zsh/custom/)
│   ├── aliases.zsh
│   ├── development.zsh       # Package management, updatelibs
│   ├── git-tools.zsh         # Git helper functions
│   ├── system-tools.zsh      # System utilities
│   ├── utilities.zsh
│   └── ...
│
├── ai/
│   └── mcp-plugins.json      # Claude Desktop MCP servers config
│
└── scripts/                  # macOS system preference automation
```

## Configuration

### Environment Variables

Copy `custom-zsh/example.env` to `custom-zsh/.env` or `.env` and configure:

```bash
GIT_PERSONAL_EMAIL="your@email.com"
GIT_NPM_TOKEN="your_npm_token"
HOMEBREW_TOKEN="your_github_token"
```

These are sourced by `.zshrc` for Git, npm, and Homebrew authentication.

### Lazy Loading

The shell uses `zsh-lazyload` to defer initialization of heavy tools until first use:
- `pyenv` - Python version manager
- `pnpm` - Fast package manager
- `java` - Java environment (jenv)
- `kubectl` - Kubernetes CLI

To profile shell startup time:
```bash
ZPROF=true zsh
```

## Key Features

**Idempotent:** Scripts safely check before installing. Safe to re-run.

**Modular:** Run individual scripts or the full setup.

**Performance-Optimized:** Lazy loading keeps shell startup fast (~0.5s).

**Auto-Detection:** Package managers detected via lockfiles. Mac architecture detected for correct paths.

**AI-Ready:** Includes MCP (Model Context Protocol) plugin configs for Claude Desktop integration.

**Multi-Platform:** Supports both Intel and Apple Silicon Macs.

## Customization

### Adding Custom Functions

1. Add your function to an appropriate file in `custom-zsh/` (or create a new `.zsh` file)
2. Re-run `sh ./install-zsh.sh` to copy to `~/.oh-my-zsh/custom/`
3. Reload shell: `exec zsh`

### Modifying Dotfiles

Edit files in `dotfiles/` directory, then:
- Re-run the appropriate installer to update symlinks, or
- Manually copy to `$HOME`

## Tips

**Using Dorothy:**
```bash
dorothy list                    # See what's installed
dorothy doctor                  # Check for issues
dorothy install --dry-run       # Preview changes
dorothy install brew --apps     # Install Homebrew with GUI apps
dorothy update                  # Update everything
```

**Machine-specific config (not tracked in git):**
```bash
dorothy local init              # Create ~/.gitconfig.local, ~/.zshrc.local, etc.
dorothy local list              # Show which .local files exist
dorothy local edit git          # Edit ~/.gitconfig.local
dorothy local edit zsh          # Edit ~/.zshrc.local
```

**List all custom commands:**
```bash
listhelpers functions   # Show all custom functions
listhelpers aliases     # Show all aliases
```

**Update everything:**
```bash
dorothy update          # Update via Dorothy (recommended)
updatelibs              # Normal update (legacy)
updatelibs clean        # Clean reinstall (legacy)
```

**Git with 1Password:**
The `.gitconfig` uses 1Password for GPG and SSH signing. Ensure 1Password is installed and configured.

**Nerd Fonts:**
iTerm2 and VS Code are configured to use Fira Code Nerd Font for icons in prompt and tools like `eza`, `bat`, and `starship`.

## Troubleshooting

**Slow shell startup?** Run `ZPROF=true zsh` to profile. Consider disabling plugins or adding more tools to lazy loading.

**Permission errors?** Ensure scripts are executable: `chmod +x *.sh`

**Git signing issues?** Check 1Password SSH agent is running: `ps aux | grep "1Password"`

**Package manager issues?** Use `cleanpkgs` to detect and reinstall with the correct package manager.

## License

Personal configuration repository. Use and modify as needed.
