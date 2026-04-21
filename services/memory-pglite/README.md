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
| `AURABOT_MEMORY_EMBEDDING_DIMENSIONS` | Embedding dimension count. Defaults to `1536`. |

## Commands

```bash
npm install
npm run smoke
npm run schema:check
npm test
```

`npm run smoke` opens a temporary database when `AURABOT_PGLITE_TEST_DIR` is set,
initializes PGlite, applies migrations, checks `SELECT 1`, and verifies vector
support. The runtime writes a sibling lock file at `<pglite-dir>.lock`; the
PGlite data directory itself remains PGlite-owned.

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
