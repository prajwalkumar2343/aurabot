import { TABLES } from "./constants.js";
import { appliedMigrations, latestMigrationId } from "./migrations.js";
import type { MemoryPgliteDatabase } from "../database/index.js";

const REQUIRED_TABLES = Object.values(TABLES);

export interface SchemaCheckResult {
  ok: boolean;
  latest_migration_id: string;
  applied_migration_ids: string[];
  missing_tables: string[];
  vector_ready: boolean;
  approximate_vector_indexes_ready: boolean;
  optional_warnings: string[];
}

interface TableRow {
  table_name: string;
}

interface IndexRow {
  indexname: string;
}

export async function checkSchema(
  database: MemoryPgliteDatabase,
): Promise<SchemaCheckResult> {
  const tables = await database.query<TableRow>(
    `
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
    `,
  );
  const tableNames = new Set(tables.rows.map((row) => row.table_name));
  const missingTables = REQUIRED_TABLES.filter((tableName) => !tableNames.has(tableName));

  const migrations = await appliedMigrations(database);
  const vectorReady = await isVectorReady(database);
  const approximateVectorIndexesReady = await hasApproximateVectorIndexes(database);

  const optionalWarnings = [];
  if (!approximateVectorIndexesReady) {
    optionalWarnings.push(
      "Approximate vector indexes were not found. Exact vector search can still work; HNSW index support may be unavailable in this PGlite build.",
    );
  }

  return {
    ok: missingTables.length === 0 && vectorReady,
    latest_migration_id: latestMigrationId(),
    applied_migration_ids: migrations.map((migration) => migration.id),
    missing_tables: missingTables,
    vector_ready: vectorReady,
    approximate_vector_indexes_ready: approximateVectorIndexesReady,
    optional_warnings: optionalWarnings,
  };
}

async function isVectorReady(database: MemoryPgliteDatabase): Promise<boolean> {
  try {
    await database.assertVectorReady();
    return true;
  } catch {
    return false;
  }
}

async function hasApproximateVectorIndexes(database: MemoryPgliteDatabase): Promise<boolean> {
  const indexes = await database.query<IndexRow>(
    `
      SELECT indexname
      FROM pg_indexes
      WHERE schemaname = 'public'
        AND indexname IN (
          'idx_recent_context_embedding',
          'idx_recent_summaries_embedding',
          'idx_brain_chunks_embedding'
        )
    `,
  );

  return indexes.rows.length === 3;
}
