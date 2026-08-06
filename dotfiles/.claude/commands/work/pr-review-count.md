---
name: pr-review-count
description: "Count PRs reviewed in a timeframe (day, week, month) with breakdown by repo and PR list."
allowed-tools: Bash
argument-hint: <day|week|month> [date]
---

# PR Review Count

Count GitHub PRs you reviewed in a timeframe using the GitHub Events API.

## Usage

```
/work:pr-review-count [timeframe] [anchor]
```

## Parameters

- `timeframe` (optional, default: `week`): `day`, `week`, or `month`
- `anchor` (optional): a date within the desired window
  - `day`: `YYYY-MM-DD` (default: today)
  - `week`: any `YYYY-MM-DD` within the week (default: current week)
  - `month`: `YYYY-MM` (default: current month)

## Process

### Step 1: Resolve date range

Run inline Python to compute `range_start`, `range_end`, and `label` from the arguments:

```python
import sys
from datetime import date, timedelta

timeframe = sys.argv[1] if sys.argv[1] else "week"
anchor_arg = sys.argv[2]
today = date.fromisoformat(sys.argv[3])

if timeframe == "day":
    target = date.fromisoformat(anchor_arg) if anchor_arg else today
    start, end = target, target
    label = f"Day: {target}"
elif timeframe == "week":
    anchor = date.fromisoformat(anchor_arg) if anchor_arg else today
    monday = anchor - timedelta(days=anchor.weekday())
    end = min(monday + timedelta(days=6), today)
    start = monday
    label = f"Week: {monday} – {end}"
elif timeframe == "month":
    if anchor_arg:
        year, month = int(anchor_arg[:4]), int(anchor_arg[5:7])
    else:
        year, month = today.year, today.month
    start = date(year, month, 1)
    next_month = date(year + (month // 12), (month % 12) + 1, 1)
    end = min(next_month - timedelta(days=1), today)
    label = f"Month: {year}-{month:02d} ({start} – {end})"

print(f"{start}|{end}|{label}")
```

### Step 2: Fetch GitHub Events

Resolve the authenticated user and fetch up to 3 pages of events (300 total):

```bash
gh_login=$(gh api user --jq '.login')
for page in 1 2 3; do
  gh api "/users/${gh_login}/events?per_page=100&page=${page}"
done
```

### Step 3: Filter and deduplicate

Filter `PullRequestReviewEvent` within the date range, deduplicating by `(owner_repo, pr_number)` keeping the most recent. The org is extracted dynamically from the event — no hardcoding:

```python
import sys, json
from datetime import datetime

# range_start, range_end, events from previous steps
seen = {}
for event in events:
    if event.get('type') != 'PullRequestReviewEvent':
        continue
    created_utc = event.get('created_at', '')
    if not created_utc:
        continue
    dt_local = datetime.fromisoformat(created_utc.replace('Z', '+00:00')).astimezone()
    event_date = dt_local.date().isoformat()
    if event_date < range_start or event_date > range_end:
        continue

    owner_repo = event['repo']['name']        # e.g. "myorg/myrepo" — no hardcoding
    repo_name = owner_repo.split('/')[-1]     # e.g. "myrepo"
    pr = event['payload']['pull_request']
    pr_number = pr['number']
    pr_url = pr.get('html_url', f"https://github.com/{owner_repo}/pull/{pr_number}")

    key = (owner_repo, pr_number)
    if key not in seen:
        seen[key] = {
            'owner_repo': owner_repo,
            'repo': repo_name,
            'number': pr_number,
            'url': pr_url,
            'title': None,
        }

result = sorted(seen.values(), key=lambda x: (x['repo'], x['number']))
```

### Step 4: Fetch PR titles

For each unique PR, fetch its title using the `owner_repo` from the event data:

```bash
gh api "/repos/${owner_repo}/pulls/${number}" --jq '.title'
```

Run these in parallel for speed, then enrich the result list with the fetched titles.

### Step 5: Display results

From the enriched list, produce:

**Overall summary** — one line:
> Reviewed **N** PRs · {label}

**By repository** — table sorted descending by count:

| Repository | Count |
|------------|-------|
| repo-name  | N     |

**PR list** — sorted by repo then number, with clickable links:

| PR | Title |
|----|-------|
| [repo#123](url) | title |

### Formatting rules

- All PR references must be hyperlinked: `[repo#number](url)`
- Emit each table as a separate block so they render correctly
- If the result is empty, say so and note the GitHub Events API only retains ~90 days of activity
- Note at the bottom: *uses GitHub Events API with local-timezone date conversion — PRs reviewed near window edges may be off by ~30 min*
