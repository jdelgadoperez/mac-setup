# Mac Setup

Automated macOS development environment configuration and dotfiles management. Transforms a fresh Mac into a fully-configured development workstation with one command.

## Quick Start

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

**Optional GUI Apps** (when `INSTALL_APPS=true`):
- 1Password, Alfred, Arc Browser
- Discord, Slack, Spotify
- VS Code, iTerm2, and more

### Shell Environment

**Zsh with Oh My Zsh** featuring:
- Performance-optimized with lazy loading for heavy tools
- Starship prompt with Dracula theme
- 10+ plugins: autosuggestions, syntax highlighting, fzf-tab, zoxide, etc.
- Custom helper functions for development workflows

**Dotfiles** symlinked to `$HOME`:
- `.zshrc` - Main shell configuration
- `.gitconfig` - Git with GPG signing via 1Password
- `.config/starship.toml` - Prompt theme
- `.config/.ripgreprc` - Search tool config
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
├── run.sh                    # Main orchestrator script
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

**List all custom commands:**
```bash
listhelpers functions   # Show all custom functions
listhelpers aliases     # Show all aliases
```

**Update everything:**
```bash
updatelibs              # Normal update
updatelibs clean        # Clean reinstall
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
