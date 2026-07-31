---
description: Audit how completely a project is specified for safe agent delegation — predicts where an agent will silently fill gaps with training-data defaults
argument-hint: "[project-dir]"
---

# Spec Completeness Audit

Audit how well this project is *specified* for delegating work to a coding
agent. An under-specified layer doesn't produce an error — the agent silently
fills the gap from training priors, and the result looks plausible while
violating unwritten intent. This audit predicts where that will happen.

Read-only until the final step: never edit files before the user approves
specific fixes.

## Phase 1 — Inventory

Check for spec-bearing artifacts: `CLAUDE.md` (both locations), `README.md`,
`AGENTS.md`, `CONTRIBUTING.md`, `docs/ARCHITECTURE.md`, ADR directories
(`docs/adr`, `docs/ADR`, `adr/`), `.claude/rules/`, linter configs
(`.eslintrc*`, `eslint.config.*`, `.pylintrc`, `pyproject.toml`,
`.rubocop.yml`), formatter configs (`.prettierrc*`, `biome.json`,
`.editorconfig`, `rustfmt.toml`), typed contracts (strict TypeScript / mypy,
Zod / Pydantic / Joi at boundaries, OpenAPI / GraphQL / protobuf schemas),
and a CHANGELOG. Read what exists; sample a couple of source files to judge
typing and error-handling quality directly rather than trusting file counts.

## Phase 2 — Score the five layers

| Layer | Weight | What "specified" means |
|---|---|---|
| 1. Behavioral | /15 | What the software *does*: features, flows, endpoints, purpose |
| 2. Interface | /20 | Types, schemas, error contracts, invariants at boundaries |
| 3. Architectural | /30 | Negative constraints ("never X"), module boundaries, what already exists and must be reused, named patterns, ADRs |
| 4. Lifecycle | /20 | Intentional debt (TODO/FIXME with rationale), migration plans, what's deliberately deferred |
| 5. Cultural | /15 | Conventions the linter can't encode: naming, style, quality bar, review criteria |

Architectural is weighted heaviest deliberately: it's the layer most often
missing and the hardest to detect when an agent gets it wrong.

## Phase 3 — Gap-fill risk

For every layer under 60%, name 2–3 **specific silent fills** likely in *this*
codebase (e.g. missing Layer 3 → agent writes a duplicate of an existing
helper module; missing Layer 2 → agent invents optimistic error handling;
missing Layer 4 → agent "fixes" an intentional shortcut). Name the single
most dangerous one.

## Phase 4 — Report

- **Executive summary**: total score /100, delegation verdict, top 3 fixes
  ranked by impact-per-effort.
- **Delegation verdict**: 80+ safe to delegate broadly (still augment
  per-task) · 60–79 delegate with supervision · 40–59 delegate only narrow,
  well-specified tasks · <40 do not delegate architectural work.
- **Layer scorecard** with per-layer gaps: each gap gets the silent fill it
  causes, a concrete fix with example content, and an effort bucket
  (<30 min / ~1 h / half-day).
- **Quick wins**: up to 3 paste-ready spec fragments (e.g. a "never do X"
  constraints block for CLAUDE.md, a module map, a debt-rationale comment
  template).

Then ask which fixes to apply (all / by number / none) before writing anything.

---

*Adapted from `spec-completeness-audit.md` (based on Hamidreza Saghir's
five-layer spec framework) in
[claude-code-ultimate-guide](https://github.com/FlorianBruniaux/claude-code-ultimate-guide)
by Florian Bruniaux (CC BY-SA 4.0).*
