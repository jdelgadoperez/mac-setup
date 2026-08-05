---
name: "proton-drive-cli"
description: >-
  Manage Proton Drive from the command line via the `proton-drive` CLI — list, upload, download,
  move, copy, trash, restore, and share files and folders, plus manage share invitations and public
  links. Use whenever the user asks to work with Proton Drive, put a file on Proton, pull a file
  down from Proton Drive, back something up to Proton, or share a Proton Drive file with someone.
---

# proton-drive-cli

End-to-end file management for Proton Drive. The binary is `proton-drive` (installed at
`/usr/local/bin/proton-drive`), a Bun-compiled wrapper over the Proton Drive SDK.

## The two rules that matter most

**1. Every remote path starts with `/my-files`.** There is no bare `/` root. `/`, `.`, `""`,
`root`, and `/root` are all rejected with `Path "..." is not supported`. Own files live under
`/my-files/...`.

**2. Always pass an explicit conflict strategy on `upload` and `download`.** With no strategy and
a name collision, the CLI **prompts interactively and blocks on stdin**:

```
Conflict on "notes.txt" (file). Type a strategy (merge, keep-both, replace, skip; or
abbreviations), or [a]pply-to-all
>
```

In a non-interactive/agent context this hangs or silently consumes empty stdin and skips the file.
Passing `-c` makes the command fully non-interactive. This is the single most common failure mode.

```bash
# Good — never prompts
proton-drive filesystem upload -c replace ./report.pdf /my-files/work

# Risky — blocks on a conflict
proton-drive filesystem upload ./report.pdf /my-files/work
```

## Command reference

```
auth login
auth logout
filesystem list [-t TYPE] path
filesystem info path
filesystem create-folder parentPath name
filesystem upload [-c STRATEGY] [-f STRATEGY] [-d STRATEGY] [-t] localPath... parentPath
filesystem download [-c STRATEGY] [-f STRATEGY] [-d STRATEGY] path... localFolder
filesystem rename path newName
filesystem copy [-n NAME] sourcePath... targetParentPath
filesystem move sourcePath... targetParentPath
filesystem trash path...
filesystem restore path...
filesystem delete path...
filesystem empty-trash
sharing status path
sharing invite [-u USER...] [-r ROLE] [-m MESSAGE] [-n] path
sharing leave path
sharing remove [-e EMAIL...] [-a] path
sharing set-url [--role ROLE] [--password PASSWORD] [--expiration EXPIRATION] path
sharing remove-url path
invitation list
invitation accept invitationUid
invitation reject invitationUid
```

### Enumerated values

| Flag | Valid values |
|------|--------------|
| `-c` / `-f` / `-d` STRATEGY | `merge`, `keep-both`, `replace`, `skip` (unique abbreviations allowed, e.g. `-c r`) |
| `-t` TYPE (on `list`) | `folder`, `file`, `album`, `photo` |
| `-r` / `--role` ROLE | `viewer`, `editor`, `admin` |

`-t` on **`upload`** is a different flag — it's `--skip-thumbnails` (a boolean), not a type filter.
Don't confuse it with `-t TYPE` on `list`.

### Global options

- `-j` / `--json` — machine-readable output. **Must come after the subcommand**, not before.
  `proton-drive filesystem list /my-files -j` works; `proton-drive -j filesystem list /my-files`
  prints the usage block instead. Prefer `-j` whenever parsing output.
- `-v` / `--verbose`
- `-h` / `--help` — top-level only. Per-subcommand help is **not** implemented: `filesystem upload
  --help` prints the generic usage block followed by `Command not found: filesystem upload --help`.
  This file is the reference; don't burn a call trying to get deeper help out of the binary.

## Recipes

```bash
# Browse
proton-drive filesystem list /my-files
proton-drive filesystem list -t folder /my-files          # folders only
proton-drive filesystem list /my-files/work -j            # JSON for parsing
proton-drive filesystem info /my-files/report.pdf

# Upload / download (always with a strategy)
proton-drive filesystem upload -c replace ./report.pdf /my-files/work
proton-drive filesystem upload -c keep-both ./a.txt ./b.txt /my-files/work
proton-drive filesystem download -c replace /my-files/work/report.pdf ./local-dir

# Organize
proton-drive filesystem create-folder /my-files archive-2026
proton-drive filesystem rename /my-files/old.txt new.txt   # newName is bare, not a path
proton-drive filesystem move /my-files/a.txt /my-files/archive-2026
proton-drive filesystem copy -n copy.txt /my-files/a.txt /my-files/work

# Remove (see safety note below)
proton-drive filesystem trash /my-files/scratch.txt
proton-drive filesystem restore /my-files/scratch.txt

# Share
proton-drive sharing status /my-files/report.pdf
proton-drive sharing invite -u alice@example.com -r viewer /my-files/report.pdf
proton-drive sharing set-url --role viewer --password hunter2 /my-files/report.pdf
proton-drive sharing remove-url /my-files/report.pdf

# Incoming shares
proton-drive invitation list
proton-drive invitation accept <invitationUid>
```

## Deletion safety

`trash` is recoverable via `restore`. **`delete` and `empty-trash` are permanent and irreversible.**

Default to `trash`. Only use `delete` / `empty-trash` when the user explicitly asks to permanently
delete, and confirm the exact paths first — these commands take `path...` and accept multiple
targets, so a wrong glob destroys more than intended.

## Output shapes

Human-readable `list` output is emoji-prefixed and **not** reliably parseable:

```
🗂️  👑 user@proton.me Sep 30 2025 15:59 - archives
📄  👑 user@proton.me Oct 25 2025 16:32 129148 bookmarks.html
```

`🗂️` = folder, `📄` = file; folders show `-` where files show a byte size. For anything
programmatic use `-j`, which returns an array of node objects with `uid`, `parentUid`, `type`,
`mediaType`, `totalStorageSize`, `isShared`, timestamps, and `name`/`keyAuthor` as
`{ok: true, value: ...}` result wrappers — unwrap `.value` rather than reading those fields
directly.

Note that `filesystem info` prints JS-inspect format (unquoted keys, single quotes) — **not** valid
JSON — unless you pass `-j`.

## Auth

`proton-drive auth login` / `auth logout`. Credentials are stored per
`PROTON_DRIVE_CREDENTIALS_STORE`: OS keychain (default), `pass`, or a plaintext file (testing
only — don't recommend it). Login is interactive; if a command fails on auth, tell the user to run
`proton-drive auth login` themselves rather than trying to drive the prompt.
