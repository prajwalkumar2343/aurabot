import type { Migration, MigrationContext } from "../schema/migration-types.js";
import {
  BRAIN_CHUNK_TYPES,
  ENTITY_TYPES,
  MEMORY_JOB_STATUSES,
  RECENT_CONTEXT_SOURCES,
  RELATION_TYPES,
  TABLES,
} from "../schema/constants.js";

function sqlStringList(values: readonly string[]): string {
  return values.map((value) => `'${value}'`).join(", ");
}

export function initialSchemaMigration(context: MigrationContext): Migration {
  const embeddingDimensions = context.embeddingDimensions;

  return {
    id: "001_initial_memory_v2_schema",
    description:
      "Create Memory v2 PGlite tables for recent context, markdown brain pages, chunks, graph entities, graph relations, timeline evidence, and jobs.",
    statements: [
      `
        CREATE TABLE IF NOT EXISTS ${TABLES.recentContextEvents} (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          agent_id TEXT,
          source TEXT NOT NULL CHECK (source IN (${sqlStringList(RECENT_CONTEXT_SOURCES)})),
          app_name TEXT,
          window_title TEXT,
          url TEXT,
          domain TEXT,
          repo_path TEXT,
          file_path TEXT,
          screen_summary TEXT,
          activities JSONB NOT NULL DEFAULT '[]'::jsonb,
          key_elements JSONB NOT NULL DEFAULT '[]'::jsonb,
          user_intent TEXT,
          metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
          embedding vector(${embeddingDimensions}),
          content_hash TEXT,
          idempotency_key TEXT,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `,
      `
        CREATE TABLE IF NOT EXISTS ${TABLES.recentContextSummaries} (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          agent_id TEXT,
          window_started_at TIMESTAMPTZ NOT NULL,
          window_ended_at TIMESTAMPTZ NOT NULL,
          summary TEXT NOT NULL,
          active_apps JSONB NOT NULL DEFAULT '[]'::jsonb,
          websites JSONB NOT NULL DEFAULT '[]'::jsonb,
          repos JSONB NOT NULL DEFAULT '[]'::jsonb,
          files JSONB NOT NULL DEFAULT '[]'::jsonb,
          projects JSONB NOT NULL DEFAULT '[]'::jsonb,
          people JSONB NOT NULL DEFAULT '[]'::jsonb,
          decisions JSONB NOT NULL DEFAULT '[]'::jsonb,
          open_questions JSONB NOT NULL DEFAULT '[]'::jsonb,
          source_event_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
          metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
          embedding vector(${embeddingDimensions}),
          source_hash TEXT NOT NULL,
          generated_by TEXT,
          generated_at TIMESTAMPTZ,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          UNIQUE (user_id, agent_id, window_started_at, window_ended_at, source_hash)
        )
      `,
      `
        CREATE TABLE IF NOT EXISTS ${TABLES.brainPages} (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          slug TEXT NOT NULL,
          path TEXT NOT NULL,
          page_type TEXT NOT NULL CHECK (page_type IN (${sqlStringList(ENTITY_TYPES)})),
          title TEXT NOT NULL,
          frontmatter JSONB NOT NULL DEFAULT '{}'::jsonb,
          compiled_truth TEXT NOT NULL DEFAULT '',
          timeline_text TEXT NOT NULL DEFAULT '',
          content_hash TEXT NOT NULL,
          source_hash TEXT NOT NULL,
          last_indexed_at TIMESTAMPTZ,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          UNIQUE (user_id, slug)
        )
      `,
      `
        CREATE TABLE IF NOT EXISTS ${TABLES.brainChunks} (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          page_id TEXT NOT NULL REFERENCES ${TABLES.brainPages}(id) ON DELETE CASCADE,
          slug TEXT NOT NULL,
          chunk_type TEXT NOT NULL CHECK (chunk_type IN (${sqlStringList(BRAIN_CHUNK_TYPES)})),
          chunk_index INTEGER NOT NULL,
          content TEXT NOT NULL,
          metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
          embedding vector(${embeddingDimensions}),
          content_hash TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          UNIQUE (page_id, chunk_type, chunk_index)
        )
      `,
      `
        CREATE TABLE IF NOT EXISTS ${TABLES.entities} (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          entity_type TEXT NOT NULL CHECK (entity_type IN (${sqlStringList(ENTITY_TYPES)})),
          canonical_key TEXT NOT NULL,
          slug TEXT,
          name TEXT NOT NULL,
          summary TEXT NOT NULL DEFAULT '',
          metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
          confidence DOUBLE PRECISION NOT NULL DEFAULT 0.0,
          first_seen_at TIMESTAMPTZ,
          last_seen_at TIMESTAMPTZ,
          content_hash TEXT,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          UNIQUE (user_id, entity_type, canonical_key)
        )
      `,
      `
        CREATE TABLE IF NOT EXISTS ${TABLES.entityAliases} (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          entity_id TEXT NOT NULL REFERENCES ${TABLES.entities}(id) ON DELETE CASCADE,
          alias TEXT NOT NULL,
          normalized_alias TEXT NOT NULL,
          source_type TEXT NOT NULL,
          source_id TEXT,
          metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          UNIQUE (user_id, normalized_alias, entity_id)
        )
      `,
      `
        CREATE TABLE IF NOT EXISTS ${TABLES.entityLinks} (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          source_entity_id TEXT NOT NULL REFERENCES ${TABLES.entities}(id) ON DELETE CASCADE,
          target_entity_id TEXT NOT NULL REFERENCES ${TABLES.entities}(id) ON DELETE CASCADE,
          relation_type TEXT NOT NULL CHECK (relation_type IN (${sqlStringList(RELATION_TYPES)})),
          confidence DOUBLE PRECISION NOT NULL DEFAULT 0.5,
          evidence JSONB NOT NULL DEFAULT '[]'::jsonb,
          evidence_source_type TEXT,
          evidence_source_id TEXT,
          metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
          source_hash TEXT,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          UNIQUE (
            user_id,
            source_entity_id,
            target_entity_id,
            relation_type,
            evidence_source_type,
            evidence_source_id
          )
        )
      `,
      `
        CREATE TABLE IF NOT EXISTS ${TABLES.timelineEvents} (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          page_id TEXT REFERENCES ${TABLES.brainPages}(id) ON DELETE SET NULL,
          entity_id TEXT REFERENCES ${TABLES.entities}(id) ON DELETE SET NULL,
          event_date DATE,
          event_timestamp TIMESTAMPTZ,
          summary TEXT NOT NULL,
          evidence JSONB NOT NULL DEFAULT '[]'::jsonb,
          metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
          content_hash TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          UNIQUE (user_id, page_id, content_hash)
        )
      `,
      `
        CREATE TABLE IF NOT EXISTS ${TABLES.memoryJobs} (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          job_type TEXT NOT NULL,
          status TEXT NOT NULL CHECK (status IN (${sqlStringList(MEMORY_JOB_STATUSES)})),
          queue TEXT NOT NULL DEFAULT 'default',
          idempotency_key TEXT NOT NULL,
          payload JSONB NOT NULL DEFAULT '{}'::jsonb,
          result JSONB,
          error TEXT,
          attempts INTEGER NOT NULL DEFAULT 0,
          max_attempts INTEGER NOT NULL DEFAULT 3,
          run_after TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          started_at TIMESTAMPTZ,
          completed_at TIMESTAMPTZ,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          UNIQUE (job_type, idempotency_key)
        )
      `,
      `CREATE INDEX IF NOT EXISTS idx_recent_context_user_agent_created ON ${TABLES.recentContextEvents} (user_id, agent_id, created_at DESC)`,
      `CREATE INDEX IF NOT EXISTS idx_recent_context_source_created ON ${TABLES.recentContextEvents} (source, created_at DESC)`,
      `CREATE INDEX IF NOT EXISTS idx_recent_context_domain ON ${TABLES.recentContextEvents} (user_id, domain, created_at DESC) WHERE domain IS NOT NULL`,
      `CREATE INDEX IF NOT EXISTS idx_recent_context_repo ON ${TABLES.recentContextEvents} (user_id, repo_path, created_at DESC) WHERE repo_path IS NOT NULL`,
      `CREATE INDEX IF NOT EXISTS idx_recent_context_idempotency ON ${TABLES.recentContextEvents} (idempotency_key) WHERE idempotency_key IS NOT NULL`,
      `CREATE INDEX IF NOT EXISTS idx_recent_context_metadata ON ${TABLES.recentContextEvents} USING GIN (metadata)`,
      `CREATE INDEX IF NOT EXISTS idx_recent_summaries_user_agent_window ON ${TABLES.recentContextSummaries} (user_id, agent_id, window_started_at DESC, window_ended_at DESC)`,
      `CREATE INDEX IF NOT EXISTS idx_brain_pages_user_type ON ${TABLES.brainPages} (user_id, page_type, updated_at DESC)`,
      `CREATE INDEX IF NOT EXISTS idx_brain_pages_path ON ${TABLES.brainPages} (path)`,
      `CREATE INDEX IF NOT EXISTS idx_brain_pages_frontmatter ON ${TABLES.brainPages} USING GIN (frontmatter)`,
      `CREATE INDEX IF NOT EXISTS idx_brain_chunks_user_type ON ${TABLES.brainChunks} (user_id, chunk_type, updated_at DESC)`,
      `CREATE INDEX IF NOT EXISTS idx_entities_user_type ON ${TABLES.entities} (user_id, entity_type, updated_at DESC)`,
      `CREATE INDEX IF NOT EXISTS idx_entities_slug ON ${TABLES.entities} (user_id, slug) WHERE slug IS NOT NULL`,
      `CREATE INDEX IF NOT EXISTS idx_entity_aliases_lookup ON ${TABLES.entityAliases} (user_id, normalized_alias)`,
      `CREATE INDEX IF NOT EXISTS idx_entity_links_source ON ${TABLES.entityLinks} (user_id, source_entity_id, relation_type)`,
      `CREATE INDEX IF NOT EXISTS idx_entity_links_target ON ${TABLES.entityLinks} (user_id, target_entity_id, relation_type)`,
      `CREATE INDEX IF NOT EXISTS idx_entity_links_evidence ON ${TABLES.entityLinks} (user_id, evidence_source_type, evidence_source_id)`,
      `CREATE INDEX IF NOT EXISTS idx_timeline_events_user_date ON ${TABLES.timelineEvents} (user_id, event_date DESC)`,
      `CREATE INDEX IF NOT EXISTS idx_memory_jobs_status_run_after ON ${TABLES.memoryJobs} (status, run_after, queue)`,
      `CREATE INDEX IF NOT EXISTS idx_memory_jobs_user_type ON ${TABLES.memoryJobs} (user_id, job_type, created_at DESC)`,
    ],
    optionalStatements: [
      `CREATE INDEX IF NOT EXISTS idx_recent_context_embedding ON ${TABLES.recentContextEvents} USING hnsw (embedding vector_cosine_ops)`,
      `CREATE INDEX IF NOT EXISTS idx_recent_summaries_embedding ON ${TABLES.recentContextSummaries} USING hnsw (embedding vector_cosine_ops)`,
      `CREATE INDEX IF NOT EXISTS idx_brain_chunks_embedding ON ${TABLES.brainChunks} USING hnsw (embedding vector_cosine_ops)`,
    ],
  };
}
