# Agent 2 Handoff

Agent: Agent 2

Parts:

- Part 3: Recent Context Ingestion
- Part 4: Rolling Recent Context Summaries

Completed subtasks:

- P3.1 imported Memory v2 recent-context DTOs from `src/contracts/index.ts`
- P3.2 input validation and normalization for source, app, URL, domain, repo path, file path, timestamps, TTL, and importance
- P3.3 `insertRecentContextEvent()` with deterministic idempotency by idempotency key
- P3.4 `getRecentContextEvents()` with time range, source, app, domain, repo, file, and limit filters
- P3.5 `cleanupExpiredRecentContext()` with configurable horizon and dry-run mode
- P3.6 optional embedding hook for events
- P3.7 graph extraction job enqueue after successful insert, without graph-module coupling
- P3.8 browser, repo/file, and screen-summary style fixtures in tests
- P3.9 tests for duplicate insert, invalid payloads, filtering, TTL cleanup, and metadata round trip
- P4.1 current context packet and summary inputs based on shared contracts
- P4.2 deterministic summarizer fallback
- P4.3 LLM summarizer seam via optional embedder/provider separation; no provider binding added
- P4.4 explicit summary window validation; active/idle window scheduling is left to the future job scheduler
- P4.5 summary idempotency by user, agent, window, idempotency key, and source hash
- P4.6 source event ids and optional summary embedding storage
- P4.7 `getCurrentContextPacket()` with last summary, recent raw events, and empty active entity placeholders
- P4.8 memory job enqueue for summary work
- P4.9 tests for empty/no-summary fallback, idempotent summary, latest summary packet, and invalid windows

Files changed:

- `services/memory-pglite/package.json`
- `services/memory-pglite/AGENT2_HANDOFF.md`
- `services/memory-pglite/src/jobs/index.ts`
- `services/memory-pglite/src/recent/events.ts`
- `services/memory-pglite/src/recent/hash.ts`
- `services/memory-pglite/src/recent/summaries.ts`
- `services/memory-pglite/tests/recent/events.test.ts`
- `services/memory-pglite/tests/recent/summaries.test.ts`

Contract files changed:

- None.

New enum values:

- None.

New table columns/indexes:

- None.

New endpoints or response fields:

- None. Agent 2 implemented service functions only, not HTTP routes.

Fixtures added/updated:

- No shared Agent 5 fixture files were modified.
- Agent 2 added module-level test fixture inputs inside `tests/recent/`.

Tests run:

- `npm run typecheck`
- `npm test`
- `npm run smoke`
- `env AURABOT_PGLITE_TEST_DIR=/tmp/aurabot-memory-pglite-agent2-schema-check npm run schema:check`

Known blockers:

- Contract/schema source mismatch remains from earlier agents: `docs/memory-v2-contracts.md` lists recent sources `terminal` and `system`, while schema constants currently allow `manual`. Agent 2 validates against the current schema constants so DB writes do not fail unexpectedly.
- The schema does not have separate `content`, `occurred_at`, `ttl_seconds`, or `importance` columns. Agent 2 maps:
  - DTO `content` to `recent_context_events.screen_summary`
  - DTO `occurred_at` to `recent_context_events.created_at`
  - DTO `ttl_seconds` and `importance` to metadata

Integration notes for other agents:

- API handlers should call `insertRecentContextEvent()`, `getRecentContextEvents()`, `cleanupExpiredRecentContext()`, `summarizeRecentContext()`, and `getCurrentContextPacket()` instead of querying tables directly.
- Graph extraction is represented as queued jobs with job type `extract_recent_context_graph`; Agent 4 can consume those jobs or replay extraction from event ids.
- Summary jobs use job type `summarize_recent_context`; repeated calls are idempotent through the summary id and job idempotency key.
- `getCurrentContextPacket()` intentionally returns `active_entities: []` until Agent 4 graph extraction can provide entity ids.
- If Agent 1 later adds first-class `occurred_at`, `ttl_seconds`, or `importance` columns, only `src/recent/events.ts` should need adjustment.
