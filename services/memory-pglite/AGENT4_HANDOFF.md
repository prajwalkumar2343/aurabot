# Agent 4 Handoff

Agent: Agent 4

Parts:

- Part 7: Entity and Relation Extraction
- Part 8: Graph-Aware Retrieval

Completed subtasks:

- P7.1 canonical entity key builder for user, app, website, repo, file, slug-backed, and title-backed entities.
- P7.2 alias upsert with normalized aliases and evidence source metadata.
- P7.3 deterministic entity extraction from recent context structured fields.
- P7.4 deterministic entity extraction from indexed markdown page slug, title, frontmatter, wikilinks, and slug links.
- P7.5 deterministic recent-context relations for `uses`, `visited`, `opened`, `edited`, `works_on`, and project context links.
- P7.6 deterministic markdown relations for project/workflow usage, repo ownership, decisions, preferences, mentions, and evidence links.
- P7.7 evidence object writing for every relation using source type, source id, excerpt, content hash, timestamp, and metadata.
- P7.8 confidence scoring for deterministic sources, with idempotent relation upsert preserving the stronger confidence.
- P7.9 LLM-assisted extraction adapter interface behind an explicit disabled-by-default flag.
- P7.10 idempotent extraction functions for recent event id, brain page id, and full user backfill.
- P7.10 follow-up: queued `memory_jobs` graph extraction processor for recent context and brain page jobs.
- P7.11 graph fixtures covered in `tests/graph/`.
- P8.1 query entity lookup from aliases, slugs, domains, paths, repo names, titles, and partial title n-grams.
- P8.2 bounded graph traversal with depth cap 4, direction filter, relation-type filter, cycle prevention, and node/relation caps.
- P8.3 graph query DTO returned through the existing shared contract shape.
- P8.4 exact vector search hooks for recent summaries and brain chunks when an embedder is provided.
- P8.5 keyword search over recent summaries, recent events, and brain chunks.
- P8.6 RRF merge across vector, keyword, and graph candidate lists.
- P8.7 ranking boosts for compiled truth, timeline chunks, recent context, graph neighbors, evidence confidence, and recency.
- P8.8 per-result ranking explanation metadata and response-level ranking debug fields.
- P8.9 `searchMemory()` service function for Agent 5 API wiring.
- P8.9 follow-up: `POST /v2/search` wired in the local PGlite HTTP service.
- P8.10 relation-focused tests for decisions, project-repo usage, and workflow-website connections.
- P8.11 traversal cap and result limit checks in graph tests.

Files changed:

- `services/memory-pglite/package.json`
- `services/memory-pglite/AGENT4_HANDOFF.md`
- `services/memory-pglite/src/cli.ts`
- `services/memory-pglite/src/graph/jobs.ts`
- `services/memory-pglite/src/graph/index.ts`
- `services/memory-pglite/src/server.ts`
- `services/memory-pglite/src/search/index.ts`
- `services/memory-pglite/tests/graph/extraction.test.ts`
- `services/memory-pglite/tests/graph/jobs.test.ts`
- `services/memory-pglite/tests/search/search.test.ts`
- `services/memory-pglite/tests/server/graph-query-route.test.ts`
- `services/memory-pglite/tests/server/search-route.test.ts`

Contract files changed:

- None.

New enum values:

- None.

New table columns/indexes:

- None.

New endpoints or response fields:

- `POST /v2/graph/query` in the local PGlite HTTP service. It returns the existing shared `GraphQueryResponse` shape and does not add response fields.
- `POST /v2/search` in the local PGlite HTTP service. It returns the existing shared `SearchMemoryResponse` shape and does not add response fields.

Fixtures added/updated:

- No shared Agent 5 fixture files were modified.
- Agent 4 added module-level graph/search fixtures inside `tests/graph/` and `tests/search/`.

Tests run:

- `npm run typecheck`
- `npm test`
- `npm run graph:smoke`
- `npm run search:smoke`

Known blockers:

- None in Agent 4 scope.

Integration notes for other agents:

- `/v2/graph/query` is wired in `src/server.ts`; Agent 5 can supervise or proxy this PGlite service route from the Python launcher if needed.
- `/v2/search` is wired in `src/server.ts`; Agent 5 can supervise or proxy this PGlite service route from the Python launcher if needed.
- Agent 2 and Agent 3 graph jobs can be fulfilled by calling `processGraphExtractionJobs()` from `src/graph/jobs.ts`.
- Graph extraction consumes already-normalized recent rows and indexed brain pages; it does not parse markdown files directly.
- Graph retrieval is read-only and does not mutate graph state.
