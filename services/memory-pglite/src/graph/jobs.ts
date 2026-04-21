import type { JsonObject, JsonValue } from "../contracts/index.js";
import type { MemoryPgliteDatabase } from "../database/index.js";
import { TABLES } from "../schema/constants.js";
import { extractGraphForBrainPage, extractGraphForRecentContextEvent } from "./index.js";

const GRAPH_JOB_TYPES = ["extract_recent_context_graph", "extract_brain_page_graph"] as const;

export interface ProcessGraphExtractionJobsOptions {
  limit?: number;
  now?: string;
}

export interface ProcessedGraphExtractionJob {
  id: string;
  job_type: (typeof GRAPH_JOB_TYPES)[number];
  status: "completed" | "failed" | "skipped";
  source_id?: string;
  entities?: number;
  relations?: number;
  error?: string;
}

interface MemoryJobRow {
  id: string;
  user_id: string | null;
  job_type: string;
  status: string;
  payload: unknown;
  attempts: number;
}

export async function processGraphExtractionJobs(
  database: MemoryPgliteDatabase,
  options: ProcessGraphExtractionJobsOptions = {},
): Promise<ProcessedGraphExtractionJob[]> {
  const rows = await loadQueuedGraphJobs(database, boundedLimit(options.limit));
  const processed: ProcessedGraphExtractionJob[] = [];

  for (const row of rows) {
    const claimed = await claimGraphJob(database, row.id);
    if (!claimed) {
      processed.push({
        id: row.id,
        job_type: assertGraphJobType(row.job_type),
        status: "skipped",
        error: "job was already claimed",
      });
      continue;
    }

    const jobType = assertGraphJobType(row.job_type);
    try {
      const payload = jsonObject(row.payload);
      const sourceId = requiredString(payload.source_id, "payload.source_id");
      const extractionOptions = options.now ? { now: options.now } : {};
      const result =
        jobType === "extract_recent_context_graph"
          ? await extractGraphForRecentContextEvent(database, sourceId, extractionOptions)
          : await extractGraphForBrainPage(database, sourceId, extractionOptions);

      const jobResult = {
        source_id: sourceId,
        entities: result.entities.length,
        relations: result.relations.length,
        generated_by: "graph_job_processor",
        generated_at: options.now ?? new Date().toISOString(),
      } satisfies JsonObject;

      await completeGraphJob(database, row.id, jobResult);
      processed.push({
        id: row.id,
        job_type: jobType,
        status: "completed",
        source_id: sourceId,
        entities: result.entities.length,
        relations: result.relations.length,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Graph extraction job failed";
      await failGraphJob(database, row.id, message);
      processed.push({
        id: row.id,
        job_type: jobType,
        status: "failed",
        error: message,
      });
    }
  }

  return processed;
}

async function loadQueuedGraphJobs(
  database: MemoryPgliteDatabase,
  limit: number,
): Promise<MemoryJobRow[]> {
  const result = await database.query<MemoryJobRow>(
    `
      SELECT id, user_id, job_type, status, payload, attempts
      FROM ${TABLES.memoryJobs}
      WHERE status = 'queued'
        AND job_type = ANY($1::text[])
        AND run_after <= NOW()
      ORDER BY created_at ASC, id ASC
      LIMIT $2
    `,
    [[...GRAPH_JOB_TYPES], limit],
  );
  return result.rows;
}

async function claimGraphJob(database: MemoryPgliteDatabase, id: string): Promise<boolean> {
  const result = await database.query<{ id: string }>(
    `
      UPDATE ${TABLES.memoryJobs}
      SET
        status = 'running',
        attempts = attempts + 1,
        started_at = NOW(),
        updated_at = NOW()
      WHERE id = $1
        AND status = 'queued'
      RETURNING id
    `,
    [id],
  );
  return result.rows.length > 0;
}

async function completeGraphJob(
  database: MemoryPgliteDatabase,
  id: string,
  result: JsonObject,
): Promise<void> {
  await database.query(
    `
      UPDATE ${TABLES.memoryJobs}
      SET
        status = 'completed',
        result = $2::jsonb,
        error = NULL,
        completed_at = NOW(),
        updated_at = NOW()
      WHERE id = $1
    `,
    [id, JSON.stringify(result)],
  );
}

async function failGraphJob(
  database: MemoryPgliteDatabase,
  id: string,
  error: string,
): Promise<void> {
  await database.query(
    `
      UPDATE ${TABLES.memoryJobs}
      SET
        status = 'failed',
        error = $2,
        completed_at = NOW(),
        updated_at = NOW()
      WHERE id = $1
    `,
    [id, error],
  );
}

function assertGraphJobType(value: string): (typeof GRAPH_JOB_TYPES)[number] {
  if (!(GRAPH_JOB_TYPES as readonly string[]).includes(value)) {
    throw new Error(`Unsupported graph extraction job type: ${value}`);
  }
  return value as (typeof GRAPH_JOB_TYPES)[number];
}

function boundedLimit(value: number | undefined): number {
  if (value === undefined) {
    return 25;
  }
  if (!Number.isInteger(value) || value <= 0) {
    throw new Error("limit must be a positive integer");
  }
  return Math.min(value, 100);
}

function jsonObject(value: unknown): JsonObject {
  const parsed = parseJson(value);
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    return {};
  }
  return parsed as JsonObject;
}

function parseJson(value: unknown): unknown {
  if (typeof value !== "string") {
    return value;
  }
  try {
    return JSON.parse(value) as unknown;
  } catch {
    return value;
  }
}

function requiredString(value: JsonValue | undefined, field: string): string {
  if (typeof value !== "string" || !value.trim()) {
    throw new Error(`${field} is required`);
  }
  return value.trim();
}
