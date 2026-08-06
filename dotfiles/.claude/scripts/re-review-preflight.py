#!/usr/bin/env python3
"""
re-review-preflight.py — emit a ReviewPlan JSON for /review:re-review-pr.

Pure-data: shells out to `gh`, computes structured analysis, prints JSON to stdout.
No posting, no agent dispatch.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor


def gh(cmd: list[str]) -> str:
    """Run a gh command and return stdout. Caller normalizes the argv."""
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"gh failed: {' '.join(cmd)}\n{result.stderr}")
    return result.stdout


def gh_json(cmd: list[str]):
    """Parse JSON from a `gh` command. Wraps json.JSONDecodeError with diagnostic
    context — gh occasionally returns exit-0 with non-JSON content (rate-limit
    warnings, transient HTML error pages), and the bare json.loads traceback
    propagated through ThreadPoolExecutor.result() is opaque about the cause."""
    raw = gh(cmd)
    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        raise RuntimeError(
            f"gh returned non-JSON output for: {' '.join(cmd)}\n"
            f"Parse error: {e}\n"
            f"Raw output (first 500 chars): {raw[:500]}"
        ) from e


def get_invoking_user() -> str:
    return gh(["gh", "api", "user", "--jq", ".login"]).strip().strip('"')


def get_pr_meta(repo: str, pr: int) -> dict:
    return gh_json([
        "gh", "pr", "view", "--repo", repo, str(pr),
        "--json", "title,body,headRefOid",
    ])


def get_reviews(repo: str, pr: int) -> list[dict]:
    return gh_json(["gh", "api", f"repos/{repo}/pulls/{pr}/reviews"])


def find_ref_review(reviews: list[dict], invoking_user: str) -> dict | None:
    """Return the most recent submitted review by the invoking user, or None."""
    mine = [r for r in reviews if r.get("user", {}).get("login") == invoking_user]
    if not mine:
        return None
    return max(mine, key=lambda r: r["submitted_at"])


def get_compare(repo: str, ref: str, head: str) -> dict:
    return gh_json(["gh", "api", f"repos/{repo}/compare/{ref}...{head}"])


def is_merge_commit(commit: dict) -> bool:
    return len(commit.get("parents", [])) > 1


def classify_short_circuit(compare: dict, ref: str, head: str) -> tuple[bool, str | None]:
    if ref == head:
        return True, "no new commits since last review"
    commits = compare.get("commits", [])
    if commits and all(is_merge_commit(c) for c in commits):
        return True, "merge commits only"
    if not compare.get("files"):
        return True, "empty delta"
    return False, None


def write_delta_diff(repo: str, pr: int, compare: dict) -> str:
    safe_repo = repo.replace("/", "-")
    path = f"/tmp/re-review-delta-{safe_repo}-{pr}.diff"
    parts = []
    for f in compare.get("files", []):
        filename = f["filename"]
        parts.append(f"diff --git a/{filename} b/{filename}")
        parts.append(f"--- a/{filename}")
        parts.append(f"+++ b/{filename}")
        if "patch" in f:
            parts.append(f["patch"])
    with open(path, "w") as fh:
        fh.write("\n".join(parts) + "\n")
    return path


# Note: `first: 100` is a hard limit. PRs with >100 review threads will have
# threads beyond position 100 absent from the lookup — those threads' comments
# default to is_resolved=false in classification (silently classified as `open`,
# never `addressed`). Pagination not implemented; acceptable for typical PR
# sizes. The misclassification fails toward "open" (more re-raises, not fewer),
# which is the safe direction.
GRAPHQL_REVIEW_THREADS = """
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          comments(first: 1) {
            nodes { id databaseId path line }
          }
        }
      }
    }
  }
}
""".strip()


def get_review_threads(repo: str, pr: int) -> tuple[list[dict], bool]:
    """Returns (threads, available). When available is False, caller should
    classify all comments as ambiguous with reason 'thread state unavailable'."""
    owner, name = repo.split("/", 1)
    cmd = [
        "gh", "api", "graphql",
        "-f", f"query={GRAPHQL_REVIEW_THREADS}",
        "-F", f"owner={owner}",
        "-F", f"repo={name}",
        "-F", f"pr={pr}",
    ]
    try:
        data = gh_json(cmd)
        return data["data"]["repository"]["pullRequest"]["reviewThreads"]["nodes"], True
    except Exception:
        return [], False


def get_inline_comments(repo: str, pr: int) -> list[dict]:
    """Return top-level inline comments only (replies are folded into their thread).

    GitHub's REST `pulls/<pr>/comments` returns every inline comment on the PR,
    including replies inside an existing thread (`in_reply_to_id` set). Replies
    don't represent new issues — they're discussion entries on a parent thread —
    so the classifier should not treat them as separate concerns. Filter them
    out here so each thread is classified once via its top-level comment.
    """
    all_comments = gh_json(["gh", "api", f"repos/{repo}/pulls/{pr}/comments"])
    return [c for c in all_comments if c.get("in_reply_to_id") is None]


def thread_lookup(threads: list[dict]) -> dict[int, bool]:
    """Map comment databaseId → isResolved for fast classification.

    NOTE: GraphQL's `databaseId` is the same numeric value as the REST API's
    `id` field on inline comments. We key on it so REST-side classification
    can do a direct lookup with comment["id"]. Do NOT change to GraphQL's
    string `id` field — that's a different identifier.
    """
    lookup = {}
    for t in threads:
        is_resolved = t.get("isResolved", False)
        for c in t.get("comments", {}).get("nodes", []):
            lookup[c["databaseId"]] = is_resolved
    return lookup


def files_touched(compare: dict) -> set[str]:
    return {f["filename"] for f in compare.get("files", [])}


def lines_modified(compare: dict, path: str) -> set[int]:
    """Parse hunks from compare.files[path].patch to extract added/modified line numbers (RIGHT side)."""
    modified = set()
    current = None  # None = not inside a valid hunk; set by successful @@ header parse
    for f in compare.get("files", []):
        if f["filename"] != path or "patch" not in f:
            continue
        for line in f["patch"].splitlines():
            if line.startswith("@@"):
                # Format: @@ -old_start,old_count +new_start,new_count @@
                try:
                    new_part = line.split("+")[1].split(" ")[0]
                    if "," in new_part:
                        start, count = new_part.split(",")
                        start, count = int(start), int(count)
                    else:
                        start, count = int(new_part), 1
                    current = start
                except (ValueError, IndexError):
                    current = None  # skip body lines until next valid hunk
                    continue
            elif current is None:
                continue
            elif line.startswith("+") and not line.startswith("+++"):
                modified.add(current)
                current += 1
            elif line.startswith(" "):
                current += 1
            # Deleted lines (`-` prefix) are intentionally not tracked: they
            # don't exist as numbered lines in the new-file view, so they
            # can't appear in `modified` (which is RIGHT-side line numbers).
            # The `line_was_deleted` predicate handles "comment anchor was on
            # a deleted line" via the REST API's null `line` field instead.
    return modified


def line_was_deleted(comment: dict) -> bool:
    """A REST inline comment whose `line` field is null/missing while `original_line`
    is present means GitHub couldn't anchor the comment in the new file — i.e., the
    line was deleted. This is the signal we use for the ambiguous classification."""
    return comment.get("line") is None and comment.get("original_line") is not None


def classify_comment(
    comment: dict,
    compare: dict,
    thread_state: dict[int, bool],
    threads_available: bool,
) -> tuple[str, str]:
    # When GraphQL is unavailable, every comment is ambiguous — we can't trust any
    # resolved-thread signal. Spec mandates this.
    if not threads_available:
        return "ambiguous", "thread state unavailable"

    path = comment["path"]
    is_resolved = thread_state.get(comment["id"], False)
    touched_files = files_touched(compare)

    # File no longer in delta tree → addressed if resolved, otherwise ambiguous
    # (the file removal is structurally similar to a deleted line — anchor gone)
    if path not in touched_files:
        if is_resolved:
            return "addressed", "thread resolved"
        return "ambiguous", "file not in delta; thread unresolved"

    # Line was deleted in the delta (file present but anchor lost). Symmetric
    # with the `path not in touched_files` case above: if the reviewer also
    # clicked "Resolve conversation" on the thread, treat that explicit signal
    # as authoritative and classify as addressed. Without a resolution signal,
    # stay ambiguous (we can't tell whether the deletion was an intentional
    # fix or unrelated refactoring).
    if line_was_deleted(comment):
        if is_resolved:
            return "addressed", "thread resolved + line deleted in delta"
        return "ambiguous", "line deleted in delta"

    line = comment.get("line") or comment.get("original_line")
    modified = lines_modified(compare, path)
    line_changed = line in modified

    if is_resolved and line_changed:
        return "addressed", "thread resolved + line modified in delta"
    if is_resolved:
        return "addressed", "thread resolved"
    if line_changed:
        return "addressed", "line modified in delta"
    return "open", "no signal of resolution"


def compute_review_plan(repo: str, pr: int) -> dict:
    # Phase A: launch all independent gh calls in parallel.
    # Stages 1, 2a, 2b, 4a, 4b have no dependencies on each other; only the
    # `compare` call (Phase B below) needs commit IDs from 2a + 2b.
    # Running them in parallel cuts wall-time from ~6 sequential gh calls
    # (~10-20s typical) to roughly the latency of the slowest single call.
    with ThreadPoolExecutor(max_workers=5) as ex:
        f_user = ex.submit(get_invoking_user)
        f_pr_meta = ex.submit(get_pr_meta, repo, pr)
        f_reviews = ex.submit(get_reviews, repo, pr)
        f_comments = ex.submit(get_inline_comments, repo, pr)
        f_threads = ex.submit(get_review_threads, repo, pr)

        # Block on the calls needed to determine mode
        invoking_user = f_user.result()
        pr_meta = f_pr_meta.result()
        head_commit = pr_meta["headRefOid"]
        reviews = f_reviews.result()
        ref_review = find_ref_review(reviews, invoking_user)

        base = {
            "invoking_user": invoking_user,
            "repo": repo,
            "pr": pr,
            "head_commit": head_commit,
        }

        if ref_review is None:
            return {
                **base,
                "mode": "full-fallback",
                "ref_commit": None,
                "ref_review_id": None,
                "ref_review_submitted_at": None,
                "short_circuit": False,
                "short_circuit_reason": "no prior review by invoking user",
            }

        ref_commit = ref_review["commit_id"]

        # Phase B: compare is sequential — depends on both commit IDs.
        compare = get_compare(repo, ref_commit, head_commit)

        # Force-push divergence → fall back to full review
        if compare.get("status") == "diverged":
            return {
                **base,
                "mode": "full-fallback",
                "ref_commit": ref_commit,
                "ref_review_id": ref_review["id"],
                "ref_review_submitted_at": ref_review["submitted_at"],
                "short_circuit": False,
                "short_circuit_reason": "ref commit diverged from head; falling back to full review",
            }

        short_circuit, sc_reason = classify_short_circuit(compare, ref_commit, head_commit)
        delta_diff_path = None if short_circuit else write_delta_diff(repo, pr, compare)

        # Block on the remaining Phase A results (already in-flight, likely done by now)
        raw_comments = f_comments.result()
        threads, threads_available = f_threads.result()
        thread_state = thread_lookup(threads)

        prior_comments = []
        for c in raw_comments:
            try:
                state, reason = classify_comment(c, compare, thread_state, threads_available)
            except Exception as e:
                state, reason = "ambiguous", f"classification failed: {e}"
            prior_comments.append({
                "id": c["id"],
                "path": c["path"],
                "line": c.get("line") or c.get("original_line"),
                "body": c.get("body", ""),
                "author": c.get("user", {}).get("login", ""),
                "submitted_at": c.get("created_at", ""),
                "state": state,
                "reason": reason,
            })

    return {
        **base,
        "mode": "delta",
        "ref_commit": ref_commit,
        "ref_review_id": ref_review["id"],
        "ref_review_submitted_at": ref_review["submitted_at"],
        "delta_diff_path": delta_diff_path,
        "short_circuit": short_circuit,
        "short_circuit_reason": sc_reason,
        "prior_comments": prior_comments,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--pr", required=True, type=int)
    args = parser.parse_args()
    plan = compute_review_plan(repo=args.repo, pr=args.pr)
    print(json.dumps(plan, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
