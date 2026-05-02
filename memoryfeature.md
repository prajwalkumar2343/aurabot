# AuraBot Memory Feature Plan

## Goal

Build AuraBot Memory v2 as a local-first memory system inspired by GBrain:

- PGlite-backed local database for fast retrieval, recent context, graph data, and embeddings.
- Markdown brain files as the durable, human-editable source of truth for long-term personalization.
- Two memory horizons:
  - Short-term context: the last 6 hours of noisy screen, app, browser, and workflow context.
  - Long-term personalization: stable knowledge about the user, projects, people, workflows, preferences, decisions, and concepts.
- Graph relations as a first-class retrieval layer, not just metadata.
- A clean Memory v2 API and Swift client cutover. Do not preserve v1 compatibility as a feature requirement.

The implementation should move AuraBot to a new Memory v2 contract directly. Old v1 memory endpoints are deprecated scaffolding and may be removed; they must not constrain schema, response shapes, client models, or task design.

## Target Architecture

```text
macOS app
  -> new Memory v2 Swift client calls
  -> AuraBot Memory v2 API
  -> Memory engine interface
       -> PGlite local engine

PGlite local engine
  -> recent context tables
  -> markdown brain page index
  -> chunk embeddings
  -> entity graph
  -> search/ranking tables

Markdown brain repo
  ~/.aurabot/brain/
    USER.md
    PREFERENCES.md
    projects/
    people/
    companies/
    workflows/
    apps/
    websites/
    repos/
    files/
    concepts/
    decisions/
    timelines/
```

Core rules:

```text
Recent, noisy, temporary activity goes into PGlite tables.
Rolling recent-context summaries are also materialized into generated markdown
pages so the brain index can retrieve the current working context.
Stable, durable personalization goes into markdown files and is indexed into PGlite.
Every graph edge must point to evidence: a recent event, markdown page, chunk, or timeline event.
```

## Non-Goals

- Do not vendor, clone, or import GBrain code into this repository.
- Do not replace the macOS app UI as part of this feature.
- Do not require external Postgres for local memory.
- Do not store every raw screenshot event as a markdown file; only generated rolling summaries may be mirrored into markdown.
- Do not make graph edges without evidence.
- Do not preserve v1 API compatibility as a goal.
- Do not let old Postgres table shapes constrain the PGlite schema. Treat existing Postgres data as an import/migration source only.

## Shared Contracts

All agents should treat these contracts as stable unless they coordinate an explicit change.

### Memory Engine Interface

The Memory v2 API should call a PGlite-backed engine interface with these operations:

```text
add_recent_context(event) -> event payload
get_recent_context(user_id, agent_id=None, range=None, limit=50) -> event payload[]
get_current_context(user_id, agent_id=None) -> current context packet
summarize_recent_context(user_id, window) -> summary payload
sync_brain_pages(user_id) -> sync report
search_memory(query, user_id, scopes=None, limit=10) -> search result
graph_query(start, relation_types=None, depth=2, direction="both") -> graph result
promote_memory(candidate_id, mode="draft") -> promotion result
delete_memory_item(id, source) -> deletion result
```

### Search Result Shape

Use a v2-native search shape. The Swift client should be updated to consume this directly.

```json
{
  "query": "what did we decide about memory storage?",
  "items": [
    {
      "id": "string",
      "source": "recent_context|recent_summary|brain_page|brain_chunk|graph",
      "content": "string",
      "user_id": "string",
      "entity_ids": [],
      "relations": [],
      "evidence": [],
      "score": 0.0,
      "scores": {
        "vector": 0.0,
        "keyword": 0.0,
        "graph": 0.0,
        "recency": 0.0
      },
      "created_at": "iso timestamp",
      "metadata": {}
    }
  ],
  "debug": {
    "matched_entities": [],
    "ranking": {}
  }
}
```

### Markdown Page Format

Each long-term page should use frontmatter, compiled truth, and timeline evidence:

```markdown
---
type: project
title: AuraBot
slug: projects/aurabot
tags: [memory, macos, local-first]
updated_at: 2026-04-21T00:00:00Z
---

Compiled truth goes here. This is the current best summary.

---

- 2026-04-21: Evidence item or decision with source reference.
```

### Entity Types

Use this initial closed set:

```text
user
person
company
project
app
website
repo
file
workflow
concept
decision
task
meeting
document
preference
```

### Relation Types

Use this initial closed set:

```text
works_on
uses
visited
opened
edited
mentioned_in
discussed_with
decided_in
evidence_for
related_to
depends_on
blocks
belongs_to
part_of
authored
created
prefers
```

## 5-Agent Coordination Model

Each agent owns two task parts. Write sets are intentionally separated to avoid conflicts.

| Agent | Parts | Ownership |
| --- | --- | --- |
| Agent 1 | Part 1, Part 2 | PGlite service foundation and schema |
| Agent 2 | Part 3, Part 4 | Recent context ingestion and rolling summaries |
| Agent 3 | Part 5, Part 6 | Markdown brain repo and indexing |
| Agent 4 | Part 7, Part 8 | Entity graph and graph-aware retrieval |
| Agent 5 | Part 9, Part 10 | Memory v2 API cutover, Swift client update, tests, migration docs |

Coordination rules:

- Do not edit another agent's owned files unless the owner has finished and asked for integration help.
- Shared API and schema changes must be recorded in this file or a dedicated design note before implementation.
- Add tests in the owned test area for each task part.
- Prefer additive work during development, but the final product should cut over to Memory v2 contracts.
- Keep old code available only as a rollback or migration aid until the PGlite path has add, get, search, delete, markdown sync, and graph query working.

## Compatibility Control Plan

The biggest multi-agent risk is incompatible assumptions: one agent creates an endpoint shape, another creates a database shape, another writes Swift models for a third shape. To prevent that, implementation should be contract-first.

### Single-Owner Shared Artifacts

Only the listed owner should edit each shared artifact. Other agents may read and import these files, but should not modify them without a checkpoint.

| Artifact | Owner | Purpose |
| --- | --- | --- |
| `docs/memory-v2-api.md` | Agent 5 | Canonical HTTP endpoints, request bodies, response bodies, error shapes |
| `docs/memory-v2-schema.md` | Agent 1 | Canonical table list, columns, indexes, migration notes |
| `docs/memory-v2-contracts.md` | Agent 5 | Shared enums, payload names, lifecycle states, evidence format |
| `services/memory-pglite/src/contracts/` | Agent 5 | TypeScript DTOs for API payloads and result shapes |
| `services/memory-pglite/src/schema/` | Agent 1 | SQL/schema definitions and migration metadata |
| `services/memory-pglite/src/test-fixtures/` | Agent 5 | Shared fixtures consumed by all agents |
| `apps/macos/Sources/AuraBot/Models/Memory.swift` | Agent 5 | Swift mirror of Memory v2 DTOs |

Contract rule:

```text
If an implementation requires a new field, enum value, endpoint, relation type, or table column, update the owned contract doc first, then implementation, then tests.
```

### Versioned Contract Fields

Use these conventions across all outputs:

- Every API response includes `schema_version: "memory-v2"`.
- Every persisted row that can be re-indexed includes `content_hash` or `source_hash`.
- Every generated artifact includes `generated_by` and `generated_at` in metadata when practical.
- Every graph edge includes `evidence` with source id and source type.
- Every background job includes `idempotency_key`.
- Every timestamp is ISO 8601 UTC.
- Every enum value uses `snake_case`.

### Integration Check Commands

Each agent should provide commands with these meanings. Exact command names can differ if documented in `docs/memory-v2-contracts.md`, but the capability must exist.

```text
memory-pglite schema:check       # tables, indexes, extensions, migration version
memory-pglite contracts:check    # DTO fixtures validate against TypeScript contracts
memory-pglite fixtures:load      # load shared test fixture dataset
memory-pglite search:smoke       # run one recent + markdown + graph search
memory-pglite graph:smoke        # run one graph traversal with evidence
swift memory:compile             # compile Swift package after model changes
```

### Contract Freeze Checkpoints

Checkpoint 0: before parallel implementation

- Agent 5 creates `docs/memory-v2-api.md`, `docs/memory-v2-contracts.md`, and shared fixtures.
- Agent 1 creates `docs/memory-v2-schema.md` and initial schema draft.
- Agents 2-4 may build against fixtures, but should not invent final response shapes.

Checkpoint 1: after schema draft

- Agent 1 publishes table and column names.
- Agents 2-4 update their modules to use schema constants, not local string copies.
- Agent 5 checks Swift DTOs against the same fixture JSON.

Checkpoint 2: after ingestion, markdown parsing, and graph extraction fixtures

- Agent 2 provides recent context fixture rows.
- Agent 3 provides markdown parse/index fixture rows.
- Agent 4 provides entity and relation fixture rows.
- Agent 5 combines them into one end-to-end fixture dataset.

Checkpoint 3: before graph-aware search

- Agent 4 confirms graph traversal payloads.
- Agent 5 confirms `/v2/search` response shape.
- Agent 1 confirms all needed query indexes exist.

Checkpoint 4: before final cutover

- `contracts:check`, `schema:check`, graph smoke, search smoke, and Swift compile all pass.
- No module imports private internals from another agent's owned module.
- Deprecated v1 references are only in migration docs or explicitly marked legacy code.

## Detailed Subtask Breakdown

Use these subtask IDs in branch names, PR titles, commit messages, and agent status notes. Each subtask should produce a small reviewable change and a test or fixture update when possible.

### Part 1 Subtasks: PGlite Runtime Foundation

- P1.1 Create `services/memory-pglite/` package skeleton with TypeScript config, lint/test command placeholders, and README.
- P1.2 Add PGlite dependency and choose runtime command (`node`, `bun`, or documented equivalent).
- P1.3 Implement `resolveAuraBotHome()` and `resolvePgliteDir()` with environment override tests.
- P1.4 Implement database lifecycle wrapper: open, close, query, transaction, and structured errors.
- P1.5 Enable `vector` extension during initialization and expose `assertVectorReady()`.
- P1.6 Add single-process write guard documentation and runtime warning if multiple service instances point to the same data dir.
- P1.7 Add `schema:check` placeholder that calls Part 2 once migrations exist.
- P1.8 Add runtime smoke test using a temp data directory.
- P1.9 Publish handoff note: database open API, config env vars, startup command, shutdown behavior.

Compatibility dependencies:

- Must not define table schemas outside the Part 2 migration path.
- Must not define HTTP DTOs outside `src/contracts/`.
- Must expose stable database wrapper imports for Parts 2-8.

### Part 2 Subtasks: PGlite Schema and Migrations

- P2.1 Create migration runner with applied migration tracking in `memory_store_config`.
- P2.2 Add schema constants for table names and enum column values.
- P2.3 Create `recent_context_events` with retention/query indexes.
- P2.4 Create `recent_context_summaries` with source event references and time-window uniqueness.
- P2.5 Create `brain_pages` with slug, path, page type, frontmatter JSON, hashes, and timestamps.
- P2.6 Create `brain_chunks` with chunk type, chunk hash, content, embedding, and page foreign key.
- P2.7 Create `entities` and `entity_aliases` with normalized lookup keys.
- P2.8 Create `entity_links` with relation type, confidence, metadata, and evidence pointers.
- P2.9 Create `timeline_events` and connect them to pages/entities/evidence.
- P2.10 Create `memory_jobs` with status, idempotency key, attempts, and payload/result JSON.
- P2.11 Add indexes and exact vector search fallback if approximate index syntax is not supported.
- P2.12 Add schema fixture seed helpers for Parts 3-8.
- P2.13 Update `docs/memory-v2-schema.md` with all columns and intended owning module.

Compatibility dependencies:

- Must keep table and column names stable after Checkpoint 1 unless all dependent agents agree.
- Must expose migration version to `/v2/health`.
- Must not add relation/entity enum values outside the shared contracts.

### Part 3 Subtasks: Recent Context Ingestion

- P3.1 Define `RecentContextEventInput` by importing contract types, not re-declaring local shapes.
- P3.2 Implement input validation and normalization for app, URL, domain, repo path, file path, and timestamp.
- P3.3 Implement `insertRecentContextEvent()` with idempotency handling.
- P3.4 Implement `getRecentContextEvents()` by time range, source, app, domain, repo, file, and limit.
- P3.5 Implement retention cleanup with configurable horizon and dry-run mode.
- P3.6 Add embedding hook that can be a no-op in tests and model-backed in integration.
- P3.7 Emit graph extraction job request after successful insert, but do not call graph internals directly.
- P3.8 Add fixtures for one browser event, one app event, one repo/file event, and one screen summary event.
- P3.9 Add tests for duplicate insert, malformed URL, missing optional fields, retention, and metadata round trip.

Compatibility dependencies:

- Must use Part 2 table constants.
- Must not write markdown files.
- Must not create graph edges directly; enqueue or expose extraction inputs for Part 7.

### Part 4 Subtasks: Rolling Recent Context Summaries

- P4.1 Define `RecentContextSummaryInput` and `CurrentContextPacket` from shared contracts.
- P4.2 Implement deterministic summarizer fallback using app/domain/repo/file frequency and latest intent.
- P4.3 Add LLM summarizer interface without binding to a specific provider.
- P4.4 Implement summary window selection for 15-minute active windows and 30-minute idle windows.
- P4.5 Implement summary idempotency by user, agent, start time, end time, and source event hash.
- P4.6 Store source event ids and summary embedding.
- P4.7 Implement `getCurrentContextPacket()` with last summary, recent raw events, and active entity placeholders.
- P4.8 Add job integration using `memory_jobs` and idempotency keys.
- P4.9 Add tests for empty window, duplicate window, deterministic fallback, and current context packet shape.

Compatibility dependencies:

- Must consume Part 3 query functions rather than querying raw tables from multiple places.
- Must not assume graph extraction is available; active entities can be empty until Part 7 lands.
- Must return the contract-defined packet shape used by Part 9 Swift models.

### Part 5 Subtasks: Markdown Brain Repository

- P5.1 Define markdown page path rules and slug normalization in `docs/memory-v2-contracts.md` via Agent 5 checkpoint.
- P5.2 Implement brain directory resolver with test override.
- P5.3 Add scaffolding command for required directories and starter files.
- P5.4 Implement frontmatter parser with strict validation and recoverable parse errors.
- P5.5 Implement compiled truth/timeline splitter.
- P5.6 Implement wikilink and slug link extraction.
- P5.7 Implement safe writer with expected hash check and conflict result.
- P5.8 Add templates for user, preference, project, person, company, workflow, app, website, repo, file, concept, decision, and timeline.
- P5.9 Add fixtures for valid page, missing frontmatter, duplicate divider, timeline-only page, and user-edited conflict.
- P5.10 Document manual editing rules and conflict behavior.

Compatibility dependencies:

- Must not index into PGlite directly except through Part 6.
- Must not invent entity types outside the shared contracts.
- Must preserve user formatting as much as practical to reduce markdown churn.

### Part 6 Subtasks: Markdown Indexing and Promotion Pipeline

- P6.1 Implement brain page scanner using Part 5 parser output.
- P6.2 Implement content hash and skip unchanged files.
- P6.3 Upsert `brain_pages` and delete or mark removed pages according to schema contract.
- P6.4 Chunk frontmatter, compiled truth, and timeline sections with stable chunk ids.
- P6.5 Embed changed chunks and validate embedding dimensions against store config.
- P6.6 Emit graph extraction job request for changed pages, but do not call graph internals directly.
- P6.7 Implement promotion candidate detector from recent summaries and repeated recent context evidence.
- P6.8 Implement promotion draft format with target slug, suggested edit, timeline entry, confidence, and evidence ids.
- P6.9 Implement conservative apply path only for explicit user-approved drafts.
- P6.10 Add re-index command and fixtures for changed page, deleted page, renamed slug, and promotion draft.

Compatibility dependencies:

- Must consume Part 5 parser output and Part 2 schema constants.
- Must produce graph extraction inputs compatible with Part 7.
- Must not silently edit user markdown without expected hash or explicit promotion approval.

### Part 7 Subtasks: Entity and Relation Extraction

- P7.1 Implement canonical entity key builder for each entity type.
- P7.2 Implement alias upsert with normalized aliases and source evidence.
- P7.3 Extract entities from recent context structured fields.
- P7.4 Extract entities from markdown frontmatter, slug, title, wikilinks, and links.
- P7.5 Extract deterministic relations from recent context events.
- P7.6 Extract deterministic relations from markdown pages and timeline events.
- P7.7 Implement evidence object writer with source type, source id, excerpt/hash, and timestamp.
- P7.8 Implement confidence scoring and repeated-evidence strengthening.
- P7.9 Implement LLM-assisted extraction adapter behind disabled feature flag.
- P7.10 Add idempotent extraction command for event id, page id, and full backfill.
- P7.11 Add fixtures for project-app, project-repo, website-visit, file-opened, decision-evidence, and preference-evidence.

Compatibility dependencies:

- Must use entity and relation enums from shared contracts.
- Must not run graph traversal or ranking logic; that belongs to Part 8.
- Must not parse markdown independently; consume Part 5/6 parsed/indexed output.

### Part 8 Subtasks: Graph-Aware Retrieval

- P8.1 Implement entity lookup from query text using aliases and slugs.
- P8.2 Implement bounded graph traversal with depth, direction, relation type filter, and cycle prevention.
- P8.3 Implement graph result DTO matching shared contracts.
- P8.4 Implement vector search over recent summaries and brain chunks.
- P8.5 Implement keyword search over recent summaries, recent events, and brain chunks.
- P8.6 Implement RRF merge across vector, keyword, and graph candidate lists.
- P8.7 Add ranking boosts for compiled truth, graph neighbors, backlinks, evidence confidence, and recency.
- P8.8 Add score explanation in debug mode.
- P8.9 Implement `/v2/search` service handler or service function consumed by Part 9.
- P8.10 Add relation-focused tests: "what did we decide", "what project uses this repo", "what sites are connected to this workflow".
- P8.11 Add performance guard tests for traversal caps and result limits.

Compatibility dependencies:

- Must return the v2 search shape exactly.
- Must not introduce new endpoint response fields without Agent 5 contract update.
- Must not mutate graph state during retrieval.

### Part 9 Subtasks: Memory v2 API Cutover and Swift Client Update

- P9.1 Write `docs/memory-v2-api.md` with endpoint list, request/response JSON, errors, auth, and status codes.
- P9.2 Write `docs/memory-v2-contracts.md` with shared enums and DTO names.
- P9.3 Create TypeScript API contract DTOs under `services/memory-pglite/src/contracts/`.
- P9.4 Create shared fixture JSON for each endpoint response.
- P9.5 Implement `/v2/health` using Part 1 and Part 2 health data.
- P9.6 Wire `/v2/recent-context` endpoints to Part 3 and Part 4.
- P9.7 Wire `/v2/brain` endpoints to Part 5 and Part 6.
- P9.8 Wire `/v2/graph/query` to Part 8 traversal API.
- P9.9 Wire `/v2/search` to Part 8 search API.
- P9.10 Wire `/v2/memories/promote` to Part 6 promotion API.
- P9.11 Update Swift `MemoryService` request methods to call v2 endpoints.
- P9.12 Update Swift memory/search/evidence/relation models to mirror fixture JSON.
- P9.13 Update Swift screens mechanically for renamed fields and source-specific display.
- P9.14 Add contract tests that decode fixture JSON in TypeScript and Swift.

Compatibility dependencies:

- Must own API contracts and fixtures, but should not own schema internals.
- Must not require v1 endpoint behavior.
- Must keep Swift model names stable after Checkpoint 3 unless downstream UI updates are included.

### Part 10 Subtasks: Tests, Migration, Documentation, and Handoff

- P10.1 Add root-level test matrix documentation with commands and expected outputs.
- P10.2 Add PGlite clean-install integration test.
- P10.3 Add end-to-end fixture load test: recent event, markdown page, graph extraction, search.
- P10.4 Add Swift compile check after Memory v2 model changes.
- P10.5 Add migration draft export from old Postgres observations when `DATABASE_URL` is provided.
- P10.6 Add import command for generated markdown drafts into `~/.aurabot/brain`.
- P10.7 Add privacy docs listing local storage paths and deletion behavior.
- P10.8 Add troubleshooting docs for PGlite startup, vector extension, stale schema, and markdown parse conflicts.
- P10.9 Add final handoff checklist per agent with completed subtasks, tests run, and open contract changes.
- P10.10 Add release checklist that confirms v1 is not required for the Memory v2 happy path.

Compatibility dependencies:

- Must not change implementation contracts without updating Agent 5-owned docs and fixtures.
- Must verify all agent-owned smoke tests in one clean run.
- Must document any remaining temporary legacy code clearly.

### Required Agent Handoff Note

Every agent should end its work with a short handoff note using this shape:

```text
Agent:
Parts:
Completed subtasks:
Files changed:
Contract files changed:
New enum values:
New table columns/indexes:
New endpoints or response fields:
Fixtures added/updated:
Tests run:
Known blockers:
Integration notes for other agents:
```

Compatibility rule:

```text
If "Contract files changed", "New enum values", "New table columns/indexes", or
"New endpoints or response fields" is non-empty, the agent must identify which
other parts need to consume the change before final integration.
```

## Part 1: PGlite Runtime Foundation

Owner: Agent 1

Primary write scope:

- `services/memory-pglite/`
- `package.json` only if a root package already exists or is needed for workspace scripts
- `Makefile` only for new non-breaking helper commands

Objective:

Create the PGlite runtime used by AuraBot Memory v2.

Implementation tasks:

- Create a TypeScript or Bun service under `services/memory-pglite/`.
- Add PGlite dependency and initialize a persistent local database at `~/.aurabot/pglite/aurabot`.
- Enable the `vector` extension.
- Create a small database wrapper with:
  - `initDatabase()`
  - `query()`
  - `transaction()`
  - `close()`
- Add a database path resolver that respects:
  - `AURABOT_HOME`
  - default `~/.aurabot`
  - test override path
- Add a CLI smoke command:
  - initialize database
  - run `SELECT 1`
  - verify vector extension can be created
- Keep the service independent from Python so it can be tested alone.

Deliverables:

- PGlite service skeleton.
- Database initialization module.
- Smoke test or script.
- README section inside `services/memory-pglite/README.md`.

Acceptance criteria:

- A clean checkout can initialize a local PGlite database without external Postgres.
- Vector extension setup is verified by an automated smoke test.
- This part does not need to preserve Python API behavior.

Risks:

- PGlite is primarily JavaScript/TypeScript, so avoid forcing it through Python wrappers for production.
- Do not assume multi-process writes are safe until confirmed. Route writes through one service process.

## Part 2: PGlite Schema and Migrations

Owner: Agent 1

Primary write scope:

- `services/memory-pglite/src/schema/`
- `services/memory-pglite/src/migrations/`
- `services/memory-pglite/tests/schema/`

Objective:

Define the complete local schema for recent context, markdown brain pages, chunks, entities, graph relations, and store metadata.

Tables:

```text
memory_store_config
recent_context_events
recent_context_summaries
brain_pages
brain_chunks
entities
entity_aliases
entity_links
timeline_events
memory_jobs
```

Required table responsibilities:

- `recent_context_events`: raw last-6-hours context from screen/app/browser/repo/file activity.
- `recent_context_summaries`: compact time-window summaries generated from raw events.
- `brain_pages`: one row per markdown page, including slug, path, type, title, frontmatter, content hash, and timestamps.
- `brain_chunks`: searchable chunks from compiled truth and timeline sections, with embeddings.
- `entities`: canonical graph nodes.
- `entity_aliases`: alternate names, domains, paths, repo names, and normalized lookup keys.
- `entity_links`: typed directed graph edges with confidence and evidence pointers.
- `timeline_events`: dated evidence extracted from markdown timelines and promoted facts.
- `memory_jobs`: durable background jobs for indexing, summarization, graph extraction, and cleanup.

Index requirements:

- Time index for recent context by `user_id`, `agent_id`, `created_at`.
- Full-text index for recent context and brain chunks.
- Vector index for embeddings.
- Unique slug index for brain pages.
- Unique entity key index per user.
- Unique graph edge index on `user_id`, `source_entity_id`, `target_entity_id`, `relation_type`, and evidence key where applicable.

Deliverables:

- Versioned migration runner.
- Initial schema migration.
- Schema tests that assert tables and indexes exist.
- Seed helpers for tests.

Acceptance criteria:

- Migrations are idempotent.
- A new PGlite database can migrate from empty to current schema.
- Tests can create, query, and clean all core tables.

Risks:

- PGlite extension support should be verified for the exact vector index syntax before relying on HNSW-specific syntax.
- If an index type is unsupported locally, use exact vector search first and leave approximate indexing as a follow-up.

## Part 3: Recent Context Ingestion

Owner: Agent 2

Primary write scope:

- `services/memory-pglite/src/recent/`
- `services/memory-pglite/tests/recent/`

Objective:

Store high-volume recent context in PGlite with a 6-hour operational horizon.

Implementation tasks:

- Define `RecentContextEvent` payload:
  - `id`
  - `user_id`
  - `agent_id`
  - `created_at`
  - `source`
  - `app_name`
  - `window_title`
  - `url`
  - `domain`
  - `repo_path`
  - `file_path`
  - `screen_summary`
  - `activities`
  - `key_elements`
  - `user_intent`
  - `metadata`
  - `embedding`
- Implement insert path for the new Memory v2 event payload.
- Add direct `POST /v2/recent-context` handler in the PGlite service.
- Add TTL cleanup for events older than 6 hours by default.
- Add config for retention:
  - `AURABOT_RECENT_CONTEXT_HOURS`, default `6`.
- Add query helpers:
  - by time range
  - by app/domain/repo
  - by entity id once graph extraction is available

Deliverables:

- Recent context ingestion module.
- Tests for insert, retrieve, TTL cleanup, and metadata preservation.
- Memory v2 payload parser for recent context events.

Acceptance criteria:

- The updated macOS Memory v2 client can write recent context without relying on the old v1 memory payload.
- Recent context can be searched by timestamp and basic metadata.
- Cleanup does not delete long-term markdown brain rows.

Risks:

- Do not embed huge raw screenshots. Store summaries and structured metadata only.
- Do not store sensitive raw screen text beyond current AuraBot behavior unless the user explicitly enables it.

## Part 4: Rolling Recent Context Summaries

Owner: Agent 2

Primary write scope:

- `services/memory-pglite/src/recent/`
- `services/memory-pglite/src/jobs/`
- `services/memory-pglite/tests/recent/`

Objective:

Compress noisy recent context into useful 15-30 minute summaries while preserving raw events for the 6-hour window.

Implementation tasks:

- Add summary job:
  - input: user id, agent id, time window
  - output: summary row in `recent_context_summaries`
- Default summary windows:
  - 15 minutes for active work
  - 30 minutes for idle/low-change periods
- Summary fields:
  - `summary`
  - `active_apps`
  - `websites`
  - `repos`
  - `files`
  - `projects`
  - `people`
  - `decisions`
  - `open_questions`
  - `source_event_ids`
  - `embedding`
- Add dedupe logic so repeated screen captures do not create repeated summaries.
- Add "current context packet" helper:
  - last summary
  - last N raw events
  - active graph entities

Deliverables:

- Summary job implementation.
- Current context packet API.
- Tests for summary windowing and dedupe.

Acceptance criteria:

- A query can retrieve a compact description of the last 6 hours without reading every raw event.
- Summary generation is idempotent for the same time window.
- The summarizer can run without blocking memory ingestion.

Risks:

- If LLM summarization is unavailable, provide deterministic fallback summaries from metadata.
- Keep summarization jobs bounded so they do not process unlimited event history.

## Part 5: Markdown Brain Repository

Owner: Agent 3

Primary write scope:

- `services/memory-pglite/src/brain/`
- `services/memory-pglite/templates/brain/`
- `services/memory-pglite/tests/brain/`
- Documentation files specific to markdown brain behavior

Objective:

Create and manage `~/.aurabot/brain` as the durable source of truth for long-term memory.

Implementation tasks:

- Add brain path resolver:
  - `AURABOT_BRAIN_DIR`
  - fallback `~/.aurabot/brain`
- Add initial file scaffolding:
  - `USER.md`
  - `PREFERENCES.md`
  - `projects/`
  - `people/`
  - `companies/`
  - `workflows/`
  - `apps/`
  - `websites/`
  - `repos/`
  - `files/`
  - `concepts/`
  - `decisions/`
  - `timelines/`
- Implement markdown parser:
  - YAML frontmatter
  - compiled truth section
  - timeline section split by `---`
  - wikilinks or slug links if present
- Implement safe writer:
  - preserves timeline history
  - updates frontmatter `updated_at`
  - avoids overwriting user edits when content hash changed unexpectedly
- Add page templates for each entity type.

Deliverables:

- Brain repository initialization.
- Markdown parser and writer.
- Page templates.
- Tests for parsing, scaffolding, and safe writes.

Acceptance criteria:

- Running init creates a readable markdown brain directory.
- Existing user-edited markdown is not overwritten silently.
- Parsed markdown can be indexed by Part 6 without file-format ambiguity.

Risks:

- Do not use markdown for raw high-volume recent context.
- Avoid formatting churn when updating files.

## Part 6: Markdown Indexing and Promotion Pipeline

Owner: Agent 3

Primary write scope:

- `services/memory-pglite/src/brain/`
- `services/memory-pglite/src/indexing/`
- `services/memory-pglite/tests/indexing/`

Objective:

Index markdown brain pages into PGlite and promote stable facts from recent context into durable pages.

Implementation tasks:

- Implement `sync_brain_pages`:
  - scan markdown files
  - compute content hash
  - upsert `brain_pages`
  - chunk compiled truth and timeline sections
  - embed changed chunks
  - delete stale chunks for removed pages
- Add chunk types:
  - `compiled_truth`
  - `timeline`
  - `frontmatter`
- Implement promotion candidate detector:
  - recurring project references
  - repeated people/company mentions
  - explicit user preferences
  - explicit decisions
  - stable workflows
- Implement promotion draft output first:
  - suggested target page
  - suggested compiled truth edit
  - suggested timeline entry
  - evidence event ids
- Add manual or controlled auto-promotion setting:
  - default should be conservative

Deliverables:

- Markdown sync/indexer.
- Embedding integration for chunks.
- Promotion candidate module.
- Tests for unchanged file skip, changed file re-index, stale deletion, and promotion drafts.

Acceptance criteria:

- Edited markdown becomes searchable after sync.
- Search results can identify whether a hit came from compiled truth or timeline evidence.
- Promotion candidates always include evidence.

Risks:

- Auto-promotion can corrupt long-term memory if too aggressive. Start with draft mode or high-confidence rules only.
- Embedding dimensions must match store config.

## Part 7: Entity and Relation Extraction

Owner: Agent 4

Primary write scope:

- `services/memory-pglite/src/graph/`
- `services/memory-pglite/tests/graph/`

Objective:

Extract canonical entities and typed graph relations from recent context and markdown brain pages.

Implementation tasks:

- Implement deterministic entity extraction:
  - app names
  - browser domains
  - URLs
  - repo paths
  - file paths
  - markdown page slugs
  - wikilinks
  - frontmatter title/type
- Implement deterministic relation extraction:
  - recent event `uses` app
  - recent event `visited` website
  - recent event `opened` file
  - recent event `edited` file when metadata says edit
  - markdown page `mentions` linked pages
  - project `uses` repo/app/website from frontmatter or links
  - timeline event `evidence_for` decision/preference/relation
- Add alias normalization:
  - lowercase keys
  - URL domain normalization
  - file path normalization
  - repo name extraction
- Add LLM-assisted extraction hook behind an interface:
  - disabled by default
  - must return evidence-backed entities and relations
- Add confidence scoring:
  - deterministic exact evidence: high
  - repeated evidence: higher
  - LLM-only with weak evidence: low

Deliverables:

- Entity extraction module.
- Relation extraction module.
- Alias resolver.
- Tests with recent context payloads and markdown pages.

Acceptance criteria:

- Same entity mention resolves to the same canonical entity.
- Every edge has at least one evidence pointer.
- Re-running extraction is idempotent.

Risks:

- Entity explosion from noisy screen text. Start with structured fields first, not arbitrary text.
- Keep relation vocabulary closed initially to preserve search quality.

## Part 8: Graph-Aware Retrieval

Owner: Agent 4

Primary write scope:

- `services/memory-pglite/src/search/`
- `services/memory-pglite/src/graph/`
- `services/memory-pglite/tests/search/`

Objective:

Use graph relations during search so AuraBot can answer relational and context-linked questions better than vector search alone.

Implementation tasks:

- Implement query entity detection:
  - direct slug match
  - alias match
  - domain/path/repo match
  - title match
- Implement graph traversal:
  - depth limit default 2
  - max depth hard cap 4 for local API unless explicitly configured
  - direction: `in`, `out`, `both`
  - relation type filter
  - cycle prevention
- Implement graph result payload:
  - matched entities
  - traversed relations
  - evidence pages/events
- Add ranking boosts:
  - compiled truth boost
  - recent context boost
  - graph-neighbor boost
  - backlink/inbound-link boost
  - evidence confidence boost
- Merge ranking with:
  - vector score
  - keyword score
  - reciprocal rank fusion
  - recency boost
- Add query modes:
  - `recent`
  - `long_term`
  - `graph`
  - `all`

Deliverables:

- Graph traversal API.
- Graph-aware search pipeline.
- Ranking tests with deterministic fixture data.

Acceptance criteria:

- A query about a known project retrieves connected apps, repos, files, decisions, and timelines.
- A relational query can return graph evidence even when vector similarity is weak.
- Search returns the v2-native result shape with source, evidence, relations, and score breakdowns.

Risks:

- Ranking can become hard to debug. Include per-result ranking explanation metadata in debug mode.
- Graph traversal must be bounded to avoid slow or huge responses.

## Part 9: Memory v2 API Cutover and Swift Client Update

Owner: Agent 5

Primary write scope:

- `services/memory-pglite/src/server.ts`
- `services/memory-pglite/src/contracts/`
- `services/memory-pglite/tests/server/`
- `apps/macos/Sources/AuraBot/Services/MemoryService.swift`
- `apps/macos/Sources/AuraBot/Models/Memory.swift`
- `apps/macos/Sources/AuraBot/Screens/`

Objective:

Cut AuraBot over to the new Memory v2 API and update the macOS client to use the new contracts directly.

Implementation tasks:

- Add backend selection config:
  - `AURABOT_MEMORY_BACKEND=pglite`
  - PGlite is the canonical local backend.
  - Existing Postgres support, if retained temporarily, is only for import, migration, or rollback.
- Add PGlite service startup strategy:
  - embedded child process
  - or documented separate process
  - health check from the macOS app supervisor
- Add canonical v2 endpoints:
  - `GET /v2/health`
  - `POST /v2/recent-context`
  - `GET /v2/recent-context/current`
  - `GET /v2/recent-context/events`
  - `DELETE /v2/recent-context/events/{id}`
  - `POST /v2/brain/sync`
  - `GET /v2/brain/pages`
  - `GET /v2/brain/pages/{slug}`
  - `PUT /v2/brain/pages/{slug}`
  - `POST /v2/graph/query`
  - `POST /v2/search`
  - `POST /v2/memories/promote`
  - `DELETE /v2/memories/{id}`
- Update health output to show:
  - active backend
  - PGlite path when active
  - brain dir
  - graph enabled
  - recent context retention hours
- Update Swift client models and calls:
  - replace old `MemoryService.add/search/getRecent/delete` payloads with v2 payloads.
  - add source/evidence/relation fields to decoded results.
  - update UI call sites only where model names or result structure changed.

Deliverables:

- Memory v2 API bridge.
- Updated Swift MemoryService and memory models.
- v2 endpoint tests.
- UI compile fixes for the new models.

Acceptance criteria:

- macOS app calls the v2 API directly.
- v2 health accurately reports PGlite status.
- The app can run locally without external Postgres when PGlite backend is selected.
- No task in this part is blocked on preserving `/v1/memories` compatibility.

Risks:

- Starting and supervising the TypeScript/Node sidecar from the macOS app can be brittle. Keep explicit logs and health checks.
- Swift model changes can cascade through screens. Keep UI changes mechanical and scoped to compiling the new v2 result structures.

## Part 10: Tests, Migration, Documentation, and Agent Handoff

Owner: Agent 5

Primary write scope:

- `tests/`
- `services/memory-pglite/tests/`
- `README.md`
- `docs/`
- `.env.example`
- `config/config.yaml.example`
- this file, only for status updates and resolved contract changes

Objective:

Make the feature verifiable, migratable, and safe for multi-agent development.

Implementation tasks:

- Add integration test matrix:
  - PGlite init smoke test
  - PGlite recent context write/read/delete
  - Memory v2 search
  - markdown sync
  - graph extraction
  - graph-aware search
  - recent context TTL
  - Swift package compile after Memory v2 model updates
- Add migration/import tools:
  - import old Postgres `observations` into recent context or brain timeline candidates when a legacy database is available
  - export old DB memories to markdown drafts
  - re-index markdown brain directory
- Add docs:
  - local-first setup
  - PGlite backend selection
  - markdown brain format
  - graph relation model
  - privacy and deletion behavior
  - troubleshooting
- Add `.env.example` and config updates:
  - `AURABOT_MEMORY_BACKEND`
  - `AURABOT_HOME`
  - `AURABOT_BRAIN_DIR`
  - `AURABOT_PGLITE_DIR`
  - `AURABOT_RECENT_CONTEXT_HOURS`
  - graph/search feature flags
- Add release checklist:
  - Memory v2 happy path works without old backend endpoints
  - PGlite backend works from clean install
  - markdown edits sync
  - graph search returns evidence
  - no raw screenshots are written to markdown

Deliverables:

- Integration tests.
- Migration scripts or documented commands.
- Updated setup docs.
- Final handoff checklist.

Acceptance criteria:

- A new developer can enable PGlite from docs without installing external Postgres.
- CI can validate schema, indexing, graph search, and v2 API behavior.
- Existing users have a documented path to migrate old memory data into PGlite/markdown drafts.

Risks:

- Migration from old memories to curated markdown should not be fully automatic by default. Generate drafts first.
- Documentation must be explicit about where private data is stored.

## Suggested Execution Order

1. Part 1: PGlite Runtime Foundation
2. Part 2: PGlite Schema and Migrations
3. Part 3: Recent Context Ingestion
4. Part 5: Markdown Brain Repository
5. Part 7: Entity and Relation Extraction
6. Part 6: Markdown Indexing and Promotion Pipeline
7. Part 4: Rolling Recent Context Summaries
8. Part 8: Graph-Aware Retrieval
9. Part 9: Memory v2 API Cutover and Swift Client Update
10. Part 10: Tests, Migration, Documentation, and Agent Handoff

Parallelization plan:

- Agent 1 can start Parts 1-2 immediately.
- Agent 3 can start Part 5 immediately because markdown parsing is independent of PGlite schema if it uses local fixtures.
- Agent 4 can start Part 7 with fixture inputs and an agreed graph contract.
- Agent 2 should start Part 3 after Agent 1 lands the initial schema, but can draft payload types earlier.
- Agent 5 should start Part 10 early for config/docs, then Part 9 after the PGlite service exposes stable health and memory operations.

## Cross-Agent Interface Checkpoints

Checkpoint A: after Part 2

- Confirm table names, columns, and migration runner.
- Confirm vector extension support and fallback search behavior.

Checkpoint B: after Parts 3, 5, and 7 have fixtures

- Confirm recent context payload shape.
- Confirm markdown parser output shape.
- Confirm entity/relation extraction input and output shape.

Checkpoint C: before Part 8

- Confirm graph traversal SQL and relation vocabulary.
- Confirm ranking fields and debug metadata.

Checkpoint D: before Part 9

- Confirm PGlite service API:
  - health
  - add memory
  - get recent
  - search
  - delete
  - sync brain
  - graph query

Checkpoint E: before merge/release

- Run full test matrix.
- Verify clean install.
- Verify migration/draft export path.
- Verify privacy-sensitive storage locations are documented.

## Minimal Vertical Slice

Before building everything, prove this path end to end:

```text
1. Initialize PGlite database.
2. Add one recent context event through the v2 API.
3. Store it as a recent context event.
4. Create or edit one markdown page under ~/.aurabot/brain/projects/aurabot.md.
5. Sync markdown into PGlite chunks.
6. Extract one project entity and one relation.
7. Search "what did we decide about memory storage?"
8. Return both recent context and markdown brain evidence.
```

This slice should be treated as the first integration milestone.

## Open Questions

- Should the PGlite service run as a separate Node process, or should the macOS app supervisor keep owning it as a managed child process?
- Should markdown promotion require user approval in the macOS UI, or should high-confidence preferences/decisions be auto-promoted?
- Should graph relations be editable directly in markdown frontmatter, or only derived from page content and timeline evidence?
- How much of the last-6-hours recent context should be exposed in UI versus only used internally for prompt enhancement?

## Recommended Defaults

- PGlite backend: canonical backend for Memory v2.
- Recent context retention: 6 hours.
- Recent context summary window: 15 minutes.
- Markdown auto-promotion: draft mode first.
- Graph extraction: deterministic first, LLM-assisted later.
- Graph traversal depth: 2 by default, hard cap 4.
- Raw screenshots: never written to markdown.
- Existing Postgres backend: migration/rollback source only, not a compatibility target.
