---
name: writing-voice
description: "Writing voice reference template for AI writing assistants. Captures authentic communication style patterns for code reviews, Slack messages, and other written communication."
install: copy
---

# Writing Voice

A customizable voice reference template used by `vera-voice-assistant` and other writing tools.

## Files

| File | Purpose |
|------|---------|
| `writing-voice.md` | Voice reference template — customize with your own writing samples |

## Usage

The voice file is read by `vera-voice-assistant` during voice passes (e.g., in the tyler-ai review pipeline). Install it to `~/.claude/tyler-ai-voice.md` and customize with your own writing examples.

## Customization

Replace the example sections in `writing-voice.md` with your own:
- Writing samples (Slack messages, PR descriptions, status updates)
- Tone patterns (how you naturally communicate)
- Code review voice (how you give technical feedback)
- Anti-patterns (things to avoid in your voice)
