#!/usr/bin/env node
/**
 * Claude Code Session Start Hook
 * 1. Persists transcript_path for save-session and session-end cleanup
 * 2. Shows active work log tasks as a system message
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const os = require('os');

const WORK_LOG_PATH = '/Users/jessdelgadoperez/projects/drata/work-log.md';
const SESSIONS_DIR = '/tmp/claude-sessions';
const KEY_FIELDS = ['PR:', 'Worktree:', 'Status:'];

const readStdin = async () => {
  let data = '';
  process.stdin.setEncoding('utf8');
  for await (const chunk of process.stdin) data += chunk;
  return data;
};

const parseHookData = (raw) => {
  if (!raw) return null;
  try { return JSON.parse(raw); } catch { return null; }
};

const persistTranscriptPath = (transcriptPath) => {
  if (!transcriptPath) return;
  // Create directory with restrictive permissions (0o700) to prevent symlink attacks
  fs.mkdirSync(SESSIONS_DIR, { recursive: true, mode: 0o700 });
  // Use ppid + random suffix to reduce collisions (ppid reuse is still possible, but less likely)
  const randomSuffix = Math.random().toString(36).substring(2, 8);
  fs.writeFileSync(path.join(SESSIONS_DIR, `${process.ppid}-${randomSuffix}.transcript`), transcriptPath);
};

const getPendingReviewCounts = () => {
  try {
    const result = execSync(
      'gh search prs --review-requested=@me --state=open --json isDraft --limit 50',
      { encoding: 'utf8', timeout: 15000, stdio: ['pipe', 'pipe', 'pipe'] }
    );
    const prs = JSON.parse(result.trim());
    const draft = prs.filter((pr) => pr.isDraft).length;
    return { total: prs.length, ready: prs.length - draft, draft };
  } catch {
    return null;
  }
};

const stripMarkdownLinks = (text) => text.replace(/\[([^\]]+)\]\([^)]+\)/g, '$1');

const extractTasks = (content, sectionHeader) => {
  // Strip HTML comments first so commented-out (archived/done) task blocks
  // aren't parsed as live tasks. Handles both single-line `<!-- ... -->` and
  // multi-line block comments spanning many lines.
  const visible = content.replace(/<!--[\s\S]*?-->/g, '');
  const lines = visible.split('\n');
  const tasks = [];
  let inSection = false;
  let current = null;

  for (const line of lines) {
    if (line.startsWith('## ')) {
      if (line.startsWith(sectionHeader)) { inSection = true; continue; }
      if (inSection) break;
    }
    if (!inSection) continue;

    if (/^- \[[ x]\] /.test(line)) {
      current = { title: line.replace(/^- \[[ x]\] /, ''), fields: [] };
      tasks.push(current);
    } else if (current && /^ {2}- /.test(line)) {
      const field = line.trim().replace(/^- /, '');
      if (KEY_FIELDS.some((k) => field.startsWith(k))) {
        current.fields.push(field);
      }
    }
  }

  return tasks;
};

const formatTask = (task) => {
  const title = stripMarkdownLinks(task.title);
  const fields = task.fields.map(stripMarkdownLinks).join(' │ ');
  return fields ? `  ▸ ${title}\n    ${fields}` : `  ▸ ${title}`;
};

const buildSystemMessage = (active, blocked, reviewCounts) => {
  const sections = [];

  if (active.length) {
    sections.push('━━━ Active Tasks ━━━', '', ...active.map(formatTask));
  }
  if (blocked.length) {
    if (sections.length) sections.push('');
    sections.push('━━━ Blocked ━━━', '', ...blocked.map(formatTask));
  }
  if (reviewCounts && reviewCounts.total > 0) {
    if (sections.length) sections.push('');
    const { total, ready, draft } = reviewCounts;
    const breakdown = `${ready} ready, ${draft} draft`;
    sections.push(
      '━━━ Code Reviews ━━━',
      '',
      `  ${total} PR${total === 1 ? '' : 's'} awaiting your review (${breakdown}).`,
      '  /review:prs to see and review them.'
    );
  }

  sections.push('', '─'.repeat(40), '/work-log to see full details or update tasks.');
  return '\n' + sections.join('\n');
};

async function main() {
  const data = parseHookData(await readStdin());
  if (!data) return;

  persistTranscriptPath(data.transcript_path);

  const reviewCounts = getPendingReviewCounts();

  const hasWorkLog = fs.existsSync(WORK_LOG_PATH);
  const workLog = hasWorkLog ? fs.readFileSync(WORK_LOG_PATH, 'utf8') : '';
  const hasOpenTasks = workLog.includes('- [ ]');

  if (!hasOpenTasks && (!reviewCounts || reviewCounts.total <= 0)) return;

  const active = hasOpenTasks ? extractTasks(workLog, '## Active') : [];
  const blocked = hasOpenTasks ? extractTasks(workLog, '## Blocked') : [];

  console.log(JSON.stringify({
    systemMessage: buildSystemMessage(active, blocked, reviewCounts),
    hookSpecificOutput: { hookEventName: 'SessionStart', additionalContext: workLog },
  }));
}

main().catch(() => {});
