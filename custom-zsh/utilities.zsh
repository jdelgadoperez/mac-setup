######################################################################################
# General Utilities & Helpers
# General-purpose utilities and helper functions
######################################################################################

######################################################################################
# Functions
######################################################################################

function listAlfredWorkflows() {
  for plist in ~/Library/Application\ Support/Alfred/Alfred.alfredpreferences/workflows/*/info.plist; do
    name=$(defaults read "$plist" name 2>/dev/null)
    bundleid=$(defaults read "$plist" bundleid 2>/dev/null)
    echo "$name — $bundleid"
  done
}

function listAlfredWorkflowIds() {
  cd ~/Library/Application\ Support/Alfred/Alfred.alfredpreferences/workflows
  find user.workflow.* -type f -name info.plist | while read -r plist; do
    name=$(/usr/libexec/PlistBuddy -c "Print name" "$plist" 2>/dev/null)
    if [[ -n "$name" ]]; then
      uuid_folder=$(echo "$plist" | cut -d'/' -f1)
      echo "$uuid_folder → $name"
    fi
    cd -
  done
}

function auggie() {
  # Check if augment is installed
  if ! command -v augment &> /dev/null; then
    echo "Augment not found. Installing..."
   npm install -g @augmentcode/auggie

    # Confirm installation and show version
    if command -v augment &> /dev/null; then
      echo "Augment installed successfully!"
      augment -v
    else
      echo "Failed to install augment"
      return 1
    fi
  fi

  # Run augment with provided arguments, or show help if no arguments
  if [ $# -eq 0 ]; then
    augment -h
  else
    augment "$@"
  fi
}

function dadjoke() {
  curl -s -H "Accept: text/plain" https://icanhazdadjoke.com/
}

function getabspath() {
  absolute_path=$(realpath $1)
  echo "Absolute path: ${absolute_path}"
}

function timestamp_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

function caff() {
  # Source styles if available
  if [[ -f "$ZSH_CUSTOM/styles.sh" ]]; then
    source "$ZSH_CUSTOM/styles.sh"
  fi

  # Show help
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo -e "${BOLD}${CYAN}caff${NC} - Caffeinate wrapper with time conversion\n"
    echo -e "${BOLD}Usage:${NC} caff [FLAGS] [TIME]\n"
    echo -e "${BOLD}TIME formats:${NC}"
    echo -e "  ${GREEN}2${NC}       → 2 hours"
    echo -e "  ${GREEN}2h${NC}      → 2 hours"
    echo -e "  ${GREEN}30m${NC}     → 30 minutes"
    echo -e "  ${GREEN}90s${NC}     → 90 seconds\n"
    echo -e "${BOLD}FLAGS${NC} (passed to caffeinate):"
    echo -e "  ${YELLOW}-d${NC}      → Prevent display from sleeping"
    echo -e "  ${YELLOW}-i${NC}      → Prevent system from idle sleeping"
    echo -e "  ${YELLOW}-m${NC}      → Prevent disk from idle sleeping"
    echo -e "  ${YELLOW}-s${NC}      → Prevent system from sleeping (AC power only)"
    echo -e "  ${YELLOW}-u${NC}      → Prevent system from sleeping (declare user activity)"
    echo -e "  ${YELLOW}-w PID${NC}  → Wait for process PID to exit\n"
    echo -e "${BOLD}Examples:${NC}"
    echo -e "  ${CYAN}caff 2${NC}              → Keep awake for 2 hours"
    echo -e "  ${CYAN}caff 30m${NC}            → Keep awake for 30 minutes"
    echo -e "  ${CYAN}caff -d 1.5h${NC}        → Keep display awake for 1.5 hours"
    echo -e "  ${CYAN}caff -i 45m${NC}         → Prevent idle sleep for 45 minutes"
    echo -e "  ${CYAN}caff -w 12345${NC}       → Keep awake while process 12345 runs"
    echo -e "  ${CYAN}caff${NC}                → Keep awake indefinitely (Ctrl+C to stop)\n"
    return 0
  fi

  local time_seconds=""
  local caff_flags=()
  local time_value=""
  local time_display=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|-i|-m|-s|-u)
        caff_flags+=("$1")
        shift
        ;;
      -w|-t)
        caff_flags+=("$1" "$2")
        shift 2
        ;;
      *)
        # Check if this is a time value
        if [[ "$1" =~ ^[0-9]*\.?[0-9]+([hms])?$ ]]; then
          time_value="$1"
          shift
        else
          echo "Error: Unknown argument '$1'"
          echo "Use 'caff --help' for usage information"
          return 1
        fi
        ;;
    esac
  done

  # Convert time to seconds if provided
  if [[ -n "$time_value" ]]; then
    local num="${time_value%[hms]}"
    local unit="${time_value##*[0-9]}"

    # Default to hours if no unit specified
    if [[ -z "$unit" || "$unit" == "$num" ]]; then
      unit="h"
    fi

    case "$unit" in
      h)
        time_seconds=$(awk "BEGIN {printf \"%.0f\", $num * 3600}")
        if (( $(awk "BEGIN {print ($num == 1)}") )); then
          time_display="$num hour"
        else
          time_display="$num hours"
        fi
        ;;
      m)
        time_seconds=$(awk "BEGIN {printf \"%.0f\", $num * 60}")
        if (( $(awk "BEGIN {print ($num == 1)}") )); then
          time_display="$num minute"
        else
          time_display="$num minutes"
        fi
        ;;
      s)
        time_seconds=$(awk "BEGIN {printf \"%.0f\", $num}")
        if (( $(awk "BEGIN {print ($num == 1)}") )); then
          time_display="$num second"
        else
          time_display="$num seconds"
        fi
        ;;
    esac

    caff_flags+=("-t" "$time_seconds")
  fi

  # Build caffeinate command
  local cmd="caffeinate"
  if [[ ${#caff_flags[@]} -gt 0 ]]; then
    cmd="$cmd ${caff_flags[@]}"
  fi

  # Show status message
  echo ""
  echo "${BOLD}${GREEN}☕ Caffeinating your Mac...${NC}"
  echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  if [[ -n "$time_display" ]]; then
    echo "  ${BOLD}Duration:${NC} ${YELLOW}$time_display${NC}"

    # Calculate and display end time
    local end_time=$(date -v+${time_seconds}S "+%I:%M %p")
    local end_date=$(date -v+${time_seconds}S "+%Y-%m-%d")
    local today=$(date "+%Y-%m-%d")

    if [[ "$end_date" == "$today" ]]; then
      echo "  ${BOLD}Ends at:${NC}  ${GREEN}$end_time${NC}"
    else
      local end_display=$(date -v+${time_seconds}S "+%a, %b %d at %I:%M %p")
      echo "  ${BOLD}Ends at:${NC}  ${GREEN}$end_display${NC}"
    fi
  else
    echo "  ${BOLD}Duration:${NC} ${YELLOW}indefinite${NC} ${CYAN}(Ctrl+C to stop)${NC}"
  fi

  if [[ ${#caff_flags[@]} -gt 0 ]]; then
    # Show flags excluding -t and its value
    local display_flags=()
    local i=0
    while [[ $i -lt ${#caff_flags[@]} ]]; do
      if [[ "${caff_flags[$i]}" != "-t" ]]; then
        display_flags+=("${caff_flags[$i]}")
        # Skip next arg if it's a flag that takes an argument
        if [[ "${caff_flags[$i]}" == "-w" ]]; then
          ((i++))
          if [[ $i -lt ${#caff_flags[@]} ]]; then
            display_flags+=("${caff_flags[$i]}")
          fi
        fi
      else
        ((i++)) # Skip the time value
      fi
      ((i++))
    done
    if [[ ${#display_flags[@]} -gt 0 ]]; then
      echo "  ${BOLD}Flags:${NC}    ${MAGENTA}${display_flags[@]}${NC}"
    fi
  fi

  echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  # Execute caffeinate
  eval "$cmd"
}
