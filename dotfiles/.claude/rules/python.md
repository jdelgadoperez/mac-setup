## Python

- Always use `uv` instead of `pip` for package management
- When running `ruff check --fix`, always follow up immediately with `ruff check` (no `--fix`) to
  verify no imports were broken by auto-fixes. Do not commit until the second check is clean.
