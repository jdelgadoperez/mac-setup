#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Get username and hostname
USER=$(whoami)
HOSTNAME=$(hostname -s)

# Get current time in 12-hour format
CURRENT_TIME=$(date +"%I:%M %p")

# Extract values using jq
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir')
CONTEXT_REMAINING=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
LINES_ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
COST_LINES=$((LINES_ADDED + LINES_REMOVED))
COST_USD=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
DURATION=$(awk "BEGIN {printf \"%.0f\", $DURATION_MS/1000}")
MODEL_NAME=$(echo "$input" | jq -r '.model.display_name')
PROJECT_DIR=$(echo "$input" | jq -r '.workspace.project_dir')
SESSION_ID=$(echo "$input" | jq -r '.session_id // "unknown"')
VERSION=$(echo "$input" | jq -r '.version // "unknown"')
DIR_NAME=$(basename "$CURRENT_DIR")

# Get directory (abbreviate home directory)
DIR_PATH="${CURRENT_DIR/#$HOME/~}"

# Dracula Pro Color Palette (more muted than standard Dracula)
PADDING="-36"
# Background: #22212c (34, 33, 44)
BG='\033[48;2;34;33;44m'
# Current Line: #44475a (68, 71, 90)
CURRENT_LINE='\033[48;2;68;71;90m'
# Foreground: #f8f8f2 (248, 248, 242)
FG='\033[38;2;248;248;242m'
# Comment: #7970a9 (121, 112, 169)
COMMENT='\033[38;2;121;112;169m'
# Cyan: #80ffea (128, 255, 234)
CYAN='\033[38;2;128;255;234m'
# Green: #8aff80 (138, 255, 128)
GREEN='\033[38;2;138;255;128m'
# Orange: #ffca80 (255, 202, 128)
ORANGE='\033[38;2;255;202;128m'
# Pink: #ff80bf (255, 128, 191)
PINK='\033[38;2;255;128;191m'
# Purple: #9580ff (149, 128, 255)
PURPLE='\033[38;2;149;128;255m'
# Red: #ff9580 (255, 149, 128)
RED='\033[38;2;255;149;128m'
# Yellow: #ffff80 (255, 255, 128)
YELLOW='\033[38;2;255;255;128m'
# Reset
RESET='\033[0m'

GIT_BRANCH=""
GIT_STATUS=""
if git -C "$CURRENT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    GIT_BRANCH=$(git -C "$CURRENT_DIR" -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null)
    if [ -n "$GIT_BRANCH" ]; then
        # Check for uncommitted changes
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            GIT_STATUS="*"
        fi
    fi
fi

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

# Context window indicator (if available)
CONTEXT_INFO=""
if [ -n "$CONTEXT_REMAINING" ]; then
    CONTEXT_INFO=$(printf "📉 ${ORANGE}${CONTEXT_REMAINING}%% ")
fi

$GIT_INFO=""
if [ -n "$GIT_BRANCH" ]; then
    GIT_INFO=$(printf "${PINK}󰳏 $GIT_BRANCH $GIT_STATUS ")
fi

COST_ROUNDED=$(awk "BEGIN {printf \"%.2f\", $COST_USD}")
DURATION_MIN=$(awk "BEGIN {printf \"%.1f\", $DURATION/60}")
DAD_JOKE=$(get_dad_joke)

# Build status line: username on hostname in directory [git] [time] [context]
printf "🕐 ${FG}${CURRENT_TIME} ${CONTEXT_INFO}${RESET}"
echo -e "🤖 ${PURPLE}[$MODEL_NAME] 📁 ${GREEN}$DIR_NAME ${CONTEXT_INFO}💰 ${YELLOW}\$${COST_ROUNDED} 📝 ${ORANGE}\$${COST_LINES}L ${CYAN}🕐 ${DURATION_MIN}m ${GIT_INFO}${RESET}"
printf "\n\n${COMMENT}🔥 ${DAD_JOKE}${RESET}"
