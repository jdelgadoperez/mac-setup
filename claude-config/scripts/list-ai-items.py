#!/usr/bin/env python3
"""List available Claude agents, skills, and commands from the terminal."""

import argparse
import json
import os
import re
import sys
from pathlib import Path

CLAUDE_DIR = Path.home() / ".claude"
PLUGINS_CACHE = CLAUDE_DIR / "plugins" / "cache"
INSTALLED_PLUGINS = CLAUDE_DIR / "plugins" / "installed_plugins.json"

BOLD   = "\033[1m"
DIM    = "\033[2m"
YELLOW = "\033[1;33m"
CYAN   = "\033[0;36m"
GREEN  = "\033[0;32m"
NC     = "\033[0m"

DESC_MAX = 100


def frontmatter_field(path: Path, field: str) -> str:
    try:
        content = path.read_text(errors="replace")
    except OSError:
        return ""
    m = re.match(r"^---\s*\n(.*?)\n---", content, re.DOTALL)
    if not m:
        return ""
    block = m.group(1)
    match = re.search(rf"^{re.escape(field)}:\s*(.+)$", block, re.MULTILINE)
    if not match:
        return ""
    val = match.group(1).strip().strip('"').strip("'")
    return val[:DESC_MAX] + "..." if len(val) > DESC_MAX else val


def collect_from_dir(base: Path, source: str, filter_type: str) -> list[dict]:
    items = []

    if not filter_type or filter_type == "agents":
        agents_dir = base / "agents"
        if agents_dir.is_dir():
            for f in sorted(agents_dir.glob("*.md")):
                name = frontmatter_field(f, "name") or f.stem
                desc = frontmatter_field(f, "description")
                items.append({"type": "agent", "name": name, "desc": desc, "source": source})

    if not filter_type or filter_type == "skills":
        skills_dir = base / "skills"
        if skills_dir.is_dir():
            for skill_dir in sorted(skills_dir.iterdir()):
                if not skill_dir.is_dir():
                    continue
                skill_file = skill_dir / "SKILL.md"
                if not skill_file.exists():
                    continue
                name = frontmatter_field(skill_file, "name") or skill_dir.name
                desc = frontmatter_field(skill_file, "description")
                items.append({"type": "skill", "name": name, "desc": desc, "source": source})

    if not filter_type or filter_type == "commands":
        commands_dir = base / "commands"
        if commands_dir.is_dir():
            for f in sorted(commands_dir.rglob("*.md")):
                rel = f.relative_to(commands_dir)
                parts = rel.parts
                if len(parts) == 1:
                    cmd_name = rel.stem
                else:
                    cmd_name = ":".join(list(parts[:-1]) + [parts[-1].removesuffix(".md")])
                desc = frontmatter_field(f, "description")
                items.append({"type": "command", "name": cmd_name, "desc": desc, "source": source})

    return items


def installed_plugin_paths() -> list[tuple[str, Path]]:
    """Yield (source_label, install_path) for each installed plugin."""
    if not INSTALLED_PLUGINS.exists():
        return []
    try:
        data = json.loads(INSTALLED_PLUGINS.read_text())
    except (json.JSONDecodeError, OSError):
        return []

    results = []
    for entries in data.get("plugins", {}).values():
        for entry in entries:
            install_path = entry.get("installPath")
            if not install_path:
                continue
            p = Path(install_path)
            if not p.is_dir():
                continue
            # Derive label from path relative to plugins cache
            try:
                rel = p.relative_to(PLUGINS_CACHE)
                label = "/".join(rel.parts[:2])  # marketplace/plugin
            except ValueError:
                label = p.name
            results.append((label, p))
    return results


def main():
    parser = argparse.ArgumentParser(description="List Claude agents, skills, and commands")
    parser.add_argument("--type", choices=["agents", "skills", "commands"], dest="filter_type",
                        help="Limit output to one type")
    parser.add_argument("--grep", metavar="PATTERN", help="Filter by name or description (case-insensitive)")
    parser.add_argument("--json", action="store_true", dest="json_output", help="Output JSON")
    args = parser.parse_args()

    items: list[dict] = []

    # Local
    items.extend(collect_from_dir(CLAUDE_DIR, "local", args.filter_type))

    # Plugins
    seen_paths: set[Path] = set()
    for label, path in installed_plugin_paths():
        if path in seen_paths:
            continue
        seen_paths.add(path)
        items.extend(collect_from_dir(path, label, args.filter_type))

    # Deduplicate: same type+name, prefer local over plugin
    seen: dict[tuple, dict] = {}
    for item in items:
        key = (item["type"], item["name"])
        if key not in seen or item["source"] == "local":
            seen[key] = item
    items = sorted(seen.values(), key=lambda x: (x["type"], x["name"].lower()))

    # Grep filter
    if args.grep:
        pattern = re.compile(re.escape(args.grep), re.IGNORECASE)
        items = [i for i in items if pattern.search(i["name"]) or pattern.search(i["desc"])]

    if args.json_output:
        print(json.dumps(
            [{"type": i["type"], "name": i["name"], "description": i["desc"], "source": i["source"]}
             for i in items],
            indent=2
        ))
        return

    if not items:
        print("No items found.")
        return

    HEADERS = {
        "agent":   f"{BOLD}{YELLOW}AGENTS{NC}",
        "skill":   f"{BOLD}{CYAN}SKILLS{NC}",
        "command": f"{BOLD}{GREEN}COMMANDS{NC}",
    }

    current_type = None
    for item in items:
        if item["type"] != current_type:
            if current_type is not None:
                print()
            print(HEADERS.get(item["type"], item["type"].upper()))
            print("─" * 64)
            current_type = item["type"]

        source_tag = f"  {DIM}[{item['source']}]{NC}" if item["source"] != "local" else ""
        print(f"  {BOLD}{item['name']:<40}{NC}{source_tag}")
        if item["desc"]:
            print(f"  {DIM}{item['desc']}{NC}")
        print()


if __name__ == "__main__":
    main()
