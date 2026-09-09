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
    return 1
  fi

  # Get the author from arguments
  if [ -z "$1" ]; then
    echo "You must provide an author email or name."
    return 1
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
    return 1
  fi

  # Get the author from arguments
  if [ -z "$1" ]; then
    echo "You must provide an author email or name."
    return 1
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
        printf "  1. Worktree cleanup — stale/orphaned worktrees (frees their branches)\n"
        printf "  2. Branch cleanup  — gone remote refs + optionally merged branches\n\n"
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

  # ── Phase 1: Worktree cleanup ──
  # Run first so any branch checked out in a worktree is released before we try
  # to delete it (git refuses `branch -D` on a branch held by a worktree).
  _git_cleanup_worktrees "$force" "$interactive"

  # ── Phase 2: Branch cleanup ──
  # Use for-each-ref / --format so the branch name never includes the worktree
  # ("+") or current ("*") marker column that `git branch -vv` prefixes.
  local gone_branches=()
  local merged_branches=()

  while IFS='|' read -r branch track; do
    if [[ "$track" == "[gone]" && -n "$branch" && ! "$branch" =~ $protected_pattern ]]; then
      gone_branches+=("$branch")
    fi
  done < <(git for-each-ref --format='%(refname:short)|%(upstream:track)' refs/heads/)

  if [[ "$include_merged" == true ]]; then
    while IFS= read -r branch; do
      if [[ -n "$branch" && ! "$branch" =~ $protected_pattern ]]; then
        local already_listed=false
        for gone in "${gone_branches[@]}"; do
          if [[ "$gone" == "$branch" ]]; then
            already_listed=true
            break
          fi
        done
        if [[ "$already_listed" == false ]]; then
          merged_branches+=("$branch")
        fi
      fi
    done < <(git branch --merged "$default_branch" --format='%(refname:short)')
  fi

  local total=$(( ${#gone_branches[@]} + ${#merged_branches[@]} ))

  if [[ $total -eq 0 ]]; then
    printf "${GREEN}No defunct branches found.${NC}\n"
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

# Scan a single repo for cleanup candidates without touching the network.
# Prints "<gone_branch_count>|<stale_worktree_count>" for the repo at $1.
function _gitclean_scan_repo() {
  local repo_path="$1"
  local gone_count=0
  local stale_count=0

  # Branches whose upstream was deleted on the remote. This reads refs as they
  # stand on disk — without a fetch the marker reflects the last prune, which is
  # why the scan reports an estimate and gitclean re-checks per repo.
  local track
  while IFS= read -r track; do
    if [[ "$track" == "[gone]" ]]; then
      ((gone_count++))
    fi
  done < <(git -C "$repo_path" for-each-ref --format='%(upstream:track)' refs/heads/ 2>/dev/null)

  # Worktree admin refs pointing at directories that no longer exist.
  if [[ -n "$(git -C "$repo_path" worktree prune --dry-run 2>/dev/null)" ]]; then
    ((stale_count++))
  fi

  # Registered worktrees whose directory is missing or whose branch is gone.
  # Mirrors the labelling in _git_cleanup_worktrees so the counts agree.
  local main_worktree
  main_worktree=$(git -C "$repo_path" worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //')

  local current_path="" current_branch="" line
  while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
      current_path="${match[1]}"
    elif [[ "$line" =~ ^branch\ refs/heads/(.+)$ ]]; then
      current_branch="${match[1]}"
    elif [[ "$line" == "detached" ]]; then
      current_branch="(detached HEAD)"
    elif [[ -z "$line" && -n "$current_path" ]]; then
      if [[ "$current_path" != "$main_worktree" ]]; then
        if [[ ! -d "$current_path" ]]; then
          ((stale_count++))
        elif ! git -C "$repo_path" show-ref --verify --quiet "refs/heads/${current_branch}" 2>/dev/null; then
          ((stale_count++))
        fi
      fi
      current_path=""
      current_branch=""
    fi
  done < <(git -C "$repo_path" worktree list --porcelain 2>/dev/null; echo "")

  printf '%s|%s\n' "$gone_count" "$stale_count"
}

function gitcleanall() {
  local depth=2
  local scan_dirs=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--depth)
        depth="$2"
        shift 2
        ;;
      --depth=*)
        depth="${1#--depth=}"
        shift
        ;;
      --help|-h)
        printf "${BOLD_CYAN}gitcleanall${NC} — Run ${CYAN}gitclean -i${NC} across every repo that needs it\n\n"
        printf "${BOLD_WHITE}Usage:${NC}\n"
        printf "  gitcleanall                  Scan current directory, then clean matches\n"
        printf "  gitcleanall ${YELLOW}<dir>...${NC}        Scan the given directories instead\n"
        printf "  gitcleanall ${YELLOW}-d 3${NC}            Scan this many directories deep (default 2)\n\n"
        printf "${BOLD_WHITE}Detection${NC} ${WHITE}(no network — reads refs as they stand on disk):${NC}\n"
        printf "  • Branches whose upstream is ${RED}[gone]${NC}\n"
        printf "  • Worktrees with a missing directory or a deleted branch\n\n"
        printf "${BOLD_WHITE}Note:${NC} counts are an estimate. ${CYAN}gitclean${NC} fetches and re-checks in each\n"
        printf "repo, and protects main/master/develop/release plus the checked-out branch.\n"
        return 0
        ;;
      -*)
        printf "${RED}Unknown option: ${1}${NC}\n"
        printf "Run ${YELLOW}gitcleanall --help${NC} for usage.\n"
        return 1
        ;;
      *)
        scan_dirs+=("$1")
        shift
        ;;
    esac
  done

  if [[ ${#scan_dirs[@]} -eq 0 ]]; then
    scan_dirs=(".")
  fi

  if ! [[ "$depth" =~ ^[0-9]+$ ]]; then
    printf "${RED}Depth must be a non-negative integer, got: ${depth}${NC}\n"
    return 1
  fi

  # Resolve to absolute paths up front so the later cd loop can never be thrown
  # off by a relative path.
  local resolved_dirs=()
  local dir
  for dir in "${scan_dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      printf "${YELLOW}Skipping missing directory: ${dir}${NC}\n"
      continue
    fi
    resolved_dirs+=("${dir:A}")
  done

  if [[ ${#resolved_dirs[@]} -eq 0 ]]; then
    printf "${RED}No valid directories to scan.${NC}\n"
    return 1
  fi

  printf "${BLUE}Scanning for repos with defunct branches or worktrees...${NC}\n"

  # Find every .git (dir for a normal repo, file for a worktree checkout).
  # -depth+1 because the .git entry sits one level below the repo itself.
  local git_markers=()
  if [[ "$depth" -eq 0 ]]; then
    git_markers=("${(@f)$(find "${resolved_dirs[@]}" -name .git -print 2>/dev/null)}")
  else
    git_markers=("${(@f)$(find "${resolved_dirs[@]}" -maxdepth $((depth + 1)) -name .git -print 2>/dev/null)}")
  fi

  local repos_to_clean=()
  local repo_summaries=()
  local scanned=0
  local marker repo gone stale counts

  for marker in "${git_markers[@]}"; do
    [[ -z "$marker" ]] && continue
    repo="${marker:h}"

    git -C "$repo" rev-parse --is-inside-work-tree &>/dev/null || continue
    ((scanned++))

    counts=$(_gitclean_scan_repo "$repo")
    gone="${counts%%|*}"
    stale="${counts##*|}"

    if [[ "$gone" -gt 0 || "$stale" -gt 0 ]]; then
      repos_to_clean+=("$repo")
      repo_summaries+=("${gone}|${stale}")
    fi
  done

  printf "${WHITE}Scanned ${BOLD_WHITE}${scanned}${NC}${WHITE} repo(s).${NC}\n"

  if [[ ${#repos_to_clean[@]} -eq 0 ]]; then
    printf "${GREEN}Nothing to clean.${NC}\n"
    return 0
  fi

  printf "\n${BOLD_WHITE}Repos needing cleanup:${NC}\n"
  local idx
  for idx in {1..${#repos_to_clean[@]}}; do
    gone="${repo_summaries[$idx]%%|*}"
    stale="${repo_summaries[$idx]##*|}"

    printf "  ${CYAN}%-50s${NC}" "${repos_to_clean[$idx]/#$HOME/~}"
    if [[ "$gone" -gt 0 ]]; then
      printf " ${RED}%s gone${NC}" "$gone"
    fi
    if [[ "$stale" -gt 0 ]]; then
      printf " ${YELLOW}%s worktree${NC}" "$stale"
    fi
    printf "\n"
  done

  printf "\n${WHITE}Total: ${BOLD_WHITE}${#repos_to_clean[@]}${NC}${WHITE} repo(s). Running ${CYAN}gitclean -i${WHITE} in each.${NC}\n"
  printf "${WHITE}Press ${YELLOW}Esc${WHITE} at a prompt to skip that repo.${NC}\n"

  # Preserve the caller's directory and any chpwd hook across the loop, and
  # restore both even if the user interrupts partway through.
  local starting_path="$PWD"
  local original_chpwd=$(declare -f chpwd)
  unset -f chpwd 2>/dev/null

  function _gitcleanall_restore() {
    gotopathsafely "$starting_path"
    if [[ -n "$original_chpwd" ]]; then
      eval "$original_chpwd"
    fi
    unfunction _gitcleanall_restore 2>/dev/null
  }
  trap '_gitcleanall_restore; trap - INT; return 130' INT

  for idx in {1..${#repos_to_clean[@]}}; do
    repo="${repos_to_clean[$idx]}"
    printf "\n${BOLD_BLUE}━━ [${idx}/${#repos_to_clean[@]}] ${repo/#$HOME/~} ━━${NC}\n"

    if ! gotopathsafely "$repo"; then
      printf "${RED}Could not enter ${repo}. Skipping.${NC}\n"
      continue
    fi

    # Keep going even if one repo errors out — a bad repo shouldn't end the run.
    gitclean -i || printf "${YELLOW}gitclean exited non-zero in ${repo/#$HOME/~}. Continuing.${NC}\n"
  done

  trap - INT
  _gitcleanall_restore

  printf "\n${BOLD_GREEN}All done.${NC} Processed ${BOLD_WHITE}${#repos_to_clean[@]}${NC} repo(s).\n"
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
