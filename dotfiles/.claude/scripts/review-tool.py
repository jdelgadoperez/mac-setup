#!/usr/bin/env python3
"""
review-tool.py — CLI for code review posting workflows.

Subcommands:
  resolve-lines  Verify/correct sidecar line numbers against a diff (stdin)
  post           Compose and post a GitHub PR review from a sidecar
  repost         Delete old review comments and re-post with corrected data

Organization is resolved in this order:
  1. --org flag
  2. REVIEW_TOOL_ORG environment variable
  3. Sidecar 'org' field
  4. Inferred from current repo via 'gh repo view'
"""

import argparse
import json
import os
import re
import subprocess
import sys


# ============================================================================
# ORG RESOLUTION
# ============================================================================

def resolve_org(args_org, sidecar=None):
    """Resolve the GitHub organization from args, env, sidecar, or git context."""
    if args_org:
        return args_org

    env_org = os.environ.get('REVIEW_TOOL_ORG')
    if env_org:
        return env_org

    if sidecar and sidecar.get('org'):
        return sidecar['org']

    # Try to infer from current repo
    try:
        result = subprocess.run(
            ['gh', 'repo', 'view', '--json', 'owner', '--jq', '.owner.login'],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    print("Error: could not determine GitHub org. Use --org, set REVIEW_TOOL_ORG, or run from a repo.", file=sys.stderr)
    sys.exit(1)


# ============================================================================
# DIFF PARSING
# ============================================================================

def parse_diff(diff_text):
    """Parse a unified diff into per-file line maps.

    Returns: {file_path: {new_line_number: line_content}}
    Only includes lines visible in the diff (+ lines and context lines).
    """
    files = {}
    current_file = None
    current_line = 0

    for line in diff_text.splitlines():
        if line.startswith('diff --git'):
            match = re.search(r' b/(.+)$', line)
            if match:
                current_file = match.group(1)
                files[current_file] = {}
            continue

        if line.startswith('@@'):
            match = re.search(r'\+(\d+)', line)
            if match:
                current_line = int(match.group(1)) - 1
            continue

        if current_file is None:
            continue

        if line.startswith('+'):
            current_line += 1
            files[current_file][current_line] = line[1:]
        elif line.startswith('-'):
            pass  # deleted lines don't increment new-file counter
        else:
            current_line += 1
            files[current_file][current_line] = line[1:] if line.startswith(' ') else line

    return files


def extract_code_snippets(body):
    """Extract code snippets from a finding body for content matching.

    Returns snippets ordered by specificity (longest first) for better matching.
    """
    snippets = set()

    # Code blocks — extract individual lines that look like real code
    for match in re.finditer(r'```\w*\n(.*?)```', body, re.DOTALL):
        for line in match.group(1).strip().splitlines():
            stripped = line.strip()
            # Skip comments, empty, short, and non-code lines
            if (stripped
                    and len(stripped) > 15
                    and not stripped.startswith('//')
                    and not stripped.startswith('#')
                    and not stripped.startswith('**')):
                snippets.add(stripped)

    # Inline code — only substantial statements (skip variable names, short refs)
    # Avoid matching inside triple-backtick regions
    body_no_blocks = re.sub(r'```.*?```', '', body, flags=re.DOTALL)
    for match in re.finditer(r'`([^`]+)`', body_no_blocks):
        code = match.group(1).strip()
        if len(code) > 20:
            snippets.add(code)

    # Return longest first — longer snippets are more specific
    return sorted(snippets, key=len, reverse=True)


def find_best_line(file_lines, claimed_line, body):
    """Find the best matching line number for a finding.

    Returns: (corrected_line, reason) or (claimed_line, None) if valid.
    """
    snippets = extract_code_snippets(body)

    # If line is in the diff, verify content matches a body snippet
    if claimed_line in file_lines:
        if not snippets:
            return claimed_line, None  # No snippets to verify against

        claimed_content = file_lines[claimed_line].strip()
        if claimed_content:
            for snippet in snippets:
                if snippet in claimed_content:
                    return claimed_line, None  # Content matches

        # Line is in diff but content doesn't match — fall through to search

    # Search all diff lines for content matches
    # Only match snippet-in-content (not content-in-snippet) to avoid false positives
    matches = []
    for snippet in snippets:
        for line_num, content in file_lines.items():
            content_stripped = content.strip()
            if not content_stripped:
                continue
            if snippet in content_stripped:
                matches.append(line_num)

    if matches:
        best = min(matches, key=lambda x: abs(x - claimed_line))
        reason = "content match" if claimed_line not in file_lines else "content mismatch corrected"
        return best, reason

    # No content match
    if claimed_line in file_lines:
        return claimed_line, None  # Can't verify, keep as-is

    if file_lines:
        nearest = min(file_lines.keys(), key=lambda x: abs(x - claimed_line))
        return nearest, f"nearest valid (no content match)"

    return claimed_line, "no valid lines in diff for this file"


# ============================================================================
# SUBCOMMANDS
# ============================================================================

def cmd_resolve_lines(args):
    """Verify/correct sidecar line numbers against a diff."""
    with open(args.sidecar) as f:
        sidecar = json.load(f)

    diff_text = sys.stdin.read()
    if not diff_text.strip():
        print("Error: no diff provided on stdin", file=sys.stderr)
        sys.exit(1)

    file_lines = parse_diff(diff_text)

    changes = []
    for comment in sidecar.get('comments', []):
        path = comment.get('path')
        line = comment.get('line')

        if path is None or line is None:
            continue

        if path not in file_lines:
            changes.append((comment['id'], line, None, f"file '{path}' not found in diff"))
            continue

        corrected, reason = find_best_line(file_lines[path], line, comment.get('body', ''))

        if reason:
            changes.append((comment['id'], line, corrected, reason))
            comment['line'] = corrected

    if not changes:
        print("All line numbers verified — no corrections needed.")
        return

    print(f"{'ID':<25} {'Was':<6} {'Now':<6} Reason")
    print("-" * 70)
    for cid, old, new, reason in changes:
        new_str = str(new) if new is not None else "???"
        print(f"{cid:<25} {old:<6} {new_str:<6} {reason}")

    if not args.dry_run:
        with open(args.sidecar, 'w') as f:
            json.dump(sidecar, f, indent=2)
            f.write('\n')
        print(f"\nSidecar updated: {args.sidecar}")
    else:
        print(f"\nDry run — no changes written.")


def cmd_post(args):
    """Compose and post a GitHub PR review from a sidecar."""
    with open(args.sidecar) as f:
        sidecar = json.load(f)

    org = resolve_org(args.org, sidecar)
    repo = args.repo or sidecar.get('repo')
    pr = args.pr or sidecar.get('pr')

    if not repo or not pr:
        print("Error: --repo and --pr required (or must be in sidecar)", file=sys.stderr)
        sys.exit(1)

    selected_ids = parse_selection(args.select, sidecar)
    if not selected_ids:
        print("Error: no valid IDs selected", file=sys.stderr)
        sys.exit(1)

    selected = [c for c in sidecar['comments'] if c['id'] in selected_ids]

    # Derive event
    has_blocking = any(c['type'] == 'blocking' for c in selected)
    event = 'REQUEST_CHANGES' if has_blocking else 'APPROVE'

    # Check commit freshness
    current_sha = gh_get_head_sha(org, repo, pr)
    sidecar_sha = sidecar['commit_id']

    if current_sha and current_sha != sidecar_sha:
        print(f"Warning: PR has new commits since review was generated.")
        print(f"  Reviewed: {sidecar_sha}")
        print(f"  Current:  {current_sha}")
        if not args.yes:
            print("  Use --yes to post anyway, or re-review first.")
            sys.exit(1)

    # Split inline vs body-level comments
    inline_comments = []
    body_comments = []

    for c in selected:
        if c.get('path') and c.get('line'):
            inline_comments.append({
                'path': c['path'],
                'line': c['line'],
                'side': c.get('side', 'RIGHT'),
                'body': c['body']
            })
        else:
            body_comments.append(c)

    # Compose review body
    if event == 'REQUEST_CHANGES':
        blocking = [c for c in selected if c['type'] == 'blocking']
        items = ', '.join(f"({i+1}) {c['title']}" for i, c in enumerate(blocking))
        body = f"Requesting changes on {len(blocking)} blocking issue{'s' if len(blocking) != 1 else ''}: {items}. See inline comments for details."
    else:
        if inline_comments:
            body = "Reviewed and approved. See inline comments for non-blocking suggestions."
        else:
            body = "Reviewed and approved."

    if body_comments:
        body += "\n\n---\n\n"
        for c in body_comments:
            tag = "**[Blocking]**" if c['type'] == 'blocking' else "**[Non-blocking]**"
            body += f"{tag} {c['title']}\n\n{c['body']}\n\n"

    payload = {
        'commit_id': sidecar_sha,
        'event': event,
        'body': body,
        'comments': inline_comments
    }

    # Display summary
    inline_ids = [c['id'] for c in selected if c.get('path') and c.get('line')]
    print(f"\n  {org}/{repo} #{pr} (commit {sidecar_sha[:12]}):")
    print(f"    Review type: {event}")
    print(f"    Inline comments: {len(inline_comments)}  ({', '.join(inline_ids)})")
    print(f"    Body comments: {len(body_comments)}")

    if args.dry_run:
        print(f"\nPayload:\n{json.dumps(payload, indent=2)}")
        print("\nDry run — nothing posted.")
        return

    if not args.yes:
        print("\nUse --yes to post.")
        return

    # Write payload and post
    tmp_path = f"/tmp/claude-review-{repo}-{pr}.json"
    with open(tmp_path, 'w') as f:
        json.dump(payload, f)

    result = subprocess.run(
        ['gh', 'api', '--method', 'POST',
         f'/repos/{org}/{repo}/pulls/{pr}/reviews',
         '--input', tmp_path],
        capture_output=True, text=True
    )

    if os.path.exists(tmp_path):
        os.unlink(tmp_path)

    if result.returncode != 0:
        print(f"Error posting review: {result.stderr}", file=sys.stderr)
        sys.exit(1)

    response = json.loads(result.stdout)
    review_id = response.get('id', '?')
    html_url = response.get('html_url', f'https://github.com/{org}/{repo}/pull/{pr}')

    print(f"\nPosted: {org}/{repo} #{pr} — {event}, {len(inline_comments)} inline comments")
    print(f"  Review ID: {review_id}")
    print(f"  URL: {html_url}")


def cmd_repost(args):
    """Delete old review comments and re-post with corrected data."""
    with open(args.sidecar) as f:
        sidecar = json.load(f)

    org = resolve_org(args.org, sidecar)
    repo = args.repo or sidecar.get('repo')
    pr = args.pr or sidecar.get('pr')
    review_id = args.review_id

    if not repo or not pr or not review_id:
        print("Error: --repo, --pr, and --review-id required", file=sys.stderr)
        sys.exit(1)

    selected_ids = parse_selection(args.select, sidecar)
    selected = [c for c in sidecar['comments'] if c['id'] in selected_ids]
    inline = [c for c in selected if c.get('path') and c.get('line')]

    # Fetch existing comments for this review
    result = subprocess.run(
        ['gh', 'api',
         f'/repos/{org}/{repo}/pulls/{pr}/reviews/{review_id}/comments',
         '--jq', '.[].id'],
        capture_output=True, text=True
    )

    if result.returncode != 0:
        print(f"Error fetching review comments: {result.stderr}", file=sys.stderr)
        sys.exit(1)

    old_ids = [cid.strip() for cid in result.stdout.strip().splitlines() if cid.strip()]

    print(f"Found {len(old_ids)} existing comments to delete.")
    print(f"Will re-post {len(inline)} inline comments.")

    if args.dry_run:
        print("\nDry run — nothing changed.")
        return

    if not args.yes:
        print("\nUse --yes to proceed.")
        return

    # Delete old comments
    for cid in old_ids:
        r = subprocess.run(
            ['gh', 'api', '--method', 'DELETE',
             f'/repos/{org}/{repo}/pulls/comments/{cid}'],
            capture_output=True, text=True
        )
        status = "deleted" if r.returncode == 0 else f"FAILED: {r.stderr.strip()}"
        print(f"  {cid}: {status}")

    # Re-post as individual comments
    commit_id = sidecar['commit_id']
    for c in inline:
        payload = {
            'commit_id': commit_id,
            'path': c['path'],
            'line': c['line'],
            'side': c.get('side', 'RIGHT'),
            'body': c['body']
        }
        tmp = "/tmp/claude-repost-comment.json"
        with open(tmp, 'w') as f:
            json.dump(payload, f)

        r = subprocess.run(
            ['gh', 'api', '--method', 'POST',
             f'/repos/{org}/{repo}/pulls/{pr}/comments',
             '--input', tmp],
            capture_output=True, text=True
        )
        if os.path.exists(tmp):
            os.unlink(tmp)

        if r.returncode == 0:
            print(f"  Posted {c['id']} → line {c['line']} ({c['path']})")
        else:
            print(f"  FAILED {c['id']}: {r.stderr.strip()}", file=sys.stderr)

    print(f"\nRepost complete.")


# ============================================================================
# HELPERS
# ============================================================================

def parse_selection(select_str, sidecar):
    """Parse selection string like '1, B, C' into sidecar IDs."""
    if not select_str:
        return set()

    if select_str.strip().lower() == 'all':
        return {c['id'] for c in sidecar['comments']}

    ids = set()
    comment_ids = {c['id'] for c in sidecar['comments']}

    for token in select_str.split(','):
        token = token.strip()
        if not token:
            continue

        if token.isdigit():
            candidate = f"blocking-{token}"
        elif token.isalpha() and len(token) == 1:
            candidate = f"non-blocking-{token.upper()}"
        else:
            candidate = token

        if candidate in comment_ids:
            ids.add(candidate)
        else:
            print(f"Warning: '{token}' → '{candidate}' not found in sidecar, skipping",
                  file=sys.stderr)

    return ids


def gh_get_head_sha(org, repo, pr):
    """Get the current head SHA for a PR."""
    result = subprocess.run(
        ['gh', 'pr', 'view', str(pr), '--repo', f'{org}/{repo}',
         '--json', 'headRefOid', '--jq', '.headRefOid'],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"Warning: couldn't fetch current HEAD: {result.stderr}", file=sys.stderr)
        return None
    return result.stdout.strip()


# ============================================================================
# CLI
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Code review posting tool',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  # Verify/fix line numbers in sidecar against actual diff
  gh pr diff 123 --repo myorg/api | %(prog)s resolve-lines --sidecar review.json

  # Post selected findings (dry run first)
  %(prog)s post --sidecar review.json --select "1,B,C" --dry-run
  %(prog)s post --sidecar review.json --select "1,B,C" --yes

  # Delete and re-post comments from a prior review
  %(prog)s repost --review-id 3939855469 --sidecar review.json --select "1,B,C" --yes

Organization resolution (in order):
  --org flag > REVIEW_TOOL_ORG env var > sidecar 'org' field > current repo owner
""")
    parser.add_argument('--org', help='GitHub organization (default: from env/sidecar/repo)')
    subparsers = parser.add_subparsers(dest='command', required=True)

    # resolve-lines
    rl = subparsers.add_parser('resolve-lines',
                               help='Verify/correct sidecar line numbers against a diff (stdin)')
    rl.add_argument('--sidecar', required=True, help='Path to sidecar JSON file')
    rl.add_argument('--dry-run', action='store_true', help='Preview corrections without modifying')

    # post
    p = subparsers.add_parser('post', help='Post a GitHub PR review from a sidecar')
    p.add_argument('--sidecar', required=True, help='Path to sidecar JSON file')
    p.add_argument('--select', required=True,
                   help='Finding IDs: "1,B,C" or "all" or "approve"')
    p.add_argument('--repo', help='Repository name (default: from sidecar)')
    p.add_argument('--pr', type=int, help='PR number (default: from sidecar)')
    p.add_argument('--org', help='GitHub organization override')
    p.add_argument('--dry-run', action='store_true', help='Show payload without posting')
    p.add_argument('--yes', '-y', action='store_true', help='Post without confirmation')

    # repost
    rp = subparsers.add_parser('repost', help='Delete old comments and re-post')
    rp.add_argument('--sidecar', required=True, help='Path to sidecar JSON file')
    rp.add_argument('--select', required=True, help='Finding IDs to re-post')
    rp.add_argument('--review-id', required=True, help='GitHub review ID')
    rp.add_argument('--repo', help='Repository name (default: from sidecar)')
    rp.add_argument('--pr', type=int, help='PR number (default: from sidecar)')
    rp.add_argument('--org', help='GitHub organization override')
    rp.add_argument('--dry-run', action='store_true', help='Preview without changing')
    rp.add_argument('--yes', '-y', action='store_true', help='Proceed without confirmation')

    args = parser.parse_args()

    if args.command == 'resolve-lines':
        cmd_resolve_lines(args)
    elif args.command == 'post':
        cmd_post(args)
    elif args.command == 'repost':
        cmd_repost(args)


if __name__ == '__main__':
    main()
