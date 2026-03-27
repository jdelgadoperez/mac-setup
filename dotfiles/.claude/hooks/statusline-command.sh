#!/bin/bash

# Dracula Color Palette (matching Starship config)
# Using standard Dracula colors from your starship.toml

# Foreground: #f8f8f2 (248, 248, 242)
FG='\033[38;2;248;248;242m'
# Comment: #6272a4 (98, 114, 164)
COMMENT='\033[38;2;98;114;164m'
# Cyan: #8be9fd (139, 233, 253)
CYAN='\033[38;2;139;233;253m'
# Green: #50fa7b (80, 250, 123)
GREEN='\033[38;2;80;250;123m'
# Orange: #ffb86c (255, 184, 108)
ORANGE='\033[38;2;255;184;108m'
# Pink: #ff79c6 (255, 121, 198)
PINK='\033[38;2;255;121;198m'
# Purple: #bd93f9 (189, 147, 249)
PURPLE='\033[38;2;189;147;249m'
# Red: #ff5555 (255, 85, 85)
RED='\033[38;2;255;85;85m'
# Yellow: #f1fa8c (241, 250, 140)
YELLOW='\033[38;2;241;250;140m'
# Bold
BOLD='\033[1m'
# Reset
RESET='\033[0m'

# Dad joke caching with 5-minute TTL
get_dad_joke() {
    local cache_file="/tmp/.claude_dad_joke_cache"
    local cache_time_file="/tmp/.claude_dad_joke_time"
    local current_time=$(date +%s)
    local cache_duration=300  # 5 minutes in seconds

    # Check if cache exists and is still valid
    if [ -f "$cache_time_file" ] && [ -f "$cache_file" ]; then
        local cached_time=$(cat "$cache_time_file")
        local time_diff=$((current_time - cached_time))

        if [ "$time_diff" -lt "$cache_duration" ]; then
            # Cache is still valid, return cached joke
            cat "$cache_file"
            return
        fi
    fi

    # Cache expired or doesn't exist, fetch new joke from API
    local joke=$(curl -s -H "Accept: application/json" https://icanhazdadjoke.com/ 2>/dev/null | jq -r '.joke' 2>/dev/null)

    # If curl fails or joke is empty, don't cache and return empty string
    if [ -z "$joke" ] || [ "$joke" = "null" ]; then
        return
    fi

    # Cache the joke and timestamp
    echo "$joke" > "$cache_file"
    echo "$current_time" > "$cache_time_file"

    echo "$joke"
}

# Read JSON input from stdin
input=$(cat)

# Extract values using jq
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir')
MODEL_NAME=$(echo "$input" | jq -r '.model.display_name')
TOTAL_INPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
TOTAL_OUTPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
TOTAL_DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
DAD_JOKE=$(get_dad_joke)

# Context progress bar (rendered by context-bar.js)
CONTEXT_BAR=$(echo "$input" | node "$HOME/.claude/hooks/context-bar.js" 2>/dev/null)

# Format duration from milliseconds to human readable
format_duration() {
    local ms=$1
    local total_seconds=$((ms / 1000))
    local hours=$((total_seconds / 3600))
    local minutes=$(((total_seconds % 3600) / 60))

    if [ "$hours" -gt 0 ]; then
        echo "${hours}h ${minutes}m"
    elif [ "$minutes" -gt 0 ]; then
        echo "${minutes}m"
    else
        echo "<1m"
    fi
}

SESSION_DURATION=$(format_duration "$TOTAL_DURATION_MS")

# Get current directory basename (matching Starship \W)
DIR_NAME=$(basename "$CURRENT_DIR")

# Get current time in 12-hour format with short date
CURRENT_TIME=$(date +"%b %d %I:%M%p")

# Git information with Starship symbol
GIT_BRANCH=""
GIT_STATUS=""
if git -C "$CURRENT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    GIT_BRANCH=$(git -C "$CURRENT_DIR" -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null)
    if [ -n "$GIT_BRANCH" ]; then
        # Check for various git states (matching Starship git_status)
        GIT_STATUS_OUTPUT=$(git -C "$CURRENT_DIR" status --porcelain 2>/dev/null)
        if [ -n "$GIT_STATUS_OUTPUT" ]; then
            GIT_STATUS="*"
        fi
    fi
fi

# Build the status line with time at the beginning
LINE_SEPARATOR="${COMMENT}|${RESET}"
DOT_SEPARATOR="${PINK}•${RESET}"

# Start with time
LINE="${FG}${CURRENT_TIME}${RESET} ${LINE_SEPARATOR}"

# Add directory
LINE="${LINE} ${BOLD}${GREEN}${DIR_NAME}${RESET}"

# Add git branch if available
if [ -n "$GIT_BRANCH" ]; then
    LINE="${LINE} ${LINE_SEPARATOR} ${PURPLE}󰳏 ${BOLD}${PURPLE}${GIT_BRANCH}${RESET}"
    if [ -n "$GIT_STATUS" ]; then
        LINE="${LINE} ${BOLD}${RED}${GIT_STATUS}${RESET} ${DOT_SEPARATOR}"
    fi
fi

# Add separator and model info
LINE="${LINE} ${LINE_SEPARATOR} ${CYAN}${MODEL_NAME}${RESET}"

# Add token usage (cumulative for session)
TOTAL_TOKENS=$((TOTAL_INPUT_TOKENS + TOTAL_OUTPUT_TOKENS))
if [ "$TOTAL_TOKENS" -gt 0 ]; then
    FORMATTED_TOKENS=$(printf "%'d" "$TOTAL_TOKENS" 2>/dev/null || echo "$TOTAL_TOKENS")
    LINE="${LINE} ${YELLOW}Tokens: ${FORMATTED_TOKENS} ${DOT_SEPARATOR}"
fi

# Add context progress bar if available
if [ -n "$CONTEXT_BAR" ]; then
    LINE="${LINE} ${CONTEXT_BAR}"
fi

# Add session duration
LINE1="${LINE} ${PURPLE}${SESSION_DURATION}${RESET}"
LINE2="${COMMENT}${DAD_JOKE}${RESET}"
echo -e "${LINE1}"
echo -e "${LINE2}"
