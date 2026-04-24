# AuraBot Memory v2 Schema

Owner: Agent 1

This document is the canonical schema reference for AuraBot Memory v2 PGlite
storage. API request/response contracts are owned separately by Agent 5 in
`docs/memory-v2-api.md` and `docs/memory-v2-contracts.md`.

## Runtime Defaults

| Setting | Default | Override |
| --- | --- | --- |
| AuraBot home | `~/.aurabot` | `AURABOT_HOME` |
| PGlite data dir | `~/.aurabot/pglite/aurabot` | `AURABOT_PGLITE_DIR` |
| Test data dir | none | `AURABOT_PGLITE_TEST_DIR` |
| Embedding dimensions | `1536` | `AURABOT_MEMORY_EMBEDDING_DIMENSIONS` |

The schema stores embedding dimensions in `memory_store_config` and refuses to
open an existing store with a different dimension count.

## Migration Tracking

Migrations are tracked in `memory_store_config`.

| Key | Meaning |
| --- | --- |
| `embedding` | Embedding dimension config for the store |
| `active_schema` | Active schema version and latest migration |
| `migration:<id>` | Applied migration metadata |

Current latest migration:

```text
001_initial_memory_v2_schema
```

## Tables

### `memory_store_config`

General key/value store for schema metadata, migration tracking, and store-level
configuration.

Key columns:

- `key TEXT PRIMARY KEY`
- `value JSONB NOT NULL`
- `created_at TIMESTAMPTZ`
- `updated_at TIMESTAMPTZ`

### `recent_context_events`

Raw short-term context events for the last operational memory window. These are
high-volume and temporary; they are not markdown source-of-truth records.

Key columns:

- `id TEXT PRIMARY KEY`
- `user_id TEXT NOT NULL`
- `agent_id TEXT`
- `source TEXT NOT NULL`
- `app_name TEXT`
- `window_title TEXT`
- `url TEXT`
- `domain TEXT`
- `repo_path TEXT`
- `file_path TEXT`
- `screen_summary TEXT`
- `activities JSONB`
- `key_elements JSONB`
- `user_intent TEXT`
- `metadata JSONB`
- `embedding vector(dimensions)`
- `content_hash TEXT`
- `idempotency_key TEXT`
- `created_at TIMESTAMPTZ`
- `updated_at TIMESTAMPTZ`

Primary indexes:

- `idx_recent_context_user_agent_created`
- `idx_recent_context_source_created`
- `idx_recent_context_domain`
- `idx_recent_context_repo`
- `idx_recent_context_idempotency`
- `idx_recent_context_metadata`
- Optional `idx_recent_context_embedding`

### `recent_context_summaries`

Rolling summaries over recent events. These are used to avoid rereading every raw
event when building current context.

When summary creation is requested through the API, the service also writes a
generated Markdown mirror under
`~/.aurabot/brain/timelines/recent-context/{user}/{agent}/current.md` and syncs
that page into `brain_pages`/`brain_chunks`. Raw recent events remain in
`recent_context_events`; only the rolling summary page is mirrored into Markdown.

Key columns:

- `id TEXT PRIMARY KEY`
- `user_id TEXT NOT NULL`
- `agent_id TEXT`
- `window_started_at TIMESTAMPTZ NOT NULL`
- `window_ended_at TIMESTAMPTZ NOT NULL`
- `summary TEXT NOT NULL`
- `active_apps JSONB`
- `websites JSONB`
- `repos JSONB`
- `files JSONB`
- `projects JSONB`
- `people JSONB`
- `decisions JSONB`
- `open_questions JSONB`
- `source_event_ids JSONB`
- `metadata JSONB`
- `embedding vector(dimensions)`
- `source_hash TEXT NOT NULL`
- `generated_by TEXT`
- `generated_at TIMESTAMPTZ`
- `created_at TIMESTAMPTZ`
- `updated_at TIMESTAMPTZ`

Uniqueness:

- `(user_id, agent_id, window_started_at, window_ended_at, source_hash)`

Primary indexes:

- `idx_recent_summaries_user_agent_window`
- Optional `idx_recent_summaries_embedding`

### `brain_pages`

One row per markdown source-of-truth page in `~/.aurabot/brain`.

Key columns:

- `id TEXT PRIMARY KEY`
- `user_id TEXT NOT NULL`
- `slug TEXT NOT NULL`
- `path TEXT NOT NULL`
- `page_type TEXT NOT NULL`
- `title TEXT NOT NULL`
- `frontmatter JSONB`
- `compiled_truth TEXT`
- `timeline_text TEXT`
- `content_hash TEXT NOT NULL`
- `source_hash TEXT NOT NULL`
- `last_indexed_at TIMESTAMPTZ`
- `created_at TIMESTAMPTZ`
- `updated_at TIMESTAMPTZ`

Uniqueness:

- `(user_id, slug)`

Primary indexes:

- `idx_brain_pages_user_type`
- `idx_brain_pages_path`
- `idx_brain_pages_frontmatter`

### `brain_chunks`

Searchable chunks generated from markdown brain pages.

Key columns:

- `id TEXT PRIMARY KEY`
- `user_id TEXT NOT NULL`
- `page_id TEXT NOT NULL`
- `slug TEXT NOT NULL`
- `chunk_type TEXT NOT NULL`
- `chunk_index INTEGER NOT NULL`
- `content TEXT NOT NULL`
- `metadata JSONB`
- `embedding vector(dimensions)`
- `content_hash TEXT NOT NULL`
- `created_at TIMESTAMPTZ`
- `updated_at TIMESTAMPTZ`

Allowed `chunk_type` values:

- `frontmatter`
- `compiled_truth`
- `timeline`

Uniqueness:

- `(page_id, chunk_type, chunk_index)`

Primary indexes:

- `idx_brain_chunks_user_type`
- Optional `idx_brain_chunks_embedding`

### `entities`

Canonical graph nodes.

Key columns:

- `id TEXT PRIMARY KEY`
- `user_id TEXT NOT NULL`
- `entity_type TEXT NOT NULL`
- `canonical_key TEXT NOT NULL`
- `slug TEXT`
- `name TEXT NOT NULL`
- `summary TEXT`
- `metadata JSONB`
- `confidence DOUBLE PRECISION`
- `first_seen_at TIMESTAMPTZ`
- `last_seen_at TIMESTAMPTZ`
- `content_hash TEXT`
- `created_at TIMESTAMPTZ`
- `updated_at TIMESTAMPTZ`

Uniqueness:

- `(user_id, entity_type, canonical_key)`

Primary indexes:

- `idx_entities_user_type`
- `idx_entities_slug`

### `entity_aliases`

Alternate lookup names for canonical entities.

Key columns:

- `id TEXT PRIMARY KEY`
- `user_id TEXT NOT NULL`
- `entity_id TEXT NOT NULL`
- `alias TEXT NOT NULL`
- `normalized_alias TEXT NOT NULL`
- `source_type TEXT NOT NULL`
- `source_id TEXT`
- `metadata JSONB`
- `created_at TIMESTAMPTZ`
- `updated_at TIMESTAMPTZ`

Uniqueness:

- `(user_id, normalized_alias, entity_id)`

Primary indexes:

- `idx_entity_aliases_lookup`

### `entity_links`

Typed directed graph edges. Every edge should include evidence.

Key columns:

- `id TEXT PRIMARY KEY`
- `user_id TEXT NOT NULL`
- `source_entity_id TEXT NOT NULL`
- `target_entity_id TEXT NOT NULL`
- `relation_type TEXT NOT NULL`
- `confidence DOUBLE PRECISION`
- `evidence JSONB`
- `evidence_source_type TEXT`
- `evidence_source_id TEXT`
- `metadata JSONB`
- `source_hash TEXT`
- `created_at TIMESTAMPTZ`
- `updated_at TIMESTAMPTZ`

Uniqueness:

- `(user_id, source_entity_id, target_entity_id, relation_type, evidence_source_type, evidence_source_id)`

Primary indexes:

- `idx_entity_links_source`
- `idx_entity_links_target`
- `idx_entity_links_evidence`

### `timeline_events`

Dated evidence extracted from markdown timelines and promoted facts.

Key columns:

- `id TEXT PRIMARY KEY`
- `user_id TEXT NOT NULL`
- `page_id TEXT`
- `entity_id TEXT`
- `event_date DATE`
- `event_timestamp TIMESTAMPTZ`
- `summary TEXT NOT NULL`
- `evidence JSONB`
- `metadata JSONB`
- `content_hash TEXT NOT NULL`
- `created_at TIMESTAMPTZ`
- `updated_at TIMESTAMPTZ`

Uniqueness:

- `(user_id, page_id, content_hash)`

Primary indexes:

- `idx_timeline_events_user_date`

### `memory_jobs`

Durable job queue for indexing, summarization, graph extraction, cleanup, and
other deterministic background work.

Key columns:

- `id TEXT PRIMARY KEY`
- `user_id TEXT`
- `job_type TEXT NOT NULL`
- `status TEXT NOT NULL`
- `queue TEXT NOT NULL`
- `idempotency_key TEXT NOT NULL`
- `payload JSONB`
- `result JSONB`
- `error TEXT`
- `attempts INTEGER`
- `max_attempts INTEGER`
- `run_after TIMESTAMPTZ`
- `started_at TIMESTAMPTZ`
- `completed_at TIMESTAMPTZ`
- `created_at TIMESTAMPTZ`
- `updated_at TIMESTAMPTZ`

Uniqueness:

- `(job_type, idempotency_key)`

Primary indexes:

- `idx_memory_jobs_status_run_after`
- `idx_memory_jobs_user_type`

## Closed Enum Sets

### Entity Types

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

### Recent Context Sources

```text
screen
app
browser
repo
file
manual
```

### Memory Job Statuses

```text
queued
running
completed
failed
cancelled
```

## Handoff Notes

- Agent 2 should use `recent_context_events`, `recent_context_summaries`, and
  `memory_jobs`; it should not create graph rows directly.
- Agent 3 should use `brain_pages`, `brain_chunks`, `timeline_events`, and
  `memory_jobs`; it should not create endpoint DTOs.
- Agent 4 should use `entities`, `entity_aliases`, `entity_links`, and
  `timeline_events`; it should not parse markdown independently.
- Agent 5 owns HTTP/Swift contracts and should mirror this schema through DTOs
  without changing table names or enum values without a checkpoint.
