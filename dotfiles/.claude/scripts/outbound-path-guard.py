#!/usr/bin/env python3
"""Detect local-path / machine leakage in outbound (externally-visible) content.

Reads a PreToolUse payload (JSON) on stdin, decides whether the tool call would
publish a local filesystem path or this machine's identity to an external
surface (GitHub, Slack, Jira/Linear, Notion, ...), and if so prints the
offending strings and exits non-zero.

Exit codes:
  0  clean  -> allow
  2  leakage detected -> block (offenders printed to stdout, one per line)
  3  fail-closed: content lives in an out-of-band file (--body-file/--input/
     -F @file) so it can't be scanned -> block

The wrapper hook (outbound-path-guard.sh) turns a non-zero exit into a
{"decision":"block"} JSON. This split keeps the fiddly regex testable in
isolation from the shell plumbing.

Rules (per the user's spec):
  BLOCK:
    - any absolute home path:            /Users/<anyuser>/...
    - ~ expansions:                      ~/... or ~<user>/...
    - temp paths:                        /private/tmp/..., /tmp/claude/...,
                                         $TMPDIR/..., paths under /var/folders
    - any absolute path under the drata container dir, INCLUDING its .llm and
      _reports/_summaries/_pr-reviews subtrees (the container is NOT a repo)
    - local machine hostname, and file:// URLs pointing at a local path
  ALLOW:
    - bare RELATIVE artifact dir names on their own (_reports/x, _summaries/y)
    - bare RELATIVE .llm/... paths (real repos carry their own .llm dir)
    - repo references in prose (drata/api, drata/web) that are NOT rooted at
      an absolute local path
"""
import json
import re
import socket
import sys

HOME_USER_DIR = "/Users/jessdelgadoperez"
DRATA_CONTAINER = f"{HOME_USER_DIR}/projects/drata"

# --- surfaces we scan --------------------------------------------------------
# MCP write tools whose payloads are outbound. For these we scan every string
# value in tool_input. Matched by substring so plugin-prefix variants also hit.
MCP_OUTBOUND_SUBSTRINGS = (
    "slack_send_message",
    "slack_schedule_message",
    "slack_create_canvas",
    "slack_update_canvas",
    "notion-create-pages",
    "notion-update-page",
    "notion-create-comment",
    "notion-create-database",
    "Linear__save_issue",
    "Linear__save_comment",
    "Linear__save_document",
    "Linear__save_project",
    "Linear__save_milestone",
    "Linear__create_attachment",
)

# For Bash, only these commands actually publish. Everything else is local.
BASH_POST_MARKERS = (
    r"gh\s+pr\s+(review|comment|create|edit)",
    r"gh\s+issue\s+(create|comment|edit)",
    r"gh\s+api\b",
    r"acli\s+jira\s+workitem\s+(create|comment|edit|transition)",
    r"linear-cli\b",
    r"slack_send_message",
    r"curl\b",  # posting to a webhook/API
)

# Executables the markers above look for. When one is run by an absolute or ~
# path (the linear plugin runs its bundled linear-cli from the plugin cache),
# that path is the program, not content being sent.
POST_PROGRAMS = ("linear-cli", "gh", "acli", "curl")

# A path ending in a POST_PROGRAM in command position (start of command, start
# of a line in a multi-line script, or after ; & | ( or $(), optionally quoted. Paths anywhere else — bodies, flags,
# JSON arguments — are left in place and still scanned.
PROGRAM_PATH_RE = re.compile(
    r"""(?P<lead>^|[;&|(\n]|\$\()(?P<space>[ \t]*)(?P<quote>["']?)"""
    r"""(?:~[A-Za-z0-9._-]*|/)[^\s"'`;&|()]*/"""
    r"""(?P<program>""" + "|".join(map(re.escape, POST_PROGRAMS)) + r""")"""
    r"""(?P=quote)(?=\s|$|[;&|)])""")


def strip_program_paths(command):
    """Replace a post tool's own executable path with its bare name."""
    return PROGRAM_PATH_RE.sub(
        lambda match: match["lead"] + match["space"] + match["program"], command)

# Out-of-band content flags: content is in a file, not the command string.
# We can't scan it, so we fail closed for post-intent commands that use them.
OUT_OF_BAND_FLAGS = (
    r"--body-file\b",
    r"--input\b",
    r"-F\s+\S+=@",   # gh api -F body=@file
    r"-f\s+\S+=@",
    r"--field\s+\S+=@",
)


def _leak_patterns():
    """Compiled (label, regex) pairs. Order = report priority."""
    drata = re.escape(DRATA_CONTAINER)
    return [
        # Absolute paths under the drata container dir (incl. .llm/_reports/etc).
        # Listed first so a drata path is labeled specifically, not as a generic
        # home path.
        ("drata container path", re.compile(drata + r"(/[^\s\"'`)]*)?")),
        # Any other absolute home path.
        ("home path", re.compile(r"/Users/[A-Za-z0-9._-]+(/[^\s\"'`)]*)?")),
        # ~ expansions (~/... and ~user/...).
        ("home (~) path", re.compile(r"(?<![\w])~[A-Za-z0-9._-]*/[^\s\"'`)]+")),
        # Temp dirs.
        ("temp path", re.compile(
            r"(?:/private/tmp|/tmp/claude|/tmp/|/var/folders)[^\s\"'`)]*")),
        ("$TMPDIR path", re.compile(r"\$TMPDIR/[^\s\"'`)]*")),
        # Local file:// URLs.
        ("local file:// URL", re.compile(r"file://[^\s\"'`)]+")),
    ]


def _hostname_patterns():
    """Match this machine's hostname(s) as a whole word. Built at runtime."""
    names = set()
    try:
        names.add(socket.gethostname())
    except Exception:
        pass
    try:
        fqdn = socket.getfqdn()
        if fqdn:
            names.add(fqdn)
            names.add(fqdn.split(".")[0])
    except Exception:
        pass
    pats = []
    for n in names:
        n = (n or "").strip()
        # Skip trivial/degenerate names that would over-match.
        if len(n) < 4 or n.lower() in ("localhost", "local"):
            continue
        pats.append(("machine hostname",
                     re.compile(r"(?<![\w.-])" + re.escape(n) + r"(?![\w-])")))
    return pats


def find_leaks(text):
    if not text:
        return []
    offenders = []
    seen = set()
    for label, pat in _leak_patterns() + _hostname_patterns():
        for m in pat.finditer(text):
            hit = m.group(0)
            key = (label, hit)
            if key in seen:
                continue
            seen.add(key)
            offenders.append((label, hit))
    return offenders


def collect_strings(obj, out):
    """Recursively gather every string leaf from a tool_input object."""
    if isinstance(obj, str):
        out.append(obj)
    elif isinstance(obj, dict):
        for v in obj.values():
            collect_strings(v, out)
    elif isinstance(obj, list):
        for v in obj:
            collect_strings(v, out)


def main():
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw)
    except Exception:
        # Can't parse -> not our job to block; let other guards handle.
        return 0

    tool = payload.get("tool_name", "") or ""
    tool_input = payload.get("tool_input", {}) or {}

    texts = []

    if tool == "Bash":
        cmd = tool_input.get("command", "") or ""
        if not cmd:
            return 0
        is_post = any(re.search(p, cmd) for p in BASH_POST_MARKERS)
        if not is_post:
            return 0
        # Fail closed if the outbound body is in an unreadable out-of-band file.
        if any(re.search(f, cmd) for f in OUT_OF_BAND_FLAGS):
            print("FAIL_CLOSED: outbound content is in a --body-file/--input/"
                  "@file, which can't be scanned. Inline the content (e.g. "
                  "--body \"...\") so it can be checked, or post it yourself "
                  "after confirming no local paths leak.")
            return 3
        texts.append(strip_program_paths(cmd))
    elif any(s in tool for s in MCP_OUTBOUND_SUBSTRINGS):
        collect_strings(tool_input, texts)
    else:
        return 0

    offenders = []
    seen = set()
    for t in texts:
        for label, hit in find_leaks(t):
            key = (label, hit)
            if key in seen:
                continue
            seen.add(key)
            offenders.append((label, hit))

    if offenders:
        for label, hit in offenders:
            print(f"{label}: {hit}")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
