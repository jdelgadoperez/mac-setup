#!/usr/bin/env python3
"""Inventory Claude Code configuration for /config-audit.

Scans user scope (~/.claude, ~/.claude.json) and project scope (cwd by
default) and emits a single JSON document describing what exists: memory
files, settings, permissions, hooks, commands, skills, agents, plugins,
and MCP servers. Secret-looking values are redacted before they ever
reach the output, so the JSON is safe to embed in a report.

Stdlib only. Usage:
    python3 collect.py [--project DIR] [--out FILE] [--user-only|--project-only]
"""

import argparse
import json
import math
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

REDACTED = "«redacted»"

SECRET_KEY_RE = re.compile(
    r"(key|token|secret|passw|cookie|auth|credential|bearer|session)", re.I
)
# Long strings with high character variety are treated as secrets even
# when their key looks innocent.
CANDIDATE_SECRET_RE = re.compile(r"^[A-Za-z0-9+/=_\-.%]{20,}$")
# Secrets embedded inside longer strings (hook commands, CLI args):
# `--token=abc`, `api_key: abc`, and well-known credential prefixes.
INLINE_SECRET_RE = re.compile(
    r"((?:key|token|secret|passw\w*|cookie|auth|bearer|credential)\w*[=:]\s*)(\S+)",
    re.I,
)
KNOWN_PREFIX_RE = re.compile(
    r"\b(?:ghp_|gho_|ghs_|github_pat_|glpat-|sk-(?:ant-)?|xox[baprs]-|AKIA)[A-Za-z0-9_\-]{8,}"
)


def _entropy(s):
    counts = {}
    for ch in s:
        counts[ch] = counts.get(ch, 0) + 1
    return -sum((c / len(s)) * math.log2(c / len(s)) for c in counts.values())


def looks_secret(value):
    if not isinstance(value, str) or len(value) < 20:
        return False
    if value.startswith(("/", "~", "./")) or " " in value:
        return False
    if re.match(r"^https?://", value):
        return False
    return bool(CANDIDATE_SECRET_RE.match(value)) and _entropy(value) > 3.5


def strip_url_credentials(url):
    # user:pass@host and secret-looking query values
    url = re.sub(r"//[^/@]+@", "//" + REDACTED + "@", url)
    return re.sub(
        r"([?&][^=&]*(?:key|token|secret|auth|sig|cred)[^=&]*=)[^&]+",
        r"\1" + REDACTED,
        url,
        flags=re.I,
    )


def redact(value, key=""):
    """Recursively redact secret-looking data. Structure is preserved."""
    if isinstance(value, dict):
        return {k: redact(v, k) for k, v in value.items()}
    if isinstance(value, list):
        return [redact(v, key) for v in value]
    if isinstance(value, str):
        if SECRET_KEY_RE.search(key) or looks_secret(value):
            return REDACTED
        if re.match(r"^https?://", value):
            value = strip_url_credentials(value)
        value = INLINE_SECRET_RE.sub(r"\1" + REDACTED, value)
        value = KNOWN_PREFIX_RE.sub(REDACTED, value)
    return value


def read_text(path, limit=200_000):
    try:
        return path.read_text(encoding="utf-8", errors="replace")[:limit]
    except OSError:
        return None


def file_stats(path):
    if not path.exists():
        return {"path": str(path), "exists": False}
    text = read_text(path) or ""
    return {
        "path": str(path),
        "exists": True,
        "bytes": path.stat().st_size,
        "lines": text.count("\n") + 1,
        "words": len(text.split()),
    }


def parse_frontmatter(path):
    """Minimal YAML-ish frontmatter parser: top-level `key: value` pairs."""
    text = read_text(path, limit=20_000)
    if not text or not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    fields = {}
    lines = text[3:end].splitlines()
    index = 0
    while index < len(lines):
        match = re.match(r"^([A-Za-z_-]+):\s*(.*)$", lines[index])
        index += 1
        if not match:
            continue
        key = match.group(1).lower()
        value = match.group(2).strip()

        # A bare key, or an explicit `|`/`>` block indicator, means the value
        # continues on the following more-indented lines.
        if value in ("", "|", ">", "|-", ">-", "|+", ">+"):
            continuation = []
            while index < len(lines):
                following = lines[index]
                if following.strip() and not following[:1].isspace():
                    break
                if following.strip():
                    continuation.append(following.strip())
                index += 1
            value = " ".join(continuation)

        fields[key] = value.strip().strip("\"'")
    return fields


def broken_link_entry(path, directory, kind, name=None):
    """A dangling symlink is inventory too — record it instead of crashing.

    `name` lets the caller supply the display name it would otherwise derive
    from frontmatter — skills pass their directory name, so a broken skill
    reads as `ship` rather than `ship/SKILL`.
    """
    return {
        "name": name or path.relative_to(directory).with_suffix("").as_posix(),
        "kind": kind,
        "path": str(path),
        "bytes": 0,
        "description": "",
        "frontmatter_keys": [],
        "has_description": False,
        "broken_symlink": True,
        "symlink_target": os.readlink(path) if path.is_symlink() else None,
    }


def inventory_markdown_dir(directory, kind):
    """Commands and agents: one .md per entry (possibly nested)."""
    items = []
    if not directory.is_dir():
        return items
    for md in sorted(directory.rglob("*.md")):
        if not md.exists():
            items.append(broken_link_entry(md, directory, kind))
            continue
        fm = parse_frontmatter(md)
        items.append(
            {
                "name": fm.get("name") or md.relative_to(directory).with_suffix("").as_posix(),
                "kind": kind,
                "path": str(md),
                "bytes": md.stat().st_size,
                "description": fm.get("description", ""),
                "frontmatter_keys": sorted(fm.keys()),
                "has_description": bool(fm.get("description")),
            }
        )
    return items


def inventory_skills(directory):
    items = []
    if not directory.is_dir():
        return items
    for skill_md in sorted(directory.glob("*/SKILL.md")):
        skill_dir = skill_md.parent
        if not skill_md.exists():
            items.append(broken_link_entry(skill_md, directory, "skill", name=skill_dir.name))
            continue
        fm = parse_frontmatter(skill_md)
        files = [p for p in skill_dir.rglob("*") if p.is_file()]
        items.append(
            {
                "name": fm.get("name") or skill_dir.name,
                "kind": "skill",
                "path": str(skill_dir),
                "bytes": sum(p.stat().st_size for p in files),
                "description": fm.get("description", ""),
                "has_description": bool(fm.get("description")),
                "file_count": len(files),
                "has_scripts": any("scripts" in p.parts[len(skill_dir.parts):] for p in files),
            }
        )
    return items


def load_json(path):
    text = read_text(path, limit=2_000_000)
    if text is None:
        return None, None
    try:
        return json.loads(text), None
    except ValueError as exc:
        return None, str(exc)


def summarize_settings(path):
    out = file_stats(path)
    if not out["exists"]:
        return out
    data, err = load_json(path)
    if err:
        out["parse_error"] = err
        return out
    perms = data.get("permissions", {}) if isinstance(data, dict) else {}
    hooks = data.get("hooks", {}) if isinstance(data, dict) else {}
    out.update(
        {
            "keys": sorted(data.keys()) if isinstance(data, dict) else [],
            "permissions": {
                mode: perms.get(mode, [])
                for mode in ("allow", "deny", "ask")
                if perms.get(mode)
            },
            "hooks": {
                event: len(entries) if isinstance(entries, list) else 1
                for event, entries in hooks.items()
            },
            "hook_details": redact(hooks),
            "env_keys": sorted(data.get("env", {}).keys())
            if isinstance(data.get("env"), dict)
            else [],
            "model": data.get("model"),
            "redacted_settings": redact(
                {k: v for k, v in data.items() if k not in ("permissions", "hooks")}
            )
            if isinstance(data, dict)
            else None,
        }
    )
    return out


def summarize_mcp(config, source):
    servers = []
    for name, spec in (config or {}).items():
        if not isinstance(spec, dict):
            continue
        servers.append(
            {
                "name": name,
                "source": source,
                "transport": spec.get("type")
                or ("http/sse" if spec.get("url") else "stdio"),
                "command": spec.get("command"),
                "args": redact(spec.get("args", []), "args"),
                "url": strip_url_credentials(spec["url"]) if spec.get("url") else None,
                "env_keys": sorted(spec.get("env", {}).keys())
                if isinstance(spec.get("env"), dict)
                else [],
                "has_headers": bool(spec.get("headers")),
            }
        )
    return servers


def scan_user_scope(home):
    root = home / ".claude"
    scope = {
        "root": str(root),
        "exists": root.is_dir(),
        "memory": file_stats(root / "CLAUDE.md"),
        "settings": summarize_settings(root / "settings.json"),
        "settings_local": summarize_settings(root / "settings.local.json"),
        "keybindings": file_stats(root / "keybindings.json"),
        "commands": inventory_markdown_dir(root / "commands", "command"),
        "agents": inventory_markdown_dir(root / "agents", "agent"),
        "skills": inventory_skills(root / "skills"),
        "plugins": sorted(
            p.name for p in (root / "plugins").iterdir() if p.is_dir()
        )
        if (root / "plugins").is_dir()
        else [],
    }
    claude_json = home / ".claude.json"
    scope["claude_json"] = {"path": str(claude_json), "exists": claude_json.exists()}
    if claude_json.exists():
        data, err = load_json(claude_json)
        if err:
            scope["claude_json"]["parse_error"] = err
        elif isinstance(data, dict):
            scope["claude_json"]["mcp_servers"] = summarize_mcp(
                data.get("mcpServers"), "~/.claude.json"
            )
            projects = data.get("projects", {})
            scope["claude_json"]["project_count"] = (
                len(projects) if isinstance(projects, dict) else 0
            )
            scope["claude_json"]["project_mcp"] = {
                proj: summarize_mcp(cfg.get("mcpServers"), proj)
                for proj, cfg in projects.items()
                if isinstance(cfg, dict) and cfg.get("mcpServers")
            } if isinstance(projects, dict) else {}
    return scope


def scan_project_scope(project):
    dot = project / ".claude"
    scope = {
        "root": str(project),
        "memory": file_stats(project / "CLAUDE.md"),
        "memory_local": file_stats(project / "CLAUDE.local.md"),
        "settings": summarize_settings(dot / "settings.json"),
        "settings_local": summarize_settings(dot / "settings.local.json"),
        "commands": inventory_markdown_dir(dot / "commands", "command"),
        "agents": inventory_markdown_dir(dot / "agents", "agent"),
        "skills": inventory_skills(dot / "skills"),
        "mcp_json": file_stats(project / ".mcp.json"),
        "is_git_repo": (project / ".git").exists(),
        # Run from $HOME, "project scope" resolves to the user's own config and
        # duplicates the user scope. Flag it so the report collapses the two
        # rather than presenting the same files as a second, distinct scope.
        "mirrors_user_scope": project.resolve() == Path.home().resolve(),
    }
    if scope["mcp_json"]["exists"]:
        data, err = load_json(project / ".mcp.json")
        if err:
            scope["mcp_json"]["parse_error"] = err
        elif isinstance(data, dict):
            scope["mcp_servers"] = summarize_mcp(data.get("mcpServers"), ".mcp.json")
    gitignore = read_text(project / ".gitignore") or ""
    scope["gitignore_covers"] = {
        "settings_local": "settings.local.json" in gitignore,
        "claude_local_md": "CLAUDE.local.md" in gitignore,
        "env": ".env" in gitignore,
    }
    return scope


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default=os.getcwd(), help="project dir to audit")
    parser.add_argument("--out", help="write JSON here instead of stdout")
    parser.add_argument("--user-only", action="store_true")
    parser.add_argument("--project-only", action="store_true")
    args = parser.parse_args()

    result = {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "platform": sys.platform,
        "home": str(Path.home()),
        "scopes": {},
    }
    if not args.project_only:
        result["scopes"]["user"] = scan_user_scope(Path.home())
    if not args.user_only:
        result["scopes"]["project"] = scan_project_scope(Path(args.project).resolve())

    payload = json.dumps(result, indent=2, ensure_ascii=False)
    if args.out:
        Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        Path(args.out).write_text(payload, encoding="utf-8")
        print(f"wrote {args.out} ({len(payload)} bytes)")
    else:
        print(payload)


if __name__ == "__main__":
    main()
