#!/usr/bin/env bash
# Batch-convert HEIC images to compressed JPGs sized for Claude's Read tool.
# Usage: heic-to-jpg.sh <source-dir> [output-dir] [max-dimension]

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <source-dir> [output-dir] [max-dimension]" >&2
    exit 1
fi

SRC_DIR="$1"
OUT_DIR="${2:-/tmp/heic-to-jpg/$(basename "$SRC_DIR")}"
MAX_DIM="${3:-1200}"

if [[ ! -d "$SRC_DIR" ]]; then
    echo "Error: source directory not found: $SRC_DIR" >&2
    exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
    echo "Error: 'sips' not found (this script requires macOS)" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"

count=0
skipped=0
shopt -s nullglob nocaseglob

for f in "$SRC_DIR"/*.heic; do
    name="$(basename "$f")"
    stem="${name%.*}"
    out="$OUT_DIR/${stem}.jpg"
    if sips -s format jpeg -Z "$MAX_DIM" "$f" --out "$out" >/dev/null 2>&1; then
        count=$((count + 1))
    else
        echo "Warn: failed to convert $name" >&2
        skipped=$((skipped + 1))
    fi
done

shopt -u nocaseglob

if [[ $count -eq 0 ]]; then
    echo "No HEIC files found in $SRC_DIR" >&2
    exit 1
fi

total_size=$(du -sh "$OUT_DIR" | awk '{print $1}')
echo "Converted $count HEIC → JPG (max edge ${MAX_DIM}px)"
[[ $skipped -gt 0 ]] && echo "Skipped: $skipped"
echo "Output: $OUT_DIR ($total_size)"
