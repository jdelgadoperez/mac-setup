## LLM Wiki Pattern

The wiki lives at `~/JDP Vault/LLM/`. All LLM-maintained pages, indexes, and logs go there.

When working in a project structured as an LLM-maintained knowledge base (wiki), follow these conventions.

### Three-layer architecture

- **Raw sources** (`raw/` or equivalent) — immutable source documents. Read from them, never modify them.
- **Wiki** (`wiki/` or equivalent) — LLM-generated and LLM-maintained markdown files. You own this layer entirely: create pages, update them, maintain cross-references, keep everything consistent.
- **Schema** — a CLAUDE.md or AGENTS.md at the project root describing wiki structure, conventions, and workflows.

Always read the project's schema document first before any ingest, query, or lint operation.

### Special files

- **`index.md`** — content-oriented catalog: every wiki page listed with a link, one-line summary, and optional metadata. Update on every ingest. Read this first when answering queries to identify relevant pages.
- **`log.md`** — append-only chronological record of ingests, queries, and lint passes. Use the format `## [YYYY-MM-DD] operation | description` so entries are grep-parseable (e.g. `## [2026-04-27] ingest | Article Title`).

### Ingest workflow

When the user adds a new source:
1. Read the source
2. Discuss key takeaways with the user
3. Write a summary page in the wiki
4. Update `index.md`
5. Update all relevant entity and concept pages (a single source may touch 10–15 pages)
6. Append an entry to `log.md`

### Query workflow

1. Read `index.md` to identify relevant pages
2. Read those pages and synthesize an answer with citations
3. If the answer is valuable (a comparison, an analysis, a discovered connection), file it back into the wiki as a new page and update `index.md` — explorations should compound in the knowledge base, not disappear into chat history

### Lint workflow

When asked to health-check the wiki, look for:
- Contradictions between pages
- Stale claims that newer sources have superseded
- Orphan pages with no inbound links
- Important concepts mentioned on multiple pages but lacking their own dedicated page
- Missing cross-references between related pages
- Data gaps that could be filled with a web search
