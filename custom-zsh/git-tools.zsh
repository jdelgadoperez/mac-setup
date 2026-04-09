######################################################################################
# Git Tools
# Git-related functions and utilities
######################################################################################

function gitclonesafely() {
  REPO_URL="$1"
  DEST_PATH="$2"

  if [ -d "$DEST_PATH" ]; then
    printf "${YELLOW}Directory already exists: ${DEST_PATH}${NC}\n"
    printf "${BLUE}Checking if it's a valid git repository...${NC}\n"

    if [ -d "$DEST_PATH/.git" ]; then
      printf "${GREEN}Valid git repository found. Pulling latest changes...${NC}\n"
      cd "$DEST_PATH"
      git pull origin HEAD 2>/dev/null || git pull 2>/dev/null || printf "${YELLOW}Could not pull updates${NC}\n"
      cd - > /dev/null
    else
      printf "${RED}Directory exists but is not a git repository. Removing and cloning fresh...${NC}\n"
      rm -rf "$DEST_PATH"
      git clone "$REPO_URL" "$DEST_PATH"
    fi
  else
    printf "${BLUE}Cloning ${GREEN}${REPO_URL}${BLUE} to ${GREEN}${DEST_PATH}${NC}\n"
    git clone "$REPO_URL" "$DEST_PATH"
  fi
}

function gccd() {
  repo=$1

  if [ -z "$repo" ]; then
    echo "Usage: gccd <git-repo-url>"
    return 1
  fi

  # Extract repository name from various Git URL formats
  # Handle SSH format: git@github.com:owner/repo.git
  # Handle HTTPS format: https://github.com/owner/repo.git
  # Remove .git suffix if present
  repo_name=$(basename "$repo" .git)

  gitclonesafely "$repo" "$repo_name"

  if [ -d "$repo_name" ]; then
    cd "$repo_name"
  else
    echo "Failed to clone repository or directory '$repo_name' not found"
    return 1
  fi
}

function clone_org_repos() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: clone_org_repos <org-name> <repo1> [repo2 ...]"
    return 1
  fi

  local org="$1"
  shift

  for repo in "$@"; do
    local repo_url="git@github.com:${org}/${repo}.git"
    gitclonesafely "$repo_url" "$repo"
    echo ""
  done
}

function showgitbranch() {
  local input_dir="${1:-.}"
  LIB_TYPE="$2"
  starting_path=$(pwd)
  local original_chpwd=$(declare -f chpwd)
  unset -f chpwd

  if [ ! -d "$input_dir" ]; then
    echo "${RED}Directory not found: ${input_dir}${NC}"
    return 1
  fi

  DIR_NAME="$(cd "$input_dir" 2>/dev/null && pwd)"

  echo "${BLUE}Checking git branches in ${CYAN}${DIR_NAME}${NC}"
  cd "$DIR_NAME" 2>/dev/null || return 1

  echo "${BLUE}Go to ${CYAN}${DIR_NAME}${NC}"
  gotopathsafely $DIR_NAME
  local dirs=()
  for dir in */; do
    if [ -d "$dir" ]; then
      dirs+=("$dir")
    fi
  done

  for dir in "${dirs[@]}"; do
    gotopathsafely $DIR_NAME/$dir
    if git rev-parse --is-inside-work-tree &>/dev/null; then
      local repo_name="${dir%/}"
      local branch_name=$(gbc)
      if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        echo "${BLUE}${repo_name} ${WHITE}|${MAGENTA} ${branch_name} ${BOLD_YELLOW}*${NC}"
      else
        echo "${BLUE}${repo_name} ${WHITE}|${MAGENTA} ${branch_name} ${BOLD_GREEN}✓${NC}"
      fi
    fi
  done

  if [ "$starting_path" != "$(pwd)" ]; then
    cd $starting_path
  fi
  eval "$original_chpwd"
}

function getcommitcount() {
  # Check if inside a Git repository
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Not inside a Git repository."
    exit 1
  fi

  # Get the author from arguments
  if [ -z "$1" ]; then
    echo "You must provide an author email or name."
    exit 1
  fi
  AUTHOR="$1"

  # Count commits by the specified author
  commit_count=$(git log --author="$AUTHOR" --pretty=oneline | wc -l)

  echo "Total commits by '$AUTHOR': $commit_count"
}

function getcommits() {
  # Check if inside a Git repository
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Not inside a Git repository."
    exit 1
  fi

  # Get the author from arguments
  if [ -z "$1" ]; then
    echo "You must provide an author email or name."
    exit 1
  fi
  AUTHOR="$1"

  # Count commits by the specified author
  git log --author="$AUTHOR" --pretty=oneline

  echo "Got all commits by '$AUTHOR'"
}

function gitclean() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    printf "${RED}Not inside a git repository.${NC}\n"
    return 1
  fi

  local force=false
  local interactive=false
  local include_merged=false

  for arg in "$@"; do
    case "$arg" in
      --force|-f) force=true ;;
      --interactive|-i) interactive=true ;;
      --merged|-m) include_merged=true ;;
      --help|-h)
        printf "${BOLD_CYAN}git-cleanup${NC} — Remove defunct local branches\n\n"
        printf "${BOLD_WHITE}Usage:${NC}\n"
        printf "  git-cleanup                  Dry run — show branches that would be deleted\n"
        printf "  git-cleanup ${YELLOW}--force${NC}         Actually delete all found branches\n"
        printf "  git-cleanup ${YELLOW}--interactive${NC}   Pick which branches to delete (fzf multi-select)\n"
        printf "  git-cleanup ${YELLOW}--merged${NC}        Also include branches merged into the default branch\n"
        printf "  git-cleanup ${YELLOW}-i -m${NC}           Interactively pick from gone + merged branches\n\n"
        printf "${BOLD_WHITE}Phases:${NC}\n"
        printf "  1. Branch cleanup  — gone remote refs + optionally merged branches\n"
        printf "  2. Worktree cleanup — stale/orphaned worktrees\n\n"
        printf "${BOLD_WHITE}Protected branches:${NC} main, master, develop, release, and current branch\n"
        return 0
        ;;
      *)
        printf "${RED}Unknown option: ${arg}${NC}\n"
        printf "Run ${YELLOW}git-cleanup --help${NC} for usage.\n"
        return 1
        ;;
    esac
  done

  local current_branch
  current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
  local protected_pattern="^(main|master|develop|release|${current_branch})$"

  printf "${BLUE}Fetching and pruning remote tracking refs...${NC}\n"
  git fetch --prune --quiet

  local default_branch
  default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  if [[ -z "$default_branch" ]]; then
    default_branch="main"
  fi

  local gone_branches=()
  local merged_branches=()

  while IFS= read -r branch; do
    local trimmed="${branch## }"
    if [[ -n "$trimmed" && ! "$trimmed" =~ $protected_pattern ]]; then
      gone_branches+=("$trimmed")
    fi
  done < <(git branch -vv | grep ': gone\]' | awk '{print $1}')

  if [[ "$include_merged" == true ]]; then
    while IFS= read -r branch; do
      local trimmed="${branch## }"
      trimmed="${trimmed%% }"
      if [[ -n "$trimmed" && ! "$trimmed" =~ $protected_pattern ]]; then
        local already_listed=false
        for gone in "${gone_branches[@]}"; do
          if [[ "$gone" == "$trimmed" ]]; then
            already_listed=true
            break
          fi
        done
        if [[ "$already_listed" == false ]]; then
          merged_branches+=("$trimmed")
        fi
      fi
    done < <(git branch --merged "$default_branch" | grep -v '^\*')
  fi

  local total=$(( ${#gone_branches[@]} + ${#merged_branches[@]} ))

  if [[ $total -eq 0 ]]; then
    printf "${GREEN}No defunct branches found.${NC}\n"
    _git_cleanup_worktrees "$force" "$interactive"
    return 0
  fi

  if [[ ${#gone_branches[@]} -gt 0 ]]; then
    printf "\n${BOLD_YELLOW}Remote gone${NC} ${WHITE}(tracking branch deleted on remote):${NC}\n"
    for branch in "${gone_branches[@]}"; do
      printf "  ${RED}%-40s${NC}\n" "$branch"
    done
  fi

  if [[ ${#merged_branches[@]} -gt 0 ]]; then
    printf "\n${BOLD_CYAN}Merged${NC} ${WHITE}(already merged into ${default_branch}):${NC}\n"
    for branch in "${merged_branches[@]}"; do
      printf "  ${YELLOW}%-40s${NC}\n" "$branch"
    done
  fi

  printf "\n${WHITE}Total: ${BOLD_WHITE}${total}${NC} branch(es) to remove\n"

  # Build the list of branches to delete based on mode
  local branches_to_delete=()

  if [[ "$interactive" == true ]]; then
    # Build fzf input: "label\tbranch" with tab delimiter
    local fzf_input=""
    for branch in "${gone_branches[@]}"; do
      fzf_input+="gone\t${branch}\n"
    done
    for branch in "${merged_branches[@]}"; do
      fzf_input+="merged\t${branch}\n"
    done

    if command -v fzf &>/dev/null; then
      printf "\n${BOLD_CYAN}Select branches to delete (Tab to toggle, Enter to confirm, Esc to cancel):${NC}\n"
      local selected
      selected=$(printf '%b' "$fzf_input" | fzf --multi \
        --delimiter=$'\t' \
        --with-nth=1,2 \
        --header="Tab: toggle selection | Shift-Tab: deselect | Enter: confirm | Esc: cancel" \
        --prompt="Delete branches> " \
        --preview="git log --oneline -10 {2}" \
        --preview-window=right:50%:wrap \
        --color="fg:#f8f8f2,bg:#282a36,hl:#ff79c6,fg+:#f8f8f2,bg+:#44475a,hl+:#ff79c6,info:#8be9fd,prompt:#50fa7b,pointer:#ff79c6,marker:#50fa7b,spinner:#50fa7b,header:#6272a4")

      if [[ -z "$selected" ]]; then
        printf "\n${YELLOW}No branches selected. Nothing deleted.${NC}\n"
      else
        while IFS= read -r line; do
          local branch_name="${line#*	}"
          branches_to_delete+=("$branch_name")
        done <<< "$selected"
      fi
    else
      # Fallback: y/n prompt per branch when fzf is not available
      printf "\n${BOLD_CYAN}Select branches to delete:${NC}\n"
      for branch in "${gone_branches[@]}"; do
        printf "  ${RED}[gone]${NC}   ${WHITE}${branch}${NC} — delete? [y/N] "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
          branches_to_delete+=("$branch")
        fi
      done
      for branch in "${merged_branches[@]}"; do
        printf "  ${YELLOW}[merged]${NC} ${WHITE}${branch}${NC} — delete? [y/N] "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
          branches_to_delete+=("$branch")
        fi
      done

      if [[ ${#branches_to_delete[@]} -eq 0 ]]; then
        printf "\n${YELLOW}No branches selected. Nothing deleted.${NC}\n"
      fi
    fi
  elif [[ "$force" == true ]]; then
    branches_to_delete=("${gone_branches[@]}" "${merged_branches[@]}")
  else
    printf "\n${BOLD_YELLOW}Dry run — no branches deleted.${NC}\n"
    printf "Run ${CYAN}git-cleanup --force${NC} to delete all, or ${CYAN}git-cleanup --interactive${NC} to pick.\n"
    _git_cleanup_worktrees "$force" "$interactive"
    return 0
  fi

  if [[ ${#branches_to_delete[@]} -gt 0 ]]; then
    printf "\n${BOLD_RED}Deleting ${#branches_to_delete[@]} branch(es)...${NC}\n"
    local deleted=0
    local failed=0

    for branch in "${branches_to_delete[@]}"; do
      if git branch -D "$branch" &>/dev/null; then
        printf "  ${GREEN}Deleted${NC} ${WHITE}${branch}${NC}\n"
        ((deleted++))
      else
        printf "  ${RED}Failed${NC} ${WHITE}${branch}${NC}\n"
        ((failed++))
      fi
    done

    printf "\n${GREEN}Done.${NC} Deleted: ${BOLD_GREEN}${deleted}${NC}"
    if [[ $failed -gt 0 ]]; then
      printf ", Failed: ${BOLD_RED}${failed}${NC}"
    fi
    printf "\n"
  fi

  # ── Phase 2: Worktree cleanup ──
  _git_cleanup_worktrees "$force" "$interactive"
}

function _git_cleanup_worktrees() {
  local force="$1"
  local interactive="$2"

  printf "\n${BOLD_BLUE}── Worktree cleanup ──${NC}\n"

  # Prune stale worktree references (directory already deleted)
  local prune_output
  prune_output=$(git worktree prune --dry-run 2>&1)
  if [[ -n "$prune_output" ]]; then
    printf "${BLUE}Pruning stale worktree admin refs...${NC}\n"
    git worktree prune
    printf "${GREEN}Pruned stale references.${NC}\n"
  fi

  # Get the main worktree path (first line is always the main checkout)
  local main_worktree
  main_worktree=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')

  # Collect non-main worktrees
  local worktree_paths=()
  local worktree_branches=()
  local worktree_labels=()

  local current_path=""
  local current_branch=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
      current_path="${match[1]}"
    elif [[ "$line" =~ ^branch\ refs/heads/(.+)$ ]]; then
      current_branch="${match[1]}"
    elif [[ "$line" == "detached" ]]; then
      current_branch="(detached HEAD)"
    elif [[ -z "$line" && -n "$current_path" ]]; then
      # End of a worktree block — skip the main worktree
      if [[ "$current_path" != "$main_worktree" ]]; then
        worktree_paths+=("$current_path")
        worktree_branches+=("$current_branch")

        # Determine label: is the directory missing or is the branch gone?
        if [[ ! -d "$current_path" ]]; then
          worktree_labels+=("missing dir")
        elif ! git show-ref --verify --quiet "refs/heads/${current_branch}" 2>/dev/null; then
          worktree_labels+=("branch gone")
        else
          worktree_labels+=("active")
        fi
      fi
      current_path=""
      current_branch=""
    fi
  done < <(git worktree list --porcelain; echo "")

  if [[ ${#worktree_paths[@]} -eq 0 ]]; then
    printf "${GREEN}No extra worktrees found.${NC}\n"
    return 0
  fi

  # Display worktrees
  printf "\n${BOLD_WHITE}Worktrees:${NC}\n"
  for idx in {1..${#worktree_paths[@]}}; do
    local label="${worktree_labels[$idx]}"
    local color="${GREEN}"
    if [[ "$label" == "missing dir" ]]; then
      color="${RED}"
    elif [[ "$label" == "branch gone" ]]; then
      color="${YELLOW}"
    fi
    printf "  ${color}[${label}]${NC} ${WHITE}${worktree_paths[$idx]}${NC} ${MAGENTA}(${worktree_branches[$idx]})${NC}\n"
  done

  # Collect worktrees to remove
  local worktrees_to_remove=()

  if [[ "$interactive" == true ]]; then
    # Build fzf input
    local fzf_input=""
    for idx in {1..${#worktree_paths[@]}}; do
      fzf_input+="${worktree_labels[$idx]}\t${worktree_paths[$idx]}\t${worktree_branches[$idx]}\n"
    done

    if command -v fzf &>/dev/null; then
      printf "\n${BOLD_CYAN}Select worktrees to remove (Tab to toggle, Enter to confirm, Esc to skip):${NC}\n"
      local selected
      selected=$(printf '%b' "$fzf_input" | fzf --multi \
        --delimiter=$'\t' \
        --with-nth=1,2,3 \
        --header="Tab: toggle | Enter: confirm | Esc: skip" \
        --prompt="Remove worktrees> " \
        --preview="ls -la {2} 2>/dev/null || echo 'Directory does not exist'" \
        --preview-window=right:40%:wrap \
        --color="fg:#f8f8f2,bg:#282a36,hl:#ff79c6,fg+:#f8f8f2,bg+:#44475a,hl+:#ff79c6,info:#8be9fd,prompt:#50fa7b,pointer:#ff79c6,marker:#50fa7b,spinner:#50fa7b,header:#6272a4")

      if [[ -z "$selected" ]]; then
        printf "\n${YELLOW}No worktrees selected. Skipping.${NC}\n"
        return 0
      fi

      while IFS= read -r line; do
        # Extract the path (second tab-delimited field)
        local wt_path
        wt_path=$(printf '%s' "$line" | cut -d$'\t' -f2)
        worktrees_to_remove+=("$wt_path")
      done <<< "$selected"
    else
      # Fallback: y/n per worktree
      printf "\n${BOLD_CYAN}Select worktrees to remove:${NC}\n"
      for idx in {1..${#worktree_paths[@]}}; do
        printf "  ${WHITE}${worktree_paths[$idx]}${NC} (${worktree_branches[$idx]}) — remove? [y/N] "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
          worktrees_to_remove+=("${worktree_paths[$idx]}")
        fi
      done
    fi
  elif [[ "$force" == true ]]; then
    # In force mode, only auto-remove worktrees with missing dirs or gone branches
    for idx in {1..${#worktree_paths[@]}}; do
      if [[ "${worktree_labels[$idx]}" != "active" ]]; then
        worktrees_to_remove+=("${worktree_paths[$idx]}")
      fi
    done

    if [[ ${#worktrees_to_remove[@]} -eq 0 ]]; then
      printf "\n${GREEN}All worktrees are active. Nothing to remove.${NC}\n"
      return 0
    fi
  else
    # Dry run
    local stale_count=0
    for label in "${worktree_labels[@]}"; do
      if [[ "$label" != "active" ]]; then
        ((stale_count++))
      fi
    done
    if [[ $stale_count -gt 0 ]]; then
      printf "\n${BOLD_YELLOW}${stale_count} stale worktree(s) found. Use ${CYAN}--force${BOLD_YELLOW} or ${CYAN}--interactive${BOLD_YELLOW} to clean up.${NC}\n"
    else
      printf "\n${GREEN}All worktrees are active.${NC}\n"
    fi
    return 0
  fi

  if [[ ${#worktrees_to_remove[@]} -eq 0 ]]; then
    printf "\n${YELLOW}No worktrees selected. Skipping.${NC}\n"
    return 0
  fi

  printf "\n${BOLD_RED}Removing ${#worktrees_to_remove[@]} worktree(s)...${NC}\n"
  local wt_deleted=0
  local wt_failed=0

  for wt_path in "${worktrees_to_remove[@]}"; do
    if git worktree remove --force "$wt_path" 2>/dev/null; then
      printf "  ${GREEN}Removed${NC} ${WHITE}${wt_path}${NC}\n"
      ((wt_deleted++))
    else
      # Directory might already be gone, try prune as fallback
      if [[ ! -d "$wt_path" ]]; then
        git worktree prune 2>/dev/null
        printf "  ${GREEN}Pruned${NC}  ${WHITE}${wt_path}${NC}\n"
        ((wt_deleted++))
      else
        printf "  ${RED}Failed${NC}  ${WHITE}${wt_path}${NC}\n"
        ((wt_failed++))
      fi
    fi
  done

  printf "\n${GREEN}Worktrees done.${NC} Removed: ${BOLD_GREEN}${wt_deleted}${NC}"
  if [[ $wt_failed -gt 0 ]]; then
    printf ", Failed: ${BOLD_RED}${wt_failed}${NC}"
  fi
  printf "\n"
}

function getorgcommitcount() {
  AUTHOR="$1"
  ORG="$2"

  local original_chpwd=$(declare -f chpwd)
  unset -f chpwd

  total_commits=0
  total_repos=0

  local dirs=()
  for dir in */; do
    if [ -d "$dir" ]; then
      dirs+=("$dir")
    fi
  done

  for dir in "${dirs[@]}"; do
    echo "Processing $dir..."
    cd "$dir" || continue
    repo_commit_count=$(git log --author="$AUTHOR" --pretty=oneline | wc -l)
    total_commits=$((total_commits + repo_commit_count))
    if [[ $repo_commit_count -gt 0 ]]; then
      total_repos=$((total_repos + 1))
    fi
    cd ..
  done

  echo "Total commits of $total_commits by '$AUTHOR' in $total_repos repos in the '$ORG' org"
  eval "$original_chpwd"
}
