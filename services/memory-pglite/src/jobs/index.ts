import type { JsonObject, MemoryJobRef } from "../contracts/index.js";
import type { MemoryPgliteDatabase } from "../database/index.js";
import { TABLES } from "../schema/constants.js";
import { sha256Hex, stableJson } from "../recent/hash.js";

export interface EnqueueMemoryJobInput {
  userId?: string;
  jobType: string;
  idempotencyKey: string;
  payload: JsonObject;
  queue?: string;
  runAfter?: string;
}

interface MemoryJobRow {
  id: string;
  status: string;
  idempotency_key: string;
}

export async function enqueueMemoryJob(
  database: MemoryPgliteDatabase,
  input: EnqueueMemoryJobInput,
): Promise<MemoryJobRef> {
  const jobId = memoryJobId(input.jobType, input.idempotencyKey);
  const runAfter = input.runAfter ? new Date(input.runAfter).toISOString() : new Date().toISOString();

  await database.query(
    `
      INSERT INTO ${TABLES.memoryJobs} (
        id,
        user_id,
        job_type,
        status,
        queue,
        idempotency_key,
        payload,
        run_after
      ) VALUES (
        $1,
        $2,
        $3,
        'queued',
        $4,
        $5,
        $6::jsonb,
        $7::timestamptz
      )
      ON CONFLICT (job_type, idempotency_key) DO NOTHING
    `,
    [
      jobId,
      input.userId ?? null,
      input.jobType,
      input.queue ?? "default",
      input.idempotencyKey,
      stableJson(input.payload),
      runAfter,
    ],
  );

  const row = await getMemoryJob(database, input.jobType, input.idempotencyKey);
  if (!row) {
    throw new Error(`Failed to enqueue or load memory job ${input.jobType}:${input.idempotencyKey}`);
  }

  return {
    id: row.id,
    status: row.status as MemoryJobRef["status"],
    idempotency_key: row.idempotency_key,
  };
}

async function getMemoryJob(
  database: MemoryPgliteDatabase,
  jobType: string,
  idempotencyKey: string,
): Promise<MemoryJobRow | null> {
  const result = await database.query<MemoryJobRow>(
    `
      SELECT id, status, idempotency_key
      FROM ${TABLES.memoryJobs}
      WHERE job_type = $1
        AND idempotency_key = $2
      LIMIT 1
    `,
    [jobType, idempotencyKey],
  );

  return result.rows[0] ?? null;
}

function memoryJobId(jobType: string, idempotencyKey: string): string {
  return `job_${sha256Hex(`${jobType}:${idempotencyKey}`).slice(0, 24)}`;
}
