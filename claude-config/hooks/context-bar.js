#!/usr/bin/env node
// Context Bar — renders a colored progress bar for context window usage
// and writes a bridge file for the context-monitor hook.
//
// Input: JSON from stdin (Claude Code statusline data)
// Output: colored progress bar string to stdout (e.g. "█████░░░░░ 50%")

const fs = require('fs');
const path = require('path');
const os = require('os');

let input = '';
const stdinTimeout = setTimeout(() => process.exit(0), 3000);
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  clearTimeout(stdinTimeout);
  try {
    const data = JSON.parse(input);
    const session = data.session_id || '';
    const remaining = data.context_window?.remaining_percentage;

    if (remaining == null) {
      process.exit(0);
    }

    // Claude Code reserves ~16.5% for autocompact buffer, so usable context
    // is 83.5% of the total window. Normalize to show 100% at that point.
    const AUTO_COMPACT_BUFFER_PCT = 16.5;
    const usableRemaining = Math.max(0, ((remaining - AUTO_COMPACT_BUFFER_PCT) / (100 - AUTO_COMPACT_BUFFER_PCT)) * 100);
    const used = Math.max(0, Math.min(100, Math.round(100 - usableRemaining)));

    // Write context metrics to bridge file for the context-monitor hook
    if (session) {
      try {
        const bridgePath = path.join(os.tmpdir(), `claude-ctx-${session}.json`);
        const bridgeData = JSON.stringify({
          session_id: session,
          remaining_percentage: remaining,
          used_pct: used,
          timestamp: Math.floor(Date.now() / 1000)
        });
        fs.writeFileSync(bridgePath, bridgeData);
      } catch (e) {
        // Silent fail — bridge is best-effort
      }
    }

    // Build progress bar (10 segments)
    const filled = Math.floor(used / 10);
    const bar = '\u2588'.repeat(filled) + '\u2591'.repeat(10 - filled);

    // Color based on usable context thresholds
    let output;
    if (used < 50) {
      output = `\x1b[32m${bar} ${used}%\x1b[0m`;
    } else if (used < 65) {
      output = `\x1b[33m${bar} ${used}%\x1b[0m`;
    } else if (used < 80) {
      output = `\x1b[38;5;208m${bar} ${used}%\x1b[0m`;
    } else {
      output = `\x1b[5;31m\uD83D\uDC80 ${bar} ${used}%\x1b[0m`;
    }

    process.stdout.write(output);
  } catch (e) {
    // Silent fail
  }
});
