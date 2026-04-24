# AuraBot Memory v2 API

Memory v2 is a local-first HTTP API. It is not constrained by the deprecated v1 memory endpoints.

## Protocol

- Base path: `/v2`
- Auth: `Authorization: Bearer <api_key>` when an API key is configured. Local development may run without auth.
- Request body: JSON.
- Response body: JSON.
- Every response includes `schema_version: "memory-v2"`.
- All timestamps are ISO 8601 UTC.

## Error Shape

```json
{
  "schema_version": "memory-v2",
  "error": {
    "code": "validation_error",
    "message": "user_id is required",
    "details": {
      "field": "user_id"
    }
  },
  "request_id": "req_01",
  "generated_at": "2026-04-21T09:00:00Z"
}
```

Common status codes:

- `200`: request succeeded.
- `201`: item created.
- `202`: background job accepted.
- `204`: delete succeeded with no body, unless the caller requests a delete report.
- `400`: validation error.
- `401`: missing or invalid API key.
- `404`: item not found.
- `409`: idempotency or expected-hash conflict.
- `422`: parse or contract violation.
- `500`: internal error.
- `503`: dependency or database not ready.

## GET /v2/health

Returns service, database, vector, and schema status. Part 1 owns runtime readiness; Part 2 owns migration status.

Response fixture: `health-response.json`

```json
{
  "schema_version": "memory-v2",
  "status": "ok",
  "service": {
    "name": "aurabot-memory-pglite",
    "version": "0.1.0"
  },
  "migration_version": "0001",
  "database": {
    "path": "~/.aurabot/pglite/aurabot",
    "schema_ready": true,
    "vector_ready": true
  },
  "checks": [
    {
      "name": "database",
      "status": "ok",
      "message": "PGlite query succeeded"
    }
  ],
  "generated_at": "2026-04-21T09:00:00Z"
}
```

## POST /v2/recent-context

Adds one recent context event. This is the v2 replacement for the app's old `POST /v1/memories/` capture path.

Request:

```json
{
  "user_id": "default_user",
  "agent_id": "screen_memories_v3",
  "idempotency_key": "ctx_default_user_20260421T090000Z",
  "source": "browser",
  "content": "Reading AuraBot Memory v2 implementation plan.",
  "occurred_at": "2026-04-21T09:00:00Z",
  "ttl_seconds": 21600,
  "importance": 0.62,
  "metadata": {
    "context": "Browse",
    "activities": ["reading"],
    "key_elements": ["Memory v2", "contracts"],
    "user_intent": "implementation planning",
    "display_num": 1,
    "browser": "Safari",
    "url": "https://example.test/aurabot/memory-v2",
    "capture_reason": "browser_context"
  }
}
```

Response fixture: `recent-context-event-response.json`

```json
{
  "schema_version": "memory-v2",
  "event": {
    "id": "ctx_20260421_0001",
    "user_id": "default_user",
    "agent_id": "screen_memories_v3",
    "source": "browser",
    "content": "Reading AuraBot Memory v2 implementation plan.",
    "content_hash": "sha256:ctx0001",
    "occurred_at": "2026-04-21T09:00:00Z",
    "created_at": "2026-04-21T09:00:03Z",
    "ttl_seconds": 21600,
    "importance": 0.62,
    "metadata": {}
  }
}
```

## GET /v2/recent-context

Lists recent context events.

Query parameters:

- `user_id` required.
- `agent_id` optional.
- `started_at` optional ISO 8601 UTC.
- `ended_at` optional ISO 8601 UTC.
- `source` optional `RecentContextSource`.
- `app`, `domain`, `repo_path`, and `file_path` optional.
- `limit` optional, default `50`, max `200`.

Response fixture: `recent-context-list-response.json`

```json
{
  "schema_version": "memory-v2",
  "items": [],
  "debug": {
    "range": {
      "started_at": null,
      "ended_at": null
    }
  }
}
```

## GET /v2/current-context

Returns the current context packet for an agent.

Query parameters:

- `user_id` required.
- `agent_id` optional.

Response fixture: `current-context-response.json`

## POST /v2/recent-context/summaries

Creates or retrieves an idempotent rolling summary for a time window. By default,
the API also writes the summary to a generated Markdown page at
`timelines/recent-context/{user}/{agent}/current.md` and syncs it into the brain
index. This improves retrieval without turning every raw recent event into a
Markdown source-of-truth file.

Request:

```json
{
  "user_id": "default_user",
  "agent_id": "screen_memories_v3",
  "idempotency_key": "summary_default_user_20260421T090000Z_20260421T093000Z",
  "window": {
    "started_at": "2026-04-21T09:00:00Z",
    "ended_at": "2026-04-21T09:30:00Z"
  },
  "mode": "deterministic",
  "write_markdown": true
}
```

Response shape matches `CurrentContextPacket` with a stored summary id in
`metadata.summary_id`. When Markdown was written, `metadata.markdown` contains
`root_dir`, `path`, `slug`, `content_hash`, `generated_at`, and `synced`.

## POST /v2/brain/sync

Scans markdown brain pages, updates the PGlite index, and enqueues graph extraction for changed pages.

Request:

```json
{
  "user_id": "default_user",
  "idempotency_key": "brain_sync_default_user_20260421T090000Z",
  "paths": ["projects/aurabot.md"],
  "dry_run": false
}
```

Response fixture: `brain-sync-response.json`

```json
{
  "schema_version": "memory-v2",
  "job": {
    "id": "job_brain_sync_0001",
    "status": "succeeded",
    "idempotency_key": "brain_sync_default_user_20260421T090000Z"
  },
  "synced_pages": [],
  "errors": []
}
```

## GET /v2/brain/pages/{slug}

Returns indexed page metadata and chunks for a markdown brain page. Slugs use the rules in `docs/memory-v2-contracts.md`.

Response:

```json
{
  "schema_version": "memory-v2",
  "page": {
    "id": "page_projects_aurabot",
    "user_id": "default_user",
    "type": "project",
    "title": "AuraBot",
    "slug": "projects/aurabot",
    "path": "projects/aurabot.md",
    "source_hash": "sha256:page0001",
    "updated_at": "2026-04-21T08:45:00Z",
    "metadata": {}
  },
  "chunks": []
}
```

## POST /v2/graph/query

Runs bounded graph traversal.

Request:

```json
{
  "user_id": "default_user",
  "start": "ent_project_aurabot",
  "relation_types": ["uses", "decided_in"],
  "depth": 2,
  "direction": "both",
  "limit": 50
}
```

Response fixture: `graph-query-response.json`

## POST /v2/search

Runs graph-aware memory retrieval across recent context, summaries, brain pages, brain chunks, and graph candidates.

Request:

```json
{
  "query": "what did we decide about memory storage?",
  "user_id": "default_user",
  "agent_id": "screen_memories_v3",
  "scopes": ["recent_summary", "brain_chunk", "graph"],
  "limit": 10,
  "debug": true
}
```

Response fixture: `search-response.json`

The response shape is exactly:

```json
{
  "schema_version": "memory-v2",
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

## POST /v2/memories/promote

Creates a markdown promotion draft or applies a user-approved draft.

Request:

```json
{
  "user_id": "default_user",
  "candidate_id": "candidate_memory_storage_decision",
  "mode": "draft",
  "idempotency_key": "promote_candidate_memory_storage_decision_draft"
}
```

Response fixture: `promotion-response.json`

## DELETE /v2/memories/{source}/{id}

Deletes or tombstones a memory item by source.

Supported `source` values are listed as `DeleteSource` in `docs/memory-v2-contracts.md`.

Query parameters:

- `user_id` required.
- `expected_hash` optional but recommended for markdown-backed sources.

Response fixture: `delete-response.json`

```json
{
  "schema_version": "memory-v2",
  "deleted": true,
  "source": "recent_context",
  "id": "ctx_20260421_0001",
  "generated_at": "2026-04-21T09:31:00Z"
}
```
