#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Debug: log the input to see what we're receiving
echo "$input" >> /tmp/claude-statusline-debug.log

# Extract values using jq
LINES_ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
COST_LINES=$((LINES_ADDED + LINES_REMOVED))
COST_USD=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
DURATION=$(awk "BEGIN {printf \"%.0f\", $DURATION_MS/1000}")
MODEL_NAME=$(echo "$input" | jq -r '.model.display_name')
PROJECT_DIR=$(echo "$input" | jq -r '.workspace.project_dir')
SESSION_ID=$(echo "$input" | jq -r '.session_id // "unknown"')
VERSION=$(echo "$input" | jq -r '.version // "unknown"')

DIR_NAME=$(basename "$CURRENT_DIR")

# Git info
GIT_BRANCH=""
GIT_STATUS=""
GIT_INFO=""
if git -C "$CURRENT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    GIT_BRANCH=$(git -C "$CURRENT_DIR" -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null)
    if [ -n "$GIT_BRANCH" ]; then
        # Check for uncommitted changes
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            GIT_STATUS="*"
        fi
        GIT_INFO=$(printf "\033[38;2;255;128;191m󰳏 $GIT_BRANCH$GIT_STATUS\033[0m ")
    fi
fi

# Dracula Pro Color Palette (more muted than standard Dracula)
# Background: #22212c (34, 33, 44)
# Current Line: #44475a (68, 71, 90)
# Foreground: #f8f8f2 (248, 248, 242)
# Comment: #7970a9 (121, 112, 169)
# Cyan: #80ffea (128, 255, 234)
# Green: #8aff80 (138, 255, 128)
# Orange: #ffca80 (255, 202, 128)
# Pink: #ff80bf (255, 128, 191)
# Purple: #9580ff (149, 128, 255)
# Red: #ff9580 (255, 149, 128)
# Yellow: #ffff80 (255, 255, 128)

# Format cost and duration
COST_ROUNDED=$(awk "BEGIN {printf \"%.2f\", $COST_USD}")
DURATION_MIN=$(awk "BEGIN {printf \"%.1f\", $DURATION/60}")

printf "\033[38;2;149;128;255m🤖 $MODEL_NAME\033[0m %b\033[38;2;138;255;128m📁 $DIR_NAME\033[0m \033[38;2;255;255;128m💰 \$$COST_ROUNDED\033[0m \033[38;2;128;255;234m📝 ${COST_LINES}L\033[0m \033[38;2;121;112;169m⏱ ${DURATION_MIN}m\033[0m" "$GIT_INFO"
