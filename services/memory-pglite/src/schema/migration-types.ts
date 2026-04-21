import type { MemoryPgliteDatabase } from "../database/index.js";

export interface MigrationContext {
  embeddingDimensions: number;
}

export interface Migration {
  id: string;
  description: string;
  statements: string[];
  optionalStatements?: string[];
}

export interface AppliedMigration {
  id: string;
  description: string;
  applied_at: string;
}

export interface MigrationRunnerResult {
  applied: AppliedMigration[];
  skipped: string[];
  optionalFailures: Array<{
    migration_id: string;
    statement: string;
    error: string;
  }>;
}

export type MigrationFactory = (context: MigrationContext) => Migration;

export interface MigrationApplier {
  database: MemoryPgliteDatabase;
  context: MigrationContext;
}
