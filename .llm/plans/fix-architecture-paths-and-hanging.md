# Fix Architecture-Specific Paths and Script Hanging Issues

## Problem Summary

### Current Issues
1. **Path Mismatch**: Intel Mac (x86_64) is configured with Apple Silicon paths (`/opt/homebrew`)
2. **Script Hanging**: `updatelibs` and other scripts hang due to:
   - Wrong Homebrew paths causing command failures
   - Git operations without timeouts
   - No error handling for failed operations
   - Long-running brew operations with no progress feedback

### Scope
- **Deployed dotfiles** (in `~/.zshrc`, etc.): Intel-only, immediate fix
- **mac-setup repository**: Architecture-aware, works on both Intel and Apple Silicon

## Architecture Detection

### Intel vs Apple Silicon Paths

**Intel Mac:**
- Homebrew: `/usr/local/bin/brew`
- Homebrew prefix: `/usr/local`
- Architecture: `x86_64`

**Apple Silicon:**
- Homebrew: `/opt/homebrew/bin/brew`
- Homebrew prefix: `/opt/homebrew`
- Architecture: `arm64`

### Detection Methods

```bash
# Method 1: Check architecture
arch=$(uname -m)
if [[ "$arch" == "arm64" ]]; then
  BREW_PREFIX="/opt/homebrew"
elif [[ "$arch" == "x86_64" ]]; then
  BREW_PREFIX="/usr/local"
fi

# Method 2: Let Homebrew tell us (most reliable)
eval "$(brew shellenv)"  # Sets HOMEBREW_PREFIX automatically

# Method 3: Check which brew exists
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  BREW_PREFIX="/opt/homebrew"
elif [[ -x "/usr/local/bin/brew" ]]; then
  BREW_PREFIX="/usr/local"
fi
```

## Implementation Plan

### Phase 1: Fix Deployed Dotfiles (Immediate - Intel Only)

Files to update on this machine:
1. `~/.zprofile` - Fix Homebrew shellenv call
2. `~/.bash_profile` - Fix Homebrew shellenv call
3. `~/.zshrc` - Fix MySQL path
4. `~/.gitconfig` - Fix GPG path

Changes:
- `/opt/homebrew` → `/usr/local`

### Phase 2: Make mac-setup Repository Architecture-Aware

Files to update in `~/projects/mac-setup/dotfiles/`:

#### 1. `.zprofile` and `.bash_profile`
**Current:**
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

**Architecture-aware:**
```bash
# Homebrew - auto-detect architecture
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x "/usr/local/bin/brew" ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
```

#### 2. `.zshrc`
**Current:**
```bash
export PATH="/opt/homebrew/opt/mysql@8.4/bin:$PATH"
```

**Architecture-aware:**
```bash
# MySQL - use Homebrew's detected prefix
if command -v brew &>/dev/null; then
  export PATH="$(brew --prefix mysql@8.4)/bin:$PATH"
fi
```

#### 3. `.gitconfig`
**Current:**
```
program = /opt/homebrew/bin/gpg
```

**Architecture-aware:**
Use dynamic path detection or rely on PATH:
```
program = gpg
```
(GPG should be in PATH from Homebrew shellenv)

### Phase 3: Fix Script Hanging Issues

#### 1. Add Git Operation Timeouts

In `development.zsh`, update `updategitdirectory` function:

**Current (line 115):**
```bash
gpra
```

**With timeout:**
```bash
# Add timeout to prevent hanging on unreachable remotes
timeout 30 git pull --rebase --autostash || {
  echo "${YELLOW}⚠️  Git pull timed out or failed for ${dir}${NC}"
  continue
}
```

#### 2. Add Error Handling

Wrap operations in error checks:
```bash
if ! timeout 30 git pull --rebase --autostash 2>&1; then
  echo "${YELLOW}⚠️  Skipping ${dir} - git pull failed${NC}"
  continue
fi
```

#### 3. Add Progress Indicators

For long operations:
```bash
echo "${BLUE}⏳ Updating Homebrew (this may take a while)...${NC}"
brew update
echo "${BLUE}⏳ Upgrading Homebrew packages...${NC}"
brew upgrade
```

#### 4. Parallel Operations (Optional Enhancement)

For updating multiple repos, consider parallel execution:
```bash
# Run git pulls in parallel with limited concurrency
for dir in "${dirs[@]}"; do
  (
    cd "$dir" && timeout 30 git pull --rebase --autostash
  ) &
done
wait  # Wait for all background jobs
```

### Phase 4: Additional Improvements

#### 1. Add `--skip-errors` flag to `updatelibs`
```bash
function updatelibs() {
  CLEAN_LIBS="$1"
  SKIP_ERRORS="${2:-false}"

  # ... existing code ...
}
```

#### 2. Add verbose/quiet modes
```bash
# Add -v for verbose, -q for quiet
while getopts "vq" opt; do
  case $opt in
    v) VERBOSE=true ;;
    q) QUIET=true ;;
  esac
done
```

#### 3. Add summary at the end
```bash
echo "${GREEN}✅ Update complete${NC}"
echo "  - Repos updated: $success_count"
echo "  - Repos skipped: $skip_count"
echo "  - Repos failed: $fail_count"
```

## Testing Strategy

### Phase 1 Testing (Deployed Dotfiles)
1. Fix paths in deployed dotfiles
2. Start new shell: `zsh`
3. Verify Homebrew works: `brew config`
4. Verify commands resolve: `which brew`, `which git`, `which mysql`
5. Test `updatelibs` with a small number of repos

### Phase 2 Testing (mac-setup Repository)
1. Update dotfiles in repository
2. Test on Intel Mac (current machine)
3. Test on Apple Silicon Mac (work laptop) or use Docker
4. Verify architecture detection works correctly
5. Run installation scripts

### Phase 3 Testing (Script Fixes)
1. Test `updatelibs` with:
   - Repos with no changes
   - Repos with changes to pull
   - Repos with unreachable remotes (should timeout)
   - Non-git directories (should skip gracefully)
2. Monitor for hanging behavior
3. Verify error messages are clear

## Rollback Plan

If issues occur:
1. **Deployed dotfiles**: Restore from `~/projects/mac-setup/dotfiles/` (revert to source)
2. **Repository changes**: Git revert specific commits
3. **Shell issues**: Start bash instead of zsh: `bash --login`

## Success Criteria

1. ✅ `brew config` shows correct prefix for Intel Mac
2. ✅ New shell starts without delays or errors
3. ✅ `updatelibs` completes without hanging
4. ✅ Git operations timeout gracefully on unreachable remotes
5. ✅ Same dotfiles work on both Intel and Apple Silicon
6. ✅ No hardcoded architecture-specific paths in repository

## Files to Modify

### Immediate (Deployed Dotfiles - Intel Specific)
- `~/.zprofile`
- `~/.bash_profile`
- `~/.zshrc`
- `~/.gitconfig`

### Repository (Architecture-Aware)
- `~/projects/mac-setup/dotfiles/.zprofile`
- `~/projects/mac-setup/dotfiles/.bash_profile`
- `~/projects/mac-setup/dotfiles/.zshrc`
- `~/projects/mac-setup/dotfiles/.gitconfig`
- `~/projects/mac-setup/custom-zsh/development.zsh` (updatelibs function)
- `~/projects/mac-setup/custom-zsh/system-tools.zsh` (if needed)

## Notes

- Keep backward compatibility during transition
- Document architecture detection in comments
- Consider adding architecture detection to `dorothy doctor` for health checks
- Update CLAUDE.md or README.md with architecture requirements
