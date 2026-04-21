# AuraBot Memory v2 Operations

This Agent 5 handoff doc covers the root test matrix, migration draft behavior, privacy paths, troubleshooting, and final release checklist for Memory v2.

## Test Matrix

Run these from the repository root unless a working directory is listed.

| Capability | Command | Expected result |
| --- | --- | --- |
| Repository contract tests | `python -m unittest discover tests` | GitHub Actions and Memory v2 contract fixtures pass. |
| Python memory API legacy tests | `cd services/memory-api && python -m unittest discover -s tests -v` | Legacy rollback surface still passes while v2 is being built. |
| Swift macOS compile | `cd apps/macos && swift build` | AuraBot compiles with v2 memory DTOs. |
| Swift fixture decode tests | `cd apps/macos && swift test` | Shared Memory v2 JSON fixtures decode into Swift DTOs. |
| Memory v2 contract check | `memory-pglite contracts:check` | TypeScript DTO validators accept all shared fixtures. |
| Memory v2 schema check | `memory-pglite schema:check` | PGlite migrations, tables, indexes, and vector readiness are valid. |
| Fixture load | `memory-pglite fixtures:load` | Recent event, brain page, graph, summary, and promotion fixture data load idempotently. |
| Search smoke | `memory-pglite search:smoke` | `/v2/search` returns a `SearchMemoryResponse` with recent, brain, and graph scores. |
| Graph smoke | `memory-pglite graph:smoke` | `/v2/graph/query` returns bounded nodes and evidence-backed relations. |

The `memory-pglite` commands are contract names. Owning agents may expose them through package scripts, a CLI binary, or Makefile wrappers, but the behavior must match this table.

## Migration Draft Export

When `DATABASE_URL` points at the old Postgres-backed memory store, the migration path should be draft-first:

1. Read v1 memory rows without mutating them.
2. Convert stable personalization candidates into markdown draft pages or timeline entries.
3. Preserve source ids, source timestamps, and hashes as evidence.
4. Write drafts under a staging directory, not directly into `~/.aurabot/brain`.
5. Emit a JSON report with counts, skipped rows, parse errors, and generated draft paths.

Recommended command contract:

```text
memory-pglite migration:export-v1 --user-id default_user --out ~/.aurabot/migration-drafts
```

Expected output shape:

```json
{
  "schema_version": "memory-v2",
  "generated_at": "2026-04-21T09:40:00Z",
  "source": "postgres_v1",
  "draft_root": "~/.aurabot/migration-drafts",
  "counts": {
    "read": 0,
    "drafted": 0,
    "skipped": 0,
    "errors": 0
  },
  "drafts": [],
  "errors": []
}
```

## Markdown Draft Import

Draft import must remain explicit and conflict-aware:

1. Validate frontmatter and slug path rules from `docs/memory-v2-contracts.md`.
2. Compare expected hashes before overwriting an existing brain page.
3. Import into `~/.aurabot/brain` only when the user approves the draft.
4. Enqueue brain sync after successful import.

Recommended command contract:

```text
memory-pglite brain:import-drafts --draft-root ~/.aurabot/migration-drafts --apply
```

Without `--apply`, the command should validate and print a dry-run report.

## Privacy And Deletion

Local storage paths:

- PGlite database: `~/.aurabot/pglite/aurabot`
- Markdown brain repo: `~/.aurabot/brain`
- Migration drafts: `~/.aurabot/migration-drafts`
- App config: `~/.aurabot/config.json`

Deletion behavior:

- Recent context deletes remove or tombstone noisy short-term events by id and source.
- Brain page deletes require an expected hash unless the caller uses an explicit force mode owned by the markdown writer.
- Graph edges must be removed or invalidated when their evidence source is deleted.
- Deleting the PGlite directory clears indexed memory and recent context, but does not delete markdown brain files.
- Deleting the brain directory removes durable personalization and should be treated as a destructive user action.

## Troubleshooting

### PGlite startup fails

- Confirm the service has read/write access to `AURABOT_HOME` or `~/.aurabot`.
- Check whether another Memory v2 service process is using the same PGlite directory.
- Run `memory-pglite schema:check` after fixing filesystem permissions.

### vector extension is unavailable

- Run `/v2/health` and inspect `database.vector_ready`.
- Re-run schema initialization after confirming the selected PGlite runtime supports `vector`.
- Use exact vector search fallback only when approximate index syntax is unsupported.

### stale schema or migration mismatch

- Compare `/v2/health.migration_version` against `docs/memory-v2-schema.md`.
- Run `memory-pglite schema:check`.
- Do not add endpoint fields to compensate for missing schema columns; fix the migration or coordinate a contract update.

### markdown parse conflicts

- Validate frontmatter first.
- Confirm the page has exactly one compiled truth/timeline divider.
- Use expected hash conflict responses instead of overwriting user edits.
- Re-run `POST /v2/brain/sync` after manual conflict resolution.

## Agent 5 Handoff

Agent: 5

Parts: 9, 10

Completed subtasks:

- P9.1: Added `docs/memory-v2-api.md`.
- P9.2: Added `docs/memory-v2-contracts.md`.
- P9.3: Added TypeScript DTOs and validators under `services/memory-pglite/src/contracts/`.
- P9.4: Added shared endpoint fixtures under `services/memory-pglite/src/test-fixtures/`.
- P9.11: Updated Swift `MemoryService` to call `/v2` endpoints.
- P9.12: Updated Swift memory, search, evidence, relation, graph, brain, promotion, delete, health DTOs.
- P9.13: Updated app usage for v2 search item fields and source-aware memory display.
- P9.14: Added Swift fixture decode tests and root fixture contract tests.
- P10.1: Added this test matrix.
- P10.5-P10.8: Documented migration draft, import, privacy, and troubleshooting contracts.
- P10.9-P10.10: Added handoff and release checklists.

Files changed:

- `docs/memory-v2-api.md`
- `docs/memory-v2-contracts.md`
- `docs/memory-v2-operations.md`
- `services/memory-pglite/src/contracts/index.ts`
- `services/memory-pglite/src/test-fixtures/*.json`
- `tests/test_memory_v2_contracts.py`
- `apps/macos/Sources/AuraBot/Models/Memory.swift`
- `apps/macos/Sources/AuraBot/Services/MemoryService.swift`
- `apps/macos/Sources/AuraBot/Services/AppService.swift`
- `apps/macos/Sources/AuraBot/Screens/MemoriesView.swift`
- `apps/macos/Sources/AuraBot/Components/MemoryCell.swift`
- `apps/macos/Tests/AuraBotTests/AuraBotTests.swift`

Contract files changed:

- Added Memory v2 API, shared contracts, TypeScript DTOs, and shared fixtures. Agents 1-4 should consume these fixtures before finalizing endpoint, graph, search, indexing, and summary implementations.

New enum values:

- Initial v2 enum sets for entity types, relation types, memory sources, recent context sources, job statuses, and promotion modes.

New table columns/indexes:

- None. Schema is Agent 1-owned.

New endpoints or response fields:

- Added `/v2/health`, `/v2/recent-context`, `/v2/current-context`, `/v2/recent-context/summaries`, `/v2/brain/sync`, `/v2/brain/pages/{slug}`, `/v2/graph/query`, `/v2/search`, `/v2/memories/promote`, and `/v2/memories/{source}/{id}`.
- All response bodies include `schema_version`.

Fixtures added/updated:

- `health-response.json`
- `recent-context-event-response.json`
- `recent-context-list-response.json`
- `current-context-response.json`
- `brain-sync-response.json`
- `graph-query-response.json`
- `search-response.json`
- `promotion-response.json`
- `delete-response.json`

Tests run:

- `python3 -m unittest discover tests` passed.
- `python3 -m unittest discover tests -p 'test_memory_v2_contracts.py'` passed.
- `cd apps/macos && swift build` passed. The only warnings were pre-existing `await` warnings in `AppDelegate.swift`.
- `cd apps/macos && swift test` could not run in this environment because the installed command line toolchain cannot import `XCTest`.

Known blockers:

- Agent 1 must provide the PGlite package runner and schema check command.
- Agents 2-4 must wire engine functions behind these endpoint contracts.
- The old Python memory API still exists as rollback scaffolding until the PGlite service is complete.

Integration notes for other agents:

- Agent 1 should expose `/v2/health` migration and vector readiness fields matching `health-response.json`.
- Agent 2 should make recent context add/list responses decode against the event fixtures.
- Agent 3 should follow slug and expected-hash rules in `docs/memory-v2-contracts.md`.
- Agent 4 should return graph relations with evidence arrays matching `graph-query-response.json`.
- Agent 8 implementation should return `/v2/search` exactly as `search-response.json` shapes it.

## Release Checklist

- `/v2/health` returns `schema_version: "memory-v2"` and status `ok`.
- Fresh PGlite initialization passes schema and vector checks.
- Shared fixtures load idempotently.
- Recent context add/list works without v1 endpoints.
- Brain sync indexes at least one markdown page.
- Graph query returns only evidence-backed relations.
- Search returns recent, brain, and graph-aware results in the v2 search shape.
- Swift app compiles and decodes shared fixtures.
- Deletion works for recent context and documents hash requirements for markdown-backed sources.
- v1 endpoints are not required for the Memory v2 happy path.
