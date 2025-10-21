######################################################################################
# Git Tools
# Git-related functions and utilities
######################################################################################

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

  g clone "$repo"

  if [ $? -eq 0 ] && [ -d "$repo_name" ]; then
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
    echo "Cloning https://github.com/${org}/${repo}.git"
    g clone "https://github.com/${org}/${repo}.git"
  done
}

function showgitbranch() {
  DIR_NAME="$1"
  LIB_TYPE="$2"
  starting_path=$(pwd)
  local original_chpwd=$(declare -f chpwd)
  unset -f chpwd

  if [ ! -d "$DIR_NAME" ]; then
    echo "${RED}Directory not found: ${DIR_NAME}${NC}"
    return 1
  fi

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
    echo ""
    gotopathsafely $DIR_NAME/$dir
    if git rev-parse --is-inside-work-tree &>/dev/null; then
      echo "${BLUE}Repo: ${CYAN}${dir}${NC}"
      echo "${BOLD_MAGENTA}Branch: ${BOLD_GREEN}$(gbc)${NC}"
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
