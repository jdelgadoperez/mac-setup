# Dorothy & Installation Scripts Optimization Plan

**Created**: 2025-11-14 **Status**: ✅ IMPLEMENTED (Phase 1, 2, 3 Complete) **Goal**: Improve Dorothy CLI
integration, code quality, and automation capabilities

> **See OPTIMIZATION_SUMMARY.md for detailed implementation report**

---

## Analysis Summary

After reviewing all installation scripts (`install-xcode.sh`, `install-brew.sh`, `config-git.sh`,
`install-zsh.sh`, `install-dracula.sh`), I've identified optimization opportunities across four priority
levels.

---

## Phase 1: Critical Fixes (High Priority)

### 1.1 Fix Symlink Inconsistency

**Problem**:

- `install-zsh.sh` (lines 48-63): Uses `cp` to copy dotfiles
- `config-git.sh` (line 6): Uses `cp` to copy .gitconfig
- Changes to repo dotfiles don't automatically reflect in `$HOME`
- Inconsistent with Dorothy's `sync` command approach

**Current Code**:

```bash
# install-zsh.sh
cp "$SCRIPT_DIR/dotfiles/.zshrc" "$DIR_ROOT/.zshrc"

# config-git.sh
cp "$SCRIPT_DIR/dotfiles/.gitconfig" ~/
```

**Solution**:

- Convert all `cp` commands to `ln -sf` (symlinks)
- Maintain single source of truth in repo
- Users can edit files in repo and changes propagate immediately

**Files to Modify**:

- [ ] `install-zsh.sh` - Lines 48-63
- [ ] `config-git.sh` - Line 6

**Impact**: High - Fixes fundamental dotfile management issue

---

### 1.2 Add Environment Variable Validation

**Problem**:

- `config-git.sh` uses `$GIT_PERSONAL_NAME` and `$GIT_PERSONAL_EMAIL` without validation
- Git config silently uses empty values if vars not set
- No helpful error messages for users

**Current Code**:

```bash
# config-git.sh (lines 7-8)
git config --global user.name $GIT_PERSONAL_NAME
git config --global user.email $GIT_PERSONAL_EMAIL
```

**Solution**:

```bash
# Validate required environment variables
if [ -z "$GIT_PERSONAL_NAME" ] || [ -z "$GIT_PERSONAL_EMAIL" ]; then
  logerror "Missing required environment variables"
  echo "Please set the following in your .env file:"
  echo "  GIT_PERSONAL_NAME=\"Your Name\""
  echo "  GIT_PERSONAL_EMAIL=\"your@email.com\""
  exit 1
fi

git config --global user.name "$GIT_PERSONAL_NAME"
git config --global user.email "$GIT_PERSONAL_EMAIL"
```

**Files to Modify**:

- [ ] `config-git.sh` - Add validation before lines 7-8
- [ ] Create `.env.example` file with required variables

**Impact**: High - Prevents silent failures

---

### 1.3 Make Interactive Prompts Optional

**Problem**:

- `install-xcode.sh` (line 14): Manual "press Enter" prompt
- `install-dracula.sh` (lines 36-37): Manual prompt for Dracula Pro zip
- Breaks fully automated installations
- No way to skip or timeout

**Current Code**:

```bash
# install-xcode.sh
read -r

# install-dracula.sh
read -r
```

**Solution**:

```bash
# Add INTERACTIVE mode flag
if [ "${INTERACTIVE:-false}" = "true" ]; then
  read -r
else
  # Auto-detect or skip
fi
```

**Files to Modify**:

- [ ] `install-xcode.sh` - Make prompt conditional
- [ ] `install-dracula.sh` - Make Dracula Pro optional
- [ ] Add `INTERACTIVE` environment variable support

**Impact**: High - Enables CI/CD and automated setups

---

## Phase 2: Dorothy Integration (Medium Priority)

### 2.1 Add Dry-Run Support to All Scripts

**Problem**:

- Dorothy has `--dry-run` flag but scripts execute commands regardless
- No preview capability before making changes

**Solution**:

- Add `DRY_RUN` environment variable check to all scripts
- Wrap destructive operations with dry-run echo

```bash
if [ "${DRY_RUN:-false}" = "true" ]; then
  echo "[DRY-RUN] Would execute: brew install ..."
else
  brew install ...
fi
```

**Files to Modify**:

- [ ] `install-xcode.sh`
- [ ] `install-brew.sh`
- [ ] `config-git.sh`
- [ ] `install-zsh.sh`
- [ ] `install-dracula.sh`

**Impact**: Medium - Improves safety and user confidence

---

### 2.2 Standardize Logging

**Problem**:

- Inconsistent logging methods across scripts
- Some use `echo -e "${GREEN}..."`, others use `loginstall`
- New functions (`loginfo`, `logsuccess`, `logerror`) not used consistently

**Solution**:

- Replace all `printf` logging with standard functions
- Use `loginfo` for informational messages
- Use `logsuccess` for successful operations
- Use `logerror` for errors
- Use `loginstall` for major installation sections

**Files to Modify**:

- [ ] `install-xcode.sh` - Replace printf statements
- [ ] `install-brew.sh` - Replace printf statements
- [ ] `install-zsh.sh` - Replace printf statements
- [ ] `install-dracula.sh` - Replace printf statements

**Impact**: Medium - Improves consistency and readability

---

### 2.3 Add Dependency Checking

**Problem**:

- No enforcement of component dependencies
- zsh installation assumes brew is installed
- No helpful error if dependencies missing

**Solution**:

- Add dependency checks at start of each script
- Provide clear error messages with remediation steps

```bash
# Example for install-zsh.sh
if ! command -v brew &> /dev/null; then
  logerror "Homebrew is required but not installed"
  echo "Please run: dorothy install brew"
  exit 1
fi
```

**Files to Modify**:

- [ ] `install-zsh.sh` - Require brew
- [ ] `install-brew.sh` - Require xcode (optional, can auto-trigger)

**Impact**: Medium - Better error messages, clearer requirements

---

## Phase 3: Code Quality (Medium Priority)

### 3.1 Add Error Handling

**Problem**:

- Scripts don't check command exit codes
- Partial failures go unnoticed
- No rollback mechanism

**Solution**:

- Add `set -e` to fail on first error
- Add `set -o pipefail` for pipeline failures
- Check critical operations explicitly

```bash
#!/bin/bash
set -e
set -o pipefail

# For operations that can fail gracefully
if ! git clone ...; then
  logwarn "Clone failed, skipping..."
fi
```

**Files to Modify**:

- [ ] All installation scripts - Add at top
- [ ] `shared.sh` - Add `logwarn` function

**Impact**: Medium - Prevents partial/broken installations

---

### 3.2 Extract Package Lists to Data Files

**Problem**:

- `install-brew.sh` has ~80 lines of hard-coded packages
- Difficult to maintain, customize, or categorize
- No way to install subsets

**Solution**:

- Create `brew-packages.json` with categorized packages
- Load and process in script
- Enable category-based installation

```json
{
  "languages": ["node", "python", "go"],
  "terminal": ["bat", "eza", "fzf"],
  "infrastructure": ["docker", "kubectl"]
}
```

**Files to Modify**:

- [ ] Create `data/brew-packages.json`
- [ ] Refactor `install-brew.sh` to read from JSON
- [ ] Update Dorothy to support package categories

**Impact**: Medium - Better maintainability, flexibility

---

### 3.3 Refactor Repetitive Code

**Problem**:

- `install-zsh.sh` has 11 individual `cp` commands (lines 53-63)
- Hard to maintain, error-prone

**Current Code**:

```bash
cp "$SCRIPT_DIR/custom-zsh/aliases.zsh" "$ZSH_CUSTOM/aliases.zsh"
cp "$SCRIPT_DIR/custom-zsh/development.zsh" "$ZSH_CUSTOM/development.zsh"
# ... 9 more lines
```

**Solution**:

```bash
ZSH_FILES=(
  "aliases.zsh"
  "development.zsh"
  "fzf-preview.sh"
  "git-tools.zsh"
  # ... etc
)

for file in "${ZSH_FILES[@]}"; do
  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would link: $file"
  else
    ln -sf "$SCRIPT_DIR/custom-zsh/$file" "$ZSH_CUSTOM/$file"
    loginfo "Linked: $file"
  fi
done
```

**Files to Modify**:

- [ ] `install-zsh.sh` - Refactor lines 48-63 to loop

**Impact**: Low-Medium - Cleaner code, easier maintenance

---

## Phase 4: Performance (Low Priority)

### 4.1 Parallelize Git Clones

**Problem**:

- `install-zsh.sh` clones 7 plugins sequentially
- Each clone waits for previous to complete
- Slow on slower connections

**Current Code**:

```bash
gitclonesafely "$REPO/plugin1" "$ZSH_CUSTOM/plugins/plugin1"
gitclonesafely "$REPO/plugin2" "$ZSH_CUSTOM/plugins/plugin2"
# ... 5 more
```

**Solution**:

```bash
PLUGINS=(
  "zsh-autosuggestions:$REPO_ZSH_USERS/zsh-autosuggestions.git"
  "zsh-completions:$REPO_ZSH_USERS/zsh-completions.git"
  # ... etc
)

for plugin in "${PLUGINS[@]}"; do
  IFS=':' read -r name url <<< "$plugin"
  gitclonesafely "$url" "$ZSH_CUSTOM/plugins/$name" &
done

wait  # Wait for all background jobs
```

**Files to Modify**:

- [ ] `install-zsh.sh` - Parallelize plugin clones
- [ ] `install-dracula.sh` - Parallelize theme clones

**Impact**: Low - Faster installation (minor improvement)

---

### 4.2 Optimize Homebrew Operations

**Problem**:

- `install-brew.sh` runs `brew update` and `brew upgrade` every time
- Can be slow, especially if recently updated

**Current Code**:

```bash
# Make sure we're using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade
```

**Solution**:

```bash
# Only update if last update was > 24 hours ago
BREW_LAST_UPDATE=$(stat -f %m "$(brew --prefix)/var/homebrew/locks/update" 2>/dev/null || echo 0)
NOW=$(date +%s)
if [ $((NOW - BREW_LAST_UPDATE)) -gt 86400 ]; then
  loginfo "Updating Homebrew (last update > 24h ago)"
  brew update
else
  loginfo "Skipping Homebrew update (recently updated)"
fi

# Make upgrade optional
if [ "${BREW_UPGRADE:-true}" = "true" ]; then
  brew upgrade
fi
```

**Files to Modify**:

- [ ] `install-brew.sh` - Add smart update logic

**Impact**: Low - Faster repeated installations

---

## Additional Improvements

### Create .env.example

Create a template for required environment variables:

```bash
# .env.example

# Git Configuration
GIT_PERSONAL_NAME="Your Name"
GIT_PERSONAL_EMAIL="your@email.com"

# Optional: Homebrew
HOMEBREW_TOKEN="ghp_your_github_token"

# Optional: npm
GIT_NPM_TOKEN="npm_your_npm_token"
```

**Files to Create**:

- [ ] `.env.example`
- [ ] Update README with .env setup instructions

---

### Improve Dorothy Component Detection

**Current Issue**:

- Dorothy's `is_installed()` function has basic checks
- May miss installations in non-standard locations

**Solution**:

- Enhance detection logic
- Add more comprehensive checks

```bash
is_installed() {
  local component=$1
  case $component in
    brew)
      command -v brew &> /dev/null && [ -d "$(brew --prefix)" ]
      ;;
    zsh)
      [ -d "$HOME/.oh-my-zsh" ] && \
      [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]
      ;;
    # ... etc
  esac
}
```

**Files to Modify**:

- [ ] `dorothy` - Enhance `is_installed()` function

---

## Implementation Order

### Recommended Sequence:

1. **Create .env.example** (5 min)
2. **Fix symlink inconsistency** (15 min) - Phase 1.1
3. **Add environment variable validation** (10 min) - Phase 1.2
4. **Standardize logging** (20 min) - Phase 2.2
5. **Make prompts optional** (15 min) - Phase 1.3
6. **Add dry-run support** (30 min) - Phase 2.1
7. **Add error handling** (20 min) - Phase 3.1
8. **Refactor repetitive code** (15 min) - Phase 3.3
9. **Add dependency checking** (15 min) - Phase 2.3
10. **Extract package lists** (45 min) - Phase 3.2 (optional)
11. **Performance optimizations** (30 min) - Phase 4 (optional)

**Total Estimated Time**: ~2-3 hours for critical + medium priority items

---

## Testing Strategy

After each phase:

1. Test with `dorothy install --dry-run`
2. Test individual script execution
3. Test full installation on clean system (if possible)
4. Verify Dorothy commands work correctly

---

## Success Criteria

- [ ] All scripts use symlinks instead of copy
- [ ] All scripts support dry-run mode
- [ ] All scripts use consistent logging
- [ ] Environment variables validated before use
- [ ] No manual prompts in non-interactive mode
- [ ] Proper error handling with meaningful messages
- [ ] Dorothy accurately detects component status
- [ ] Documentation updated to reflect changes

---

## Notes

- Maintain backward compatibility where possible
- Keep legacy `run.sh` working
- Document breaking changes in README
- Consider creating migration guide for existing users
