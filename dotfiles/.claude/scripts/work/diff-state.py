#!/usr/bin/env python3
"""
diff-state.py — compare a live work-log state JSON against a cached snapshot
and emit a structured diff.

Usage:
    diff-state.py <new-state.json> [--cache <path>]

If --cache is omitted, defaults to ~/.claude/state/work-log-state.json.
After diffing, the cache is NOT rewritten — the caller decides when to
promote (e.g., after successfully applying sync notes to the work log).

Output JSON:
{
  "has_changes": true,
  "prs": [
    {
      "key": "api#32262",
      "changes": [
        {"field": "ciRollup", "from": "FAILURE", "to": "SUCCESS"},
        {"field": "approvers", "added": ["aaron-junot"], "removed": []}
      ]
    }
  ],
  "tickets": [
    {"key": "PLAT-14371", "changes": [{"field": "status", "from": "Code Review", "to": "In Progress"}]}
  ]
}
"""

import argparse
import json
import os
import sys
from pathlib import Path


DEFAULT_CACHE = Path.home() / ".claude" / "state" / "work-log-state.json"

PR_SCALAR_FIELDS = ("state", "isDraft", "reviewDecision", "ciRollup", "headRefOid", "mergedAt")
PR_LIST_FIELDS = ("approvers", "changesRequestedBy")
TICKET_FIELDS = ("status", "sprint", "assignee")


def load(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        print(f"warning: {path} is not valid JSON, treating as empty", file=sys.stderr)
        return {}


def diff_scalar(field, old, new):
    if old != new:
        return {"field": field, "from": old, "to": new}
    return None


def diff_list(field, old, new):
    old_set = set(old or [])
    new_set = set(new or [])
    added = sorted(new_set - old_set)
    removed = sorted(old_set - new_set)
    if added or removed:
        return {"field": field, "added": added, "removed": removed}
    return None


def diff_pr(key, old, new):
    changes = []
    for f in PR_SCALAR_FIELDS:
        c = diff_scalar(f, old.get(f), new.get(f))
        if c:
            changes.append(c)
    for f in PR_LIST_FIELDS:
        c = diff_list(f, old.get(f), new.get(f))
        if c:
            changes.append(c)
    if changes:
        return {"key": key, "changes": changes, "title": new.get("title")}
    return None


def diff_ticket(key, old, new):
    changes = []
    for f in TICKET_FIELDS:
        c = diff_scalar(f, old.get(f), new.get(f))
        if c:
            changes.append(c)
    if changes:
        return {"key": key, "changes": changes}
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("new_state", help="Path to new state JSON (output of fetch-state.sh)")
    ap.add_argument("--cache", default=str(DEFAULT_CACHE), help="Path to cached state")
    ap.add_argument("--promote", action="store_true", help="Overwrite cache with new state after diffing")
    args = ap.parse_args()

    new = load(Path(args.new_state))
    cache = load(Path(args.cache))

    new_prs = new.get("prs", {})
    new_tickets = new.get("tickets", {})
    old_prs = cache.get("prs", {})
    old_tickets = cache.get("tickets", {})

    pr_diffs = []
    for key, new_pr in new_prs.items():
        d = diff_pr(key, old_prs.get(key, {}), new_pr)
        if d:
            pr_diffs.append(d)

    ticket_diffs = []
    for key, new_t in new_tickets.items():
        d = diff_ticket(key, old_tickets.get(key, {}), new_t)
        if d:
            ticket_diffs.append(d)

    out = {
        "has_changes": bool(pr_diffs or ticket_diffs),
        "fetched_at": new.get("fetched_at"),
        "prs": pr_diffs,
        "tickets": ticket_diffs,
    }

    print(json.dumps(out, indent=2))

    if args.promote:
        cache_path = Path(args.cache)
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(json.dumps(new, indent=2))
        print(f"cache promoted → {cache_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
