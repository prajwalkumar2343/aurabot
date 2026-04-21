# AuraBot Memory PGlite

Local-first Memory v2 storage engine for AuraBot. This service owns the embedded
PGlite runtime, schema migrations, and schema health checks. It intentionally
does not implement the Memory v2 HTTP API or Swift client; those are Agent 5
owned integration tasks.

## Runtime

- Node.js 22+
- TypeScript
- `@electric-sql/pglite`
- PGlite data directory defaults to `~/.aurabot/pglite/aurabot`

Environment variables:

| Variable | Purpose |
| --- | --- |
| `AURABOT_HOME` | Base AuraBot data directory. Defaults to `~/.aurabot`. |
| `AURABOT_PGLITE_DIR` | Explicit PGlite data directory override. |
| `AURABOT_PGLITE_TEST_DIR` | Test-only PGlite data directory override. |
| `AURABOT_BRAIN_DIR` | Explicit markdown brain directory override. Defaults to `~/.aurabot/brain`. |
| `AURABOT_MEMORY_EMBEDDING_DIMENSIONS` | Embedding dimension count. Defaults to `1536`. |

## Commands

```bash
npm install
npm run smoke
npm run schema:check
npm run brain:init
npm run brain:sync
npm run serve
npm test
```

`npm run smoke` opens a temporary database when `AURABOT_PGLITE_TEST_DIR` is set,
initializes PGlite, applies migrations, checks `SELECT 1`, and verifies vector
support. The runtime writes a sibling lock file at `<pglite-dir>.lock`; the
PGlite data directory itself remains PGlite-owned.

`npm run brain:init` creates the markdown brain starter directories and files
without overwriting existing user-edited pages. `npm run brain:sync` scans the
brain directory, validates frontmatter, indexes changed pages into
`brain_pages`, `brain_chunks`, and `timeline_events`, and enqueues graph
extraction jobs for changed pages.

`npm run serve` starts the local Memory v2 PGlite HTTP service.

`POST /v2/graph/query` accepts:

```json
{
  "user_id": "default_user",
  "start": "projects/aurabot",
  "relation_types": ["uses"],
  "depth": 2,
  "direction": "both",
  "limit": 50
}
```

The route returns the shared `GraphQueryResponse` shape from
`src/contracts/index.ts`.

`POST /v2/search` accepts:

```json
{
  "user_id": "default_user",
  "query": "what did we decide about memory storage?",
  "scopes": ["all"],
  "limit": 10
}
```

The route returns the shared `SearchMemoryResponse` shape from
`src/contracts/index.ts`.

Graph extraction jobs queued by recent-context ingestion and brain sync can be
processed with `processGraphExtractionJobs()` from `src/graph/jobs.ts`.

## Agent 1 Ownership

Owned files:

- `src/database/`
- `src/config/`
- `src/schema/`
- `src/migrations/`
- `tests/schema/`
- `docs/memory-v2-schema.md`

Do not add endpoint DTOs here. API contracts belong to Agent 5 under
`services/memory-pglite/src/contracts/` and `docs/memory-v2-contracts.md`.
