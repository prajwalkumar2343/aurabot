import { mkdir, open, rm } from "node:fs/promises";
import { dirname, join } from "node:path";
import { PGlite } from "@electric-sql/pglite";
import { vector } from "@electric-sql/pglite/vector";
import { resolveEmbeddingDimensions, resolvePgliteDir } from "../config/paths.js";
import { runMigrations } from "../schema/migrations.js";
import { MemoryDatabaseError, MemorySchemaError } from "./errors.js";

const INSTANCE_LOCK_SUFFIX = ".lock";

export interface MemoryDatabaseOptions {
  dataDir?: string;
  embeddingDimensions?: number;
  env?: NodeJS.ProcessEnv;
  skipMigrations?: boolean;
  allowMultipleInstances?: boolean;
}

export interface QueryResult<Row extends object = Record<string, unknown>> {
  rows: Row[];
  fields?: unknown[];
}

export class MemoryPgliteDatabase {
  readonly dataDir: string;
  readonly embeddingDimensions: number;

  private db: PGlite | null = null;
  private lockHandle: Awaited<ReturnType<typeof open>> | null = null;
  private readonly skipMigrations: boolean;
  private readonly allowMultipleInstances: boolean;

  constructor(options: MemoryDatabaseOptions = {}) {
    this.dataDir = options.dataDir ?? resolvePgliteDir(options.env);
    this.embeddingDimensions =
      options.embeddingDimensions ?? resolveEmbeddingDimensions(options.env);
    this.skipMigrations = options.skipMigrations ?? false;
    this.allowMultipleInstances = options.allowMultipleInstances ?? false;
  }

  async open(): Promise<void> {
    if (this.db) {
      return;
    }

    await mkdir(this.dataDir, { recursive: true });
    await this.acquireInstanceLock();

    try {
      this.db = new PGlite(this.dataDir, {
        extensions: { vector },
      });

      await this.exec("CREATE EXTENSION IF NOT EXISTS vector");

      if (!this.skipMigrations) {
        await runMigrations(this, {
          embeddingDimensions: this.embeddingDimensions,
        });
      }
    } catch (error) {
      await this.close();
      const causeMessage = error instanceof Error ? `: ${error.message}` : "";
      throw new MemoryDatabaseError(
        `Failed to open PGlite database at ${this.dataDir}${causeMessage}`,
        {
          cause: error,
        },
      );
    }
  }

  async close(): Promise<void> {
    const activeDb = this.db;
    this.db = null;

    if (activeDb) {
      await activeDb.close();
    }

    if (this.lockHandle) {
      await this.lockHandle.close();
      this.lockHandle = null;
      await rm(this.instanceLockPath(), { force: true });
    }
  }

  async query<Row extends object = Record<string, unknown>>(
    sql: string,
    params?: unknown[],
  ): Promise<QueryResult<Row>> {
    const db = this.requireOpenDatabase();
    const result = await db.query<Row>(sql, params);
    return {
      rows: result.rows,
      fields: result.fields,
    };
  }

  async exec(sql: string): Promise<void> {
    const db = this.requireOpenDatabase();
    await db.exec(sql);
  }

  async transaction<T>(callback: () => Promise<T>): Promise<T> {
    await this.exec("BEGIN");
    try {
      const value = await callback();
      await this.exec("COMMIT");
      return value;
    } catch (error) {
      await this.exec("ROLLBACK");
      throw error;
    }
  }

  async assertVectorReady(): Promise<void> {
    try {
      await this.query("SELECT '[1,2,3]'::vector AS vector_value");
    } catch (error) {
      throw new MemorySchemaError("PGlite vector extension is not ready", { cause: error });
    }
  }

  private requireOpenDatabase(): PGlite {
    if (!this.db) {
      throw new MemoryDatabaseError("PGlite database is not open");
    }

    return this.db;
  }

  private async acquireInstanceLock(): Promise<void> {
    if (this.allowMultipleInstances) {
      return;
    }

    const lockPath = this.instanceLockPath();
    await mkdir(dirname(lockPath), { recursive: true });

    try {
      this.lockHandle = await open(lockPath, "wx");
      await this.lockHandle.writeFile(
        JSON.stringify(
          {
            pid: process.pid,
            created_at: new Date().toISOString(),
            warning:
              "AuraBot Memory v2 routes writes through one PGlite service process. Remove this file only if no service is running.",
          },
          null,
          2,
        ),
      );
    } catch (error) {
      throw new MemoryDatabaseError(
        `PGlite data directory appears to be in use: ${this.dataDir}. ` +
          `If no AuraBot memory service is running, remove ${lockPath}.`,
        { cause: error },
      );
    }
  }

  private instanceLockPath(): string {
    return `${this.dataDir}${INSTANCE_LOCK_SUFFIX}`;
  }
}

export async function openMemoryDatabase(
  options: MemoryDatabaseOptions = {},
): Promise<MemoryPgliteDatabase> {
  const database = new MemoryPgliteDatabase(options);
  await database.open();
  return database;
}
