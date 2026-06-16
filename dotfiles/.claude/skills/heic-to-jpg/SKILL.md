---
name: heic-to-jpg
description: Batch-convert HEIC images (e.g., iPhone slide screenshots) to compressed JPGs that fit under Read tool size limits. Use when the user has HEIC files that need to be reviewed visually by Claude or batch-processed for any downstream tool.
allowed-tools: Bash(sips:*), Bash(mkdir:*), Bash(ls:*), Bash(du:*), Bash(find:*)
---

# HEIC → JPG (batch converter)

Converts a directory of `.HEIC` (or `.heic`) images to JPGs sized for Claude's Read tool (~256KB cap per file).

## When to use

- User has HEIC screenshots / photos and asks Claude to review them visually.
- HEIC files are too large for `Read` (typical iPhone HEIC is 1–3MB, far above the 256KB cap).
- Batch image preprocessing for any downstream pipeline (Notion uploads, PDFs, ML pipelines).

## Usage

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/heic-to-jpg.sh <source-dir> [output-dir] [max-dimension]
```

**Arguments:**
- `source-dir` (required) — directory containing `.HEIC`/`.heic` files
- `output-dir` (optional) — defaults to `/tmp/heic-to-jpg/<source-dir-basename>`
- `max-dimension` (optional) — longest-edge resize in pixels, default `1200` (keeps most slide screenshots under 256KB)

**Examples:**
```bash
# Convert iPhone screenshots from Documents folder
bash ${CLAUDE_SKILL_DIR}/scripts/heic-to-jpg.sh "/Users/me/Documents/temporal replay/slide-screenshots"

# Custom output dir + tighter sizing
bash ${CLAUDE_SKILL_DIR}/scripts/heic-to-jpg.sh ./photos /tmp/photos-jpg 1000
```

## Output

- One `.jpg` per `.HEIC` input, same basename
- Prints count + total output size on completion
- Skips files that aren't `.HEIC`/`.heic`

## Notes

- Uses `sips` (built into macOS). Not portable to Linux — if you need that, swap in `heif-convert` or ImageMagick.
- If output JPGs are still too large for `Read`, re-run with a smaller `max-dimension` (e.g., `800`).
- Original HEIC files are never modified.
