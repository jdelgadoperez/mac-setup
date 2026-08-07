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
import hashlib
import json
import math
import os
import re
import shutil
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


def _has_skill_frontmatter(fm):
    """A stray .md carries skill frontmatter if it declares name and/or description."""
    return bool(fm.get("name") or fm.get("description"))


def _file_hash(path):
    """sha256 of file bytes, or None if unreadable (covers broken symlinks too)."""
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return None


def inventory_skills(directory):
    """Skills are enumerated by directory, not by globbing SKILL.md.

    A skill dir with no root SKILL.md never loads in Claude Code even if it
    contains a plausible-looking markdown file elsewhere inside it -- globbing
    `*/SKILL.md` silently drops exactly that case from the inventory. See
    DESIGN-NOTES.md for the review-prs/ case this was built to catch.
    """
    items = []
    if not directory.is_dir():
        return items
    for skill_dir in sorted(p for p in directory.iterdir() if p.is_dir()):
        skill_md = skill_dir / "SKILL.md"
        loads = skill_md.is_file()

        if skill_md.is_symlink() and not skill_md.exists():
            entry = broken_link_entry(skill_md, directory, "skill", name=skill_dir.name)
            entry["loads"] = False
            entry["stray_frontmatter_files"] = []
            entry["self_duplicate_files"] = []
            items.append(entry)
            continue

        # Every markdown file in the skill dir (any depth), guarding broken
        # symlinks the same way the rest of the collector does: record, don't
        # crash on them.
        md_files = sorted(
            p for p in skill_dir.rglob("*.md") if p.is_file() or p.is_symlink()
        )

        fm = parse_frontmatter(skill_md) if loads else {}
        stray_frontmatter_files = []
        best_stray_fm = {}
        for md in md_files:
            if md == skill_md:
                continue
            if not md.is_file():  # broken symlink -- can't read frontmatter
                continue
            stray_fm = parse_frontmatter(md)
            if _has_skill_frontmatter(stray_fm):
                rel = md.relative_to(skill_dir).as_posix()
                stray_frontmatter_files.append(rel)
                if not loads and not best_stray_fm:
                    best_stray_fm = stray_fm

        # Byte-identical .md files within this skill dir, grouped.
        hashes = {}
        for md in md_files:
            if not md.is_file():
                continue
            digest = _file_hash(md)
            if digest is None:
                continue
            hashes.setdefault(digest, []).append(md.relative_to(skill_dir).as_posix())
        self_duplicate_files = [
            sorted(paths) for paths in hashes.values() if len(paths) >= 2
        ]

        files = [p for p in skill_dir.rglob("*") if p.is_file()]
        name = fm.get("name") or best_stray_fm.get("name") or skill_dir.name
        description = fm.get("description") or best_stray_fm.get("description", "")
        items.append(
            {
                "name": name,
                "kind": "skill",
                "path": str(skill_dir),
                "bytes": sum(p.stat().st_size for p in files),
                "description": description,
                "has_description": bool(description),
                "file_count": len(files),
                "has_scripts": any("scripts" in p.parts[len(skill_dir.parts):] for p in files),
                "loads": loads,
                "stray_frontmatter_files": sorted(stray_frontmatter_files),
                "self_duplicate_files": sorted(self_duplicate_files),
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


# --- permission reachability -------------------------------------------------
#
# A deny rule only holds if the capability it names cannot be reached another
# way on THIS machine. Two rules govern everything below:
#
#   1. Resolve, never execute. shutil.which() is a PATH lookup plus os.access;
#      it does not run the binary it finds. Nothing in this section may call
#      subprocess/os.system/exec. A security auditor that executes what it
#      discovers is a worse problem than the gaps it reports.
#   2. No hardcoded alternates table. Which binaries exist differs per machine,
#      so a baked-in list produces false positives on one host and misses real
#      gaps on another. Everything is derived from the rules themselves plus a
#      live PATH probe, and only installed binaries are ever reported.

RULE_RE = re.compile(r"^(?P<surface>[A-Za-z]+)\((?P<body>.*)\)$", re.DOTALL)

# Deny bodies mentioning these are path-scoped (the right shape) rather than
# flag-scoped (the leaky shape). Used only to suppress false positives.
SENSITIVE_PATH_RE = re.compile(
    r"(\.env|\.pem|\.key|\.ssh|credential|secret|\.aws|id_rsa|id_ed25519|"
    r"\.p12|\.pfx|\.netrc|\.npmrc|token)",
    re.IGNORECASE,
)

# This IS a fixed list, and that is defensible where the earlier "equivalent
# tools" table was not. These are POSIX text utilities whose defining purpose is
# emitting file contents -- that does not vary by machine or by who installed
# what. The list only ever filters rules the user already granted, and each hit
# is still confirmed against PATH, so a name here proves nothing on its own.
FILE_READING_BINARIES = frozenset({
    "awk", "cat", "col", "cut", "diff", "egrep", "fgrep", "fold", "grep",
    "head", "jq", "less", "more", "nl", "od", "paste", "rev", "rg", "sed",
    "sort", "strings", "tac", "tail", "tr", "uniq", "wc", "xxd", "yq",
})

# NOT a fixed recognized-reader binary list -- deliberately removed. Round one
# of empirical testing on Claude Code 2.1.224 seemed to show coverage keyed on
# binary identity (cat/head/tail/sed denied, matching the docs' "such as"
# phrasing). Round two overturned that: `ls -la .env` and `file .env` were
# DENIED even though neither reads file contents, while `echo skipping .env`
# (which mentions the path but doesn't operate on it) RAN. rg/jq/sort/uniq/
# perl were also all DENIED despite not appearing in any binary list. That
# pattern is only explained by Claude Code resolving which paths a Bash
# command's arguments actually touch and applying the Read/Edit deny to any
# command touching a denied path -- not by binary membership. A binary-name
# allowlist/denylist therefore cannot determine coverage and must not gate a
# "reachable" vs "covered" split; see the cross_surface block below, which is
# informational only for exactly this reason.

# Deliberately NOT implemented: "sibling binary" detection (flagging scp/sftp
# because ssh is denied). Every execution-free signal available here -- name
# prefix, directory co-location -- either floods the report with coincidences
# ('su' -> 'sum', 'superclaude') or reports the wrong family members
# (ssh-keygen, not scp) while missing the real ones. The only thing that works
# is a hand-written table of equivalent tools, which is precisely what breaks
# when this skill runs on a machine with a different toolset. Equivalent-
# capability analysis is left to the model, which can reason about intent; the
# collector reports only what it can establish from the rules plus PATH.


def parse_rule(rule):
    """Split 'Bash(gpg -d:*)' into surface/binary/rest. None if unparseable."""
    match = RULE_RE.match(rule.strip())
    if not match:
        return None
    surface = match.group("surface")
    body = match.group("body").strip()
    # Trailing ':*' / '*' are glob suffixes, not part of the command.
    body = re.sub(r":\*$", "", body).strip()
    tokens = body.split()
    if not tokens:
        return {"surface": surface, "binary": None, "rest": "", "raw": rule}
    binary = tokens[0].strip("*").strip()
    # Path-style rules (Read(**/.env)) have no binary.
    if surface != "Bash":
        return {"surface": surface, "binary": None, "rest": body, "raw": rule}
    return {
        "surface": surface,
        "binary": os.path.basename(binary) if binary else None,
        "rest": " ".join(tokens[1:]).strip("*").strip(),
        "raw": rule,
    }


def which(binary):
    """PATH lookup only. Never executes the result."""
    if not binary or any(c in binary for c in "*?[]$"):
        return None
    try:
        return shutil.which(binary)
    except (OSError, ValueError):
        return None


def path_binaries():
    """Every executable name on PATH. Filesystem listing, no execution."""
    names = {}
    for entry in os.environ.get("PATH", "").split(os.pathsep):
        if not entry:
            continue
        try:
            directory = Path(entry)
            if not directory.is_dir():
                continue
            for item in directory.iterdir():
                if item.name in names:
                    continue
                if os.access(item, os.X_OK) and not item.is_dir():
                    names[item.name] = str(item)
        except (OSError, PermissionError):
            continue
    return names


def analyze_reachability(rule_sets):
    """Report deny rules whose capability is reachable another way here.

    rule_sets: list of (scope_label, permissions_dict). Deny rules from any
    scope are tested against allow rules from every scope, because a project
    allow rule can route around a user deny rule.
    """
    allow, deny, ask = [], [], []
    for label, perms in rule_sets:
        for mode, bucket in (("allow", allow), ("deny", deny), ("ask", ask)):
            for rule in perms.get(mode, []) or []:
                parsed = parse_rule(rule) if isinstance(rule, str) else None
                if parsed:
                    parsed["scope"] = label
                    bucket.append(parsed)

    denied_binaries = {r["binary"] for r in deny if r["binary"]}
    gated_binaries = denied_binaries | {r["binary"] for r in ask if r["binary"]}
    installed = path_binaries()
    findings = []

    # (1) Cross-surface: secret paths denied on one tool surface while another
    # surface has an allowed Bash binary that could, in principle, name the
    # same path. This is INFORMATIONAL inventory, not a finding -- see the
    # comment above DENY_EXTENSION_RECOGNIZED_READERS's removal. Empirically,
    # Claude Code resolves the actual paths a Bash command's arguments touch
    # and applies the Read/Edit deny to any command touching a denied path,
    # regardless of which binary is invoked (ls/file, which don't even read
    # contents, were denied; echo, which only mentions the path, was allowed).
    # A binary being allowed and installed is therefore NOT evidence it can
    # reach a denied path -- there is no execution-free way to know, from the
    # rules and PATH alone, which of these binaries' argv Claude Code would
    # actually resolve to the denied path. So this block reports the inventory
    # (which allowed Bash binaries exist alongside which path denies) without
    # asserting any of them are reachable.
    path_denies = [r for r in deny if r["surface"] != "Bash" and r["rest"]]
    if path_denies:
        readers = {}
        for rule in allow:
            if rule["surface"] != "Bash" or not rule["binary"]:
                continue
            binary = rule["binary"]
            if binary in gated_binaries or binary in readers:
                continue
            # Only binaries that can emit file contents are inventory-relevant
            # here. A rule granting mkdir/pwd is not plausibly related to
            # reading a denied path.
            if binary not in FILE_READING_BINARIES:
                continue
            resolved = which(binary)
            if resolved:
                readers[binary] = {
                    "binary": binary,
                    "path": resolved,
                    "rule": rule["raw"],
                    "scope": rule["scope"],
                }
        if readers:
            findings.append({
                "kind": "cross_surface",
                "status": "informational",
                "reportable": False,
                "denied_surfaces": sorted({r["surface"] for r in path_denies}),
                "denied_paths": [r["raw"] for r in path_denies],
                "allowed_bash_readers": sorted(readers.values(), key=lambda r: r["binary"]),
                "detail": (
                    "Informational only -- do not present as a gap. Path "
                    "denies (Read/Edit) are documented to extend to 'file "
                    "commands Claude Code recognizes in Bash', but empirical "
                    "testing on 2.1.224 shows this is NOT a fixed binary list: "
                    "Claude Code resolves which path a Bash command's "
                    "arguments actually operate on and applies the deny to any "
                    "command touching that path. Verified across "
                    "ls/file/rg/jq/sort/uniq/strings/od/cut/perl -- ls and file "
                    "were denied even though neither reads file contents, "
                    "while `echo <path>` (which only mentions the path) ran. "
                    "Because coverage is path-resolution-based, a binary being "
                    "allowed and installed here is NOT evidence it can reach "
                    "the denied path -- binary-identity lists cannot determine "
                    "coverage either way. allowed_bash_readers is inventory "
                    "only: which allowed, installed, file-reading Bash "
                    "binaries exist alongside these path denies."
                ),
                "caveat": (
                    "The genuinely uncovered class is arbitrary subprocesses "
                    "that open the file themselves rather than going through a "
                    "command Claude Code recognizes -- e.g. `python -c "
                    "\"open('.env').read()\"` or a node script -- which Claude "
                    "Code only PROMPTS for rather than denies. Bash deny "
                    "patterns that try to constrain arguments also remain "
                    "fragile in general (command substitution, variable "
                    "indirection, recursive traversal can evade them). For "
                    "the arbitrary-subprocess residue, the documented fix is "
                    "enabling the sandbox (sandbox.credentials.files with "
                    "mode deny), not adding more Bash deny patterns."
                ),
            })

    # (2) Flag-scoped: a binary denied only for certain flags. Other invocations
    # of the same installed binary remain allowed -- UNLESS a broader ask/deny
    # rule for the same binary already covers it, in which case the narrow
    # rule is redundant rather than a gap. An ask rule counts as coverage too:
    # it forces a human checkpoint on every invocation of that binary, which is
    # a strictly stronger control than a deny scoped to particular flags.
    def _is_broader_coverage(candidate, narrow_rest):
        """True if `candidate` (an ask/deny rule) covers `narrow_rest`.

        A covering rule must itself be trailing-wildcard/prefix form (its raw
        text ends with '*' or ':*') and its own rest must be empty or a
        strict prefix of the narrow rule's rest -- strict so a rule never
        counts as covering itself (chmod 777 * vs chmod 777 * is equal, not a
        strict prefix, and therefore excluded).
        """
        body = candidate["raw"].strip()
        if body.endswith(")"):
            body = body[:-1]
        if not (body.endswith("*") or body.endswith(":*")):
            return False
        cand_rest = candidate["rest"]
        if cand_rest == narrow_rest:
            return False
        if cand_rest == "":
            return True
        return narrow_rest.startswith(cand_rest + " ") or narrow_rest == cand_rest

    by_binary = {}
    for rule in deny:
        if not (rule["binary"] and rule["rest"]):
            continue
        # A deny naming a sensitive PATH ('cat *.env') is the correct way to
        # write this rule, not a gap. Only flag rules that constrain the
        # invocation itself ('gpg -d', 'rm -rf /'), where the same binary
        # stays reachable for equivalent work.
        if SENSITIVE_PATH_RE.search(rule["rest"]):
            continue
        by_binary.setdefault(rule["binary"], []).append(rule)
    for binary, rules in by_binary.items():
        resolved = which(binary)
        if not resolved:
            continue
        if any(r["binary"] == binary and not r["rest"] for r in deny):
            continue  # also denied binary-wide -> not a gap

        # Broader ask/deny rules for the same binary, checked across both
        # lists so an ask rule can retire a narrower deny rule.
        broader_candidates = [
            (r, "ask") for r in ask if r["binary"] == binary
        ] + [
            (r, "deny") for r in deny if r["binary"] == binary
        ]

        for rule in rules:
            covering = next(
                (
                    (cand, cand_list)
                    for cand, cand_list in broader_candidates
                    if _is_broader_coverage(cand, rule["rest"])
                ),
                None,
            )
            if covering:
                cand, cand_list = covering
                findings.append({
                    "kind": "flag_scoped",
                    "denied_binary": binary,
                    "path": resolved,
                    "denied_rules": [rule["raw"]],
                    "redundant": True,
                    "covered_by": cand["raw"],
                    "covered_by_list": cand_list,
                    "detail": (
                        f"'{rule['raw']}' is redundant, not a coverage gap: "
                        f"'{cand['raw']}' already covers every invocation of "
                        f"'{binary}' at {cand_list} scope. "
                        + (
                            f"An {cand_list} rule is a strictly stronger "
                            f"control than a narrow deny -- it forces a "
                            f"human checkpoint on every '{binary}' call. "
                            if cand_list == "ask"
                            else ""
                        )
                        + "Safe to drop the narrower rule."
                    ),
                })
            else:
                findings.append({
                    "kind": "flag_scoped",
                    "denied_binary": binary,
                    "path": resolved,
                    "denied_rules": [rule["raw"]],
                    "redundant": False,
                    "covered_by": None,
                    "covered_by_list": None,
                    "detail": (
                        f"'{binary}' is installed and denied only for specific "
                        f"flags ('{rule['raw']}'); other invocations of the "
                        "same binary are not covered by any broader ask/deny "
                        "rule."
                    ),
                })

    return {
        "note": (
            "Machine-specific. Only binaries resolvable on this host's PATH are "
            "reported, so results differ per machine by design. Probing is "
            "PATH resolution only -- no binary is executed."
        ),
        "path_binaries_seen": len(installed),
        "findings": findings,
    }


def scan_user_scope(home):
    root = home / ".claude"
    skills = inventory_skills(root / "skills")
    scope = {
        "root": str(root),
        "exists": root.is_dir(),
        "memory": file_stats(root / "CLAUDE.md"),
        "settings": summarize_settings(root / "settings.json"),
        "settings_local": summarize_settings(root / "settings.local.json"),
        "keybindings": file_stats(root / "keybindings.json"),
        "commands": inventory_markdown_dir(root / "commands", "command"),
        "agents": inventory_markdown_dir(root / "agents", "agent"),
        "skills": skills,
        # Convenience count so consumers don't have to filter `skills` for
        # `loads: false` themselves.
        "skills_not_loading": sum(1 for s in skills if not s.get("loads", False)),
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
    skills = inventory_skills(dot / "skills")
    scope = {
        "root": str(project),
        "memory": file_stats(project / "CLAUDE.md"),
        "memory_local": file_stats(project / "CLAUDE.local.md"),
        "settings": summarize_settings(dot / "settings.json"),
        "settings_local": summarize_settings(dot / "settings.local.json"),
        "commands": inventory_markdown_dir(dot / "commands", "command"),
        "agents": inventory_markdown_dir(dot / "agents", "agent"),
        "skills": skills,
        "skills_not_loading": sum(1 for s in skills if not s.get("loads", False)),
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


# Directory basenames that mean "this is a config subdirectory, not a
# project root" -- landing here almost always means --project was omitted
# and cwd happened to be inside ~/.claude or similar.
SUSPICIOUS_ROOT_BASENAMES = frozenset(
    {".claude", "skills", "commands", "agents", "hooks", "rules"}
)


def _root_warnings(project_root):
    """Warnings for a resolved project root that is probably the wrong dir.

    Two independent checks, kept distinct because they catch different
    mistakes: the basename check catches "cwd was inside ~/.claude/skills",
    the missing-markers check catches "cwd was some unrelated empty dir".
    """
    warnings = []
    if project_root.name in SUSPICIOUS_ROOT_BASENAMES:
        warnings.append(
            f"project root '{project_root}' has basename "
            f"'{project_root.name}', which is almost certainly wrong -- it "
            "looks like a Claude Code config subdirectory, not a project "
            "root. Pass --project <dir> explicitly."
        )
    has_claude_md = (project_root / "CLAUDE.md").exists()
    has_dot_claude = (project_root / ".claude").is_dir()
    has_mcp_json = (project_root / ".mcp.json").exists()
    if not (has_claude_md or has_dot_claude or has_mcp_json):
        warnings.append(
            f"project root '{project_root}' has no CLAUDE.md, no .claude/ "
            "dir, and no .mcp.json -- it does not look like a project root "
            "at all. Pass --project <dir> explicitly if this is unexpected."
        )
    return warnings


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
        "warnings": [],
    }

    user_root = Path.home() / ".claude"
    project_root = Path(args.project).resolve()

    # Resolved roots must be visible without opening the JSON -- a wrong
    # --project silently producing a "clean" empty report is exactly the
    # failure this exists to prevent.
    if not args.project_only:
        print(f"user scope: {user_root}", file=sys.stderr)
    if not args.user_only:
        print(f"project root: {project_root}", file=sys.stderr)

    if not args.project_only:
        result["scopes"]["user"] = scan_user_scope(Path.home())
    if not args.user_only:
        result["scopes"]["project"] = scan_project_scope(project_root)
        # scan_project_scope always resolves `root` to an absolute path (it
        # is derived from `project.resolve()`, never left null) even when
        # the scope turns out to be empty -- an unresolvable path is not
        # possible here since Path.resolve() succeeds even for a
        # nonexistent directory, so this cannot silently emit `root: null`.
        root_warnings = _root_warnings(project_root)
        if root_warnings:
            result["warnings"].extend(root_warnings)
            for warning in root_warnings:
                print(f"WARNING: {warning}", file=sys.stderr)

    # Reachability spans scopes: a project allow rule can route around a user
    # deny rule, so it is computed across everything collected, not per scope.
    rule_sets = []
    for label, scope in result["scopes"].items():
        for key in ("settings", "settings_local"):
            perms = (scope.get(key) or {}).get("permissions")
            if perms:
                rule_sets.append((f"{label}/{key}", perms))
    result["permission_reachability"] = analyze_reachability(rule_sets)

    payload = json.dumps(result, indent=2, ensure_ascii=False)
    if args.out:
        Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        Path(args.out).write_text(payload, encoding="utf-8")
        print(f"wrote {args.out} ({len(payload)} bytes)")
    else:
        print(payload)


if __name__ == "__main__":
    main()
