#!/usr/bin/env python3
"""Test battery for outbound-path-guard.py. Run: python3 outbound-path-guard.test.py"""
import json
import subprocess
import sys
from pathlib import Path

DETECTOR = str(Path(__file__).with_name("outbound-path-guard.py"))

HOME = "/Users/jessdelgadoperez"
DRATA = f"{HOME}/projects/drata"

CASES = [
    # (desc, payload, expected_rc)
    ("BLOCK drata _reports path in review body",
     {"tool_name": "Bash", "tool_input": {"command":
      f'gh pr review 123 --request-changes --body "see {DRATA}/_reports/temporal/x.md"'}}, 2),
    ("BLOCK home path in slack send",
     {"tool_name": "mcp__claude_ai_Slack__slack_send_message", "tool_input":
      {"channel": "C1", "text": f"full working in {HOME}/foo/bar.md"}}, 2),
    ("BLOCK ~ expansion in notion page",
     {"tool_name": "mcp__claude_ai_Notion__notion-create-pages", "tool_input":
      {"pages": [{"content": "artifact at ~/projects/drata/x.md"}]}}, 2),
    ("BLOCK temp path in gh api comment",
     {"tool_name": "Bash", "tool_input": {"command":
      'gh api repos/drata/api/issues/1/comments -f body="log in /private/tmp/claude/run.log"'}}, 2),
    ("BLOCK drata/.llm absolute path",
     {"tool_name": "Bash", "tool_input": {"command":
      f'gh pr comment 5 --body "plan: {DRATA}/.llm/plans/p.md"'}}, 2),
    ("BLOCK $TMPDIR path in linear comment",
     {"tool_name": "mcp__claude_ai_Linear__save_comment", "tool_input":
      {"body": "output at $TMPDIR/run/out.txt"}}, 2),
    ("BLOCK other-user home path",
     {"tool_name": "mcp__claude_ai_Slack__slack_send_message", "tool_input":
      {"text": "on the box: /Users/someoneelse/secret/creds"}}, 2),
    ("FAIL-CLOSED gh api --body-file",
     {"tool_name": "Bash", "tool_input": {"command":
      'gh pr review 12 --request-changes --body-file /tmp/x'}}, 3),
    ("FAIL-CLOSED gh api -F body=@file",
     {"tool_name": "Bash", "tool_input": {"command":
      'gh api repos/drata/api/issues/1/comments -F body=@/tmp/b.md'}}, 3),
    ("ALLOW bare relative .llm path in prose",
     {"tool_name": "mcp__claude_ai_Slack__slack_send_message", "tool_input":
      {"text": "the plan is in .llm/plans/foo.md"}}, 0),
    ("ALLOW bare _reports dir name",
     {"tool_name": "mcp__claude_ai_Slack__slack_send_message", "tool_input":
      {"text": "dropped it in _reports/temporal/"}}, 0),
    ("ALLOW repo ref drata/api in prose",
     {"tool_name": "Bash", "tool_input": {"command":
      'gh pr comment 1 --body "fixed in drata/api web layer"'}}, 0),
    ("ALLOW local cat of home path (not a post)",
     {"tool_name": "Bash", "tool_input": {"command":
      f'cat {DRATA}/foo.md'}}, 0),
    ("ALLOW gh pr view read no body",
     {"tool_name": "Bash", "tool_input": {"command":
      'gh pr view 123 --json title'}}, 0),
    ("ALLOW unrelated tool (Read)",
     {"tool_name": "Read", "tool_input": {"file_path": f"{HOME}/x.md"}}, 0),
    ("ALLOW linear-cli run by its quoted plugin-cache path (read call)",
     {"tool_name": "Bash", "tool_input": {"command":
      f'"{HOME}/.claude/plugins/cache/ai-plugins/linear/1.1.3/install/linear-cli" call list_teams \'{{"limit":1}}\''}}, 0),
    ("ALLOW linear-cli run by ~ path after another command",
     {"tool_name": "Bash", "tool_input": {"command":
      'true && ~/.claude/plugins/cache/ai-plugins/linear/1.1.3/install/linear-cli call list_issues \'{}\''}}, 0),
    ("ALLOW linear-cli run by quoted path on a later line of a script",
     {"tool_name": "Bash", "tool_input": {"command":
      f'echo start\n"{HOME}/.claude/plugins/cache/ai-plugins/linear/1.1.3/install/linear-cli" call save_issue \'{{"team":"INT","title":"t"}}\''}}, 0),
    ("BLOCK multi-line script that stages the body in a temp file",
     {"tool_name": "Bash", "tool_input": {"command":
      f'cat > /tmp/d.md <<\'EOF\'\nbody\nEOF\n"{HOME}/.claude/plugins/cache/ai-plugins/linear/1.1.3/install/linear-cli" call save_issue "$(cat /tmp/d.md)"'}}, 2),
    ("BLOCK linear-cli run by absolute path with a home path in the body",
     {"tool_name": "Bash", "tool_input": {"command":
      f'{HOME}/.claude/plugins/cache/ai-plugins/linear/1.1.3/install/linear-cli call save_comment \'{{"body":"see {HOME}/r.md"}}\''}}, 2),
    ("BLOCK bare linear-cli with a temp path in the description",
     {"tool_name": "Bash", "tool_input": {"command":
      'linear-cli call save_issue \'{"description":"/private/tmp/x.log"}\''}}, 2),
    ("BLOCK a tool path inside the body, not in command position",
     {"tool_name": "Bash", "tool_input": {"command":
      'gh pr comment 1 --body "run /Users/someoneelse/bin/gh"'}}, 2),
    ("ALLOW linear-cli body that mentions the file flags in its text",
     {"tool_name": "Bash", "tool_input": {"command":
      'linear-cli call save_comment \'{"issueId":"INT-1","body":"the agent requires `gh pr edit --body-file`, and --input is refused"}\''}}, 0),
    ("ALLOW gh pr comment quoting the guard's own fail-closed message",
     {"tool_name": "Bash", "tool_input": {"command":
      'gh pr comment 1 --body "it said: content is in a --body-file/--input/@file, which can\'t be scanned"'}}, 0),
    ("FAIL-CLOSED gh api -F with a quoted @file value",
     {"tool_name": "Bash", "tool_input": {"command":
      "gh api repos/drata/api/issues/1/comments -F 'body=@/tmp/b.md'"}}, 3),
    ("FAIL-CLOSED gh api with -F joined to its @file value",
     {"tool_name": "Bash", "tool_input": {"command":
      'gh api repos/drata/api/issues/1/comments -Fbody=@b.md'}}, 3),
    ("FAIL-CLOSED gh pr edit --body-file=<file> form",
     {"tool_name": "Bash", "tool_input": {"command":
      'gh pr edit 1 --body-file=b.md'}}, 3),
    ("FAIL-CLOSED unparseable command that names a body file",
     {"tool_name": "Bash", "tool_input": {"command":
      'gh pr review 1 --body-file b.md --body "unbalanced'}}, 3),
    ("ALLOW linear-cli run by a quoted path with a space in it (read call)",
     {"tool_name": "Bash", "tool_input": {"command":
      f'"{HOME}/Library/Application Support/Claude/plugins/linear/install/linear-cli" call list_comments \'{{"issueId":"INT-736","limit":100,"orderBy":"createdAt"}}\''}}, 0),
    ("ALLOW linear-cli run by a path with a backslash-escaped space",
     {"tool_name": "Bash", "tool_input": {"command":
      f'{HOME}/Library/Application\\ Support/Claude/plugins/linear/install/linear-cli call list_teams \'{{}}\''}}, 0),
    ("BLOCK linear-cli run by a spaced path with a home path in the body",
     {"tool_name": "Bash", "tool_input": {"command":
      f'"{HOME}/Library/Application Support/Claude/plugins/linear/install/linear-cli" call save_comment \'{{"body":"see {HOME}/r.md"}}\''}}, 2),
    ("BLOCK a quoted spaced home path in a body that only ends in a tool name",
     {"tool_name": "Bash", "tool_input": {"command":
      f'gh pr comment 1 --body "{HOME}/Library/Application Support/x/gh"'}}, 2),
    ("ALLOW slack clean message",
     {"tool_name": "mcp__claude_ai_Slack__slack_send_message", "tool_input":
      {"text": "the readiness report is attached"}}, 0),
]


def main():
    failures = 0
    for desc, payload, expected in CASES:
        proc = subprocess.run(
            [sys.executable, DETECTOR],
            input=json.dumps(payload), capture_output=True, text=True)
        if proc.returncode == expected:
            print(f"PASS [{proc.returncode}] {desc}")
        else:
            failures += 1
            print(f"FAIL exp={expected} got={proc.returncode} :: {desc}")
            if proc.stdout.strip():
                print(f"       out: {proc.stdout.strip()}")
    print(f"\n{len(CASES)-failures}/{len(CASES)} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
