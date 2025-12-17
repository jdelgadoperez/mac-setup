######################################################################################
# System Tools
# System administration, utilities, and helper functions
######################################################################################

# Utility function to format bytes into human-readable format
function format_bytes() {
  local bytes=$1
  if ((bytes >= 1073741824)); then
    printf "%.2f GB" $((bytes / 1073741824.0))
  elif ((bytes >= 1048576)); then
    printf "%.2f MB" $((bytes / 1048576.0))
  elif ((bytes >= 1024)); then
    printf "%.2f KB" $((bytes / 1024.0))
  else
    printf "%d bytes" $bytes
  fi
}

function delete_writable_recursive() {
  local target_dir="$1"
  echo -e "${GREEN}Cleaning: $target_dir${NC}"
  find "$target_dir" -mindepth 1 -exec bash -c '
    for path; do
      if [ -w "$path" ]; then
        echo "Deleting: $path"
        rm -rf "$path"
      else
        echo "Skipped (not permitted): $path"
      fi
    done
  ' bash {} +
}

function cleandocker() {
  echo -e "${GREEN}Pruning docker...${NC}"
  docker image prune -f
  docker container prune -f
  docker volume prune -f
}

function cleansys() {
  echo -e "${GREEN}Starting system cleanup...${NC}"
  delete_writable_recursive ~/Library/Caches
  delete_writable_recursive ~/Library/Logs
  delete_writable_recursive "~/Library/Saved Application State"
  delete_writable_recursive ~/Library/Developer/Xcode/DerivedData
  delete_writable_recursive ~/.Trash
  # echo -e "${GREEN}Emptying volume trash...${NC}"
  # sudo rm -rf /Volumes/*/.Trashes
  cleandocker
  echo -e "${GREEN}System cleaned${NC}"
}

function createdirsafely() {
  DIR_NAME=$@
  if [ ! -d "$DIR_NAME" ]; then
    mkdir -p "$DIR_NAME"
    echo "Directory created: $GREEN $DIR_NAME $NC"
  fi
}

function gotopathsafely() {
  specific_path="$1"
  current_path=$(pwd)
  if [ "$current_path" != "$specific_path" ]; then
    cd "$specific_path"
  fi
}

function getmactype() {
  MY_MAC_CHIP=$(sysctl -n machdep.cpu.brand_string)
  MY_MAC_TYPE=""
  if [[ "$MY_MAC_CHIP" == *"Intel"* ]]; then
    MY_MAC_TYPE="Intel"
  elif [[ "$MY_MAC_CHIP" == *"Apple"* ]]; then
    MY_MAC_TYPE="Apple Silicon"
  else
    MY_MAC_TYPE="Unknown processor: $MY_MAC_CHIP"
  fi
  echo $MY_MAC_CHIP
  echo $MY_MAC_TYPE
}

function mysqlrm() {
  OLD_VERSION=$1
  # Remove current mysql
  brew services stop $OLD_VERSION
  sleep 10
  sudo killall mysqld
  brew unlink $OLD_VERSION
  brew unpin $OLD_VERSION
  brew uninstall $OLD_VERSION
  brew cleanup
  brew doctor

  # Remove remaining config
  sudo rm -f /opt/homebrew/etc/my.cnf
  sudo rm -rf /opt/homebrew/etc/my.cnf.d
  sudo rm -rf /opt/homebrew/var/mysql
  sudo rm -rf /opt/homebrew/var/log/mysql*
  sudo rm -rf /opt/homebrew/var/mysql*
  sudo rm -rf /opt/homebrew/Cellar/mysql
  sudo rm -rf /opt/homebrew/Cellar/mysql-client
  sudo rm -rf /opt/homebrew/opt/mysql
  sudo rm -f ~/Library/LaunchAgents/homebrew.mxcl.mysql.plist
  sudo rm -f /Library/Launch{Agents,Daemons}/*mysql*
  sudo rm -f /private/etc/mysql*

  # remove any simlinks that point to old mysql
  cd /opt/homebrew/opt
  ls -latr mysql*
  cd -
}

function mysqladd() {
  NEW_VERSION=$1
  # Extract version number from package name (e.g., "mysql@8.4" -> "8.4")
  VERSION_NUMBER=${NEW_VERSION#mysql@}
  # Update and install new
  brew update
  install_mysql $VERSION_NUMBER
  brew link --force $NEW_VERSION
  brew pin $NEW_VERSION
  brew services list
}

function mysqlreplace() {
  OLD_VERSION=$1
  NEW_VERSION=$2
  # Remove current mysql
  mysqlrm $OLD_VERSION
  # Update and install new
  mysqladd $NEW_VERSION
}

function viewports() {
  # COMMAND, PID, USER, FD, TYPE, DEVICE, SIZE/OFF, NODE NAME
  types=$1
  if [ "$types" = '*' ]; then
    sudo lsof -i -n -P
  else
    if [ -z "$types" ]; then
      types="TCP"
    fi
    sudo lsof -i -n -P | grep "$types"
  fi
}

function listhelpers() {
  local target_dir="${2:-$ZSH_CUSTOM}" # Default to $ZSH_CUSTOM if no directory specified
  target_dir=$(realpath "$target_dir") # Get absolute path

  case "$1" in
  aliases)
    alias | cut -d'=' -f1 | sed 's/alias //' | grep -v '^_' | sort | column
    ;;
  functions)
    local func
    local output=()
    # Get all function names without leading underscore
    for func in $(declare -F | cut -d' ' -f3 | grep -v '^_'); do
      local funcinfo=$(type "$func" 2>/dev/null)
      if [[ $funcinfo == *"is a function"* ]]; then
        local source_file=$(type "$func" | grep -oP 'from \K.*' 2>/dev/null)
        if [[ -n "$source_file" ]]; then
          source_file=$(realpath "$source_file" 2>/dev/null)
          # Only include functions from the target directory
          if [[ $source_file == $target_dir* ]]; then
            output+=("$func :: ${source_file#$target_dir/}")
          fi
        fi
      fi
    done
    if ((${#output[@]})); then
      printf '%s\n' "${output[@]}" | sort | column -t -s '::'
    else
      echo "No functions found in $target_dir"
    fi
    ;;
  parameters)
    local output=()
    while IFS= read -r param; do
      if [[ -n "$param" ]]; then
        # Get the source file for this parameter
        local source_file=$(grep -l "^[[:space:]]*${param}=" "$target_dir"/* 2>/dev/null)
        if [[ -n "$source_file" ]]; then
          source_file=$(realpath "$source_file" 2>/dev/null)
          if [[ $source_file == $target_dir* ]]; then
            output+=("$param :: ${source_file#$target_dir/}")
          fi
        fi
      fi
    done < <(declare -p | cut -d' ' -f3 | cut -d= -f1 | grep -v '^_' | sort)

    if ((${#output[@]})); then
      printf '%s\n' "${output[@]}" | sort | column -t -s '::'
    else
      echo "No parameters found in $target_dir"
    fi
    ;;
  *)
    echo "Usage: listhelpers [aliases|functions|parameters] [directory]"
    echo "Examples:"
    echo "  listhelpers aliases"
    echo "  listhelpers functions $ZSH_CUSTOM"
    echo "  listhelpers parameters"
    return 1
    ;;
  esac
}

# Show install times for all Homebrew formulas (newest → oldest)
function brew_installed() {
  echo "📦 Homebrew formula install times"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Check if brew is available
  if ! command -v brew &>/dev/null; then
    echo "❌ Error: Homebrew not found" >&2
    return 1
  fi

  local formulas=("${(f)$(brew list --formula 2>/dev/null)}")

  if [[ ${#formulas} -eq 0 ]]; then
    echo "ℹ️  No formulas installed"
    return 0
  fi

  local total=${#formulas}
  local tmpfile=$(mktemp)
  local json_file=$(mktemp)

  # Trap to ensure cleanup on exit/interrupt
  trap "rm -f '$tmpfile' '$json_file'" EXIT INT TERM

  echo "⏳ Fetching formula information..." >&2

  # Fetch JSON and clean control characters
  if ! brew info --json=v2 --installed 2>/dev/null | tr -d '\000-\037' > "$json_file"; then
    echo "❌ Error: Failed to fetch formula info" >&2
    return 1
  fi

  if [[ ! -s "$json_file" ]]; then
    echo "❌ Error: Empty JSON response" >&2
    return 1
  fi

  echo "⏳ Processing $total formulas..." >&2

  local i=1
  local human epoch ts

  for formula in $formulas; do
    # Progress indicator (every 10 formulas or last one)
    if (( i % 10 == 0 || i == total )); then
      printf "\r\033[K⏳ Progress: %d/%d (%.0f%%)" "$i" "$total" "$((i * 100.0 / total))" >&2
    fi

    # Extract timestamp for this specific formula from the cleaned JSON
    ts=$(jq -r --arg f "$formula" \
      '.formulae[] | select(.name == $f) | .installed[0].time // empty' \
      "$json_file" 2>/dev/null)

    if [[ -z "$ts" ]]; then
      human="unknown"
      epoch=0
    elif [[ "$ts" == <-> ]]; then
      # Unix timestamp
      human=$(date -r "$ts" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
      epoch="$ts"
    else
      # ISO 8601 format
      human=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$ts" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$ts")
      epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$ts" "+%s" 2>/dev/null || echo 0)
    fi

    printf "%s\t%s\t%s\n" "$epoch" "$human" "$formula" >> "$tmpfile"
    ((i++))
  done

  # Clear progress line
  printf "\r\033[K" >&2

  # Sort and display results
  if [[ -s "$tmpfile" ]]; then
    sort -t $'\t' -k1,1nr "$tmpfile" | awk -F'\t' '
      BEGIN {
        count = 0
      }
      {
        count++
        time = ($2 == "unknown") ? "Unknown" : $2
        printf "%-40s  %s\n", $3, time
      }
      END {
        print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        printf "✅ Total: %d formulas\n", count
      }
    '
  else
    echo "❌ No data to display" >&2
    return 1
  fi
}
