# AuraBot Memory v2 Contracts

This document is the Agent 5-owned source of truth for Memory v2 HTTP DTOs, shared enum values, fixture names, and client-facing lifecycle states. Schema tables and indexes are owned by `docs/memory-v2-schema.md`.

## Global Rules

- Every API response includes `schema_version: "memory-v2"`.
- Every timestamp is ISO 8601 UTC.
- Every enum value uses `snake_case`.
- Every persisted or re-indexable item includes `content_hash` or `source_hash` when practical.
- Every generated artifact includes `generated_by` and `generated_at` in `metadata` when practical.
- Every graph edge includes `evidence` with source id and source type.
- Every background job includes `idempotency_key`.

## Enums

### EntityType

`user`, `person`, `company`, `project`, `app`, `website`, `repo`, `file`, `workflow`, `concept`, `decision`, `task`, `meeting`, `document`, `preference`

### RelationType

`works_on`, `uses`, `visited`, `opened`, `edited`, `mentioned_in`, `discussed_with`, `decided_in`, `evidence_for`, `related_to`, `depends_on`, `blocks`, `belongs_to`, `part_of`, `authored`, `created`, `prefers`

### MemorySource

`recent_context`, `recent_summary`, `brain_page`, `brain_chunk`, `graph`

### RecentContextSource

`screen`, `app`, `browser`, `repo`, `file`, `terminal`, `system`

### JobStatus

`queued`, `running`, `succeeded`, `failed`, `cancelled`, `skipped`

### PromotionMode

`draft`, `apply`

### DeleteSource

`recent_context`, `recent_summary`, `brain_page`, `brain_chunk`, `graph`, `timeline_event`, `promotion_candidate`

## Common DTOs

### Evidence

```json
{
  "source": "recent_context",
  "source_id": "ctx_20260421_0001",
  "excerpt": "User decided AuraBot memory storage should be local-first.",
  "content_hash": "sha256:8f2f...",
  "created_at": "2026-04-21T00:00:00Z",
  "metadata": {}
}
```

Required fields: `source`, `source_id`. `excerpt`, `content_hash`, `created_at`, and `metadata` are optional but recommended when the producer has them.

### MemoryScoreBreakdown

```json
{
  "vector": 0.74,
  "keyword": 0.62,
  "graph": 0.88,
  "recency": 0.41
}
```

### RelationRef

```json
{
  "id": "link_project_repo",
  "relation_type": "uses",
  "source_entity_id": "ent_project_aurabot",
  "target_entity_id": "ent_repo_aurabot",
  "confidence": 0.92,
  "evidence": []
}
```

### RecentContextEvent

```json
{
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

### CurrentContextPacket

```json
{
  "schema_version": "memory-v2",
  "user_id": "default_user",
  "agent_id": "screen_memories_v3",
  "generated_at": "2026-04-21T09:30:00Z",
  "window": {
    "started_at": "2026-04-21T09:00:00Z",
    "ended_at": "2026-04-21T09:30:00Z"
  },
  "summary": "Working on AuraBot Memory v2 contracts.",
  "recent_events": [],
  "active_entities": [],
  "metadata": {}
}
```

### SearchMemoryItem

```json
{
  "id": "brain_chunk_projects_aurabot_summary",
  "source": "brain_chunk",
  "content": "AuraBot Memory v2 stores durable personalization in markdown brain files.",
  "user_id": "default_user",
  "entity_ids": ["ent_project_aurabot"],
  "relations": [],
  "evidence": [],
  "score": 0.91,
  "scores": {
    "vector": 0.82,
    "keyword": 0.71,
    "graph": 0.64,
    "recency": 0.25
  },
  "created_at": "2026-04-21T08:45:00Z",
  "metadata": {
    "slug": "projects/aurabot",
    "chunk_type": "compiled_truth"
  }
}
```

### SearchMemoryResponse

```json
{
  "schema_version": "memory-v2",
  "query": "what did we decide about memory storage?",
  "items": [],
  "debug": {
    "matched_entities": [],
    "ranking": {}
  }
}
```

## Markdown Brain Rules

Brain pages live under `~/.aurabot/brain/` by default. Tests may override the root path.

Required top-level starter files and directories:

```text
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

Slug rules:

- Use lower-case path components separated by `/`.
- Use `kebab-case` inside each component.
- Allowed characters are `a-z`, `0-9`, `/`, and `-`.
- Required prefix for typed pages: `projects/`, `people/`, `companies/`, `workflows/`, `apps/`, `websites/`, `repos/`, `files/`, `concepts/`, `decisions/`, or `timelines/`.
- `USER.md` uses slug `user`; `PREFERENCES.md` uses slug `preferences`.
- Slugs must be stable. Renames should preserve the old slug as an alias until downstream indexes are rebuilt.

Path rules:

- `slug: projects/aurabot` maps to `projects/aurabot.md`.
- `slug: user` maps to `USER.md`.
- `slug: preferences` maps to `PREFERENCES.md`.
- Writers must use an expected hash check before modifying an existing page.

Generated recent-context summary pages are the exception to the user-edit
writer rule. The service owns and overwrites
`timelines/recent-context/{user}/{agent}/current.md` after each rolling summary,
then indexes it like any other brain page. These pages mirror summaries only;
raw recent events remain in PGlite.

## Fixture Set

Shared fixtures are stored in `services/memory-pglite/src/test-fixtures/`.

- `health-response.json`
- `recent-context-event-response.json`
- `recent-context-list-response.json`
- `current-context-response.json`
- `brain-sync-response.json`
- `graph-query-response.json`
- `search-response.json`
- `promotion-response.json`
- `delete-response.json`

## Integration Check Commands

These commands define the expected capabilities for final integration. The exact implementation may live in the owning agent's package scripts.

```text
memory-pglite schema:check
memory-pglite contracts:check
memory-pglite fixtures:load
memory-pglite search:smoke
memory-pglite graph:smoke
swift memory:compile
```

For this contract checkpoint, `contracts:check` means every shared fixture validates against `services/memory-pglite/src/contracts/` DTO validators, and `swift memory:compile` means the macOS Swift package compiles after decoding the shared response fixtures.
