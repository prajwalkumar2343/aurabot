import { URL } from "node:url";
import type {
  JsonObject,
  JsonValue,
  RecentContextEvent,
  RecentContextEventInput,
  RecentContextListResponse,
  RecentContextMetadata,
} from "../contracts/index.js";
import type { MemoryPgliteDatabase } from "../database/index.js";
import { enqueueMemoryJob } from "../jobs/index.js";
import { RECENT_CONTEXT_SOURCES, TABLES } from "../schema/constants.js";
import { contentHash, sha256Hex, stableJson } from "./hash.js";

const DEFAULT_RECENT_CONTEXT_TTL_SECONDS = 6 * 60 * 60;
const MAX_RECENT_CONTEXT_LIMIT = 200;

export type EmbeddingProvider = (texts: string[]) => Promise<number[][]> | number[][];

export interface InsertRecentContextOptions {
  embedder?: EmbeddingProvider;
  enqueueGraphExtraction?: boolean;
}

export interface RecentContextQuery {
  userId: string;
  agentId?: string;
  startedAt?: string;
  endedAt?: string;
  source?: string;
  app?: string;
  domain?: string;
  repoPath?: string;
  filePath?: string;
  limit?: number;
}

export interface CleanupRecentContextResult {
  deleted_ids: string[];
  cutoff: string;
}

interface RecentContextRow {
  id: string;
  user_id: string;
  agent_id: string | null;
  source: string;
  app_name: string | null;
  window_title: string | null;
  url: string | null;
  domain: string | null;
  repo_path: string | null;
  file_path: string | null;
  screen_summary: string | null;
  activities: unknown;
  key_elements: unknown;
  user_intent: string | null;
  metadata: unknown;
  content_hash: string | null;
  idempotency_key: string | null;
  created_at: string | Date;
  updated_at: string | Date;
}

interface DeletedRow {
  id: string;
}

export async function insertRecentContextEvent(
  database: MemoryPgliteDatabase,
  input: RecentContextEventInput,
  options: InsertRecentContextOptions = {},
): Promise<RecentContextEvent> {
  const normalized = normalizeRecentContextInput(input);
  const embedding = options.embedder ? await embedText(options.embedder, normalized.content) : null;
  const vectorLiteral = embedding ? vectorLiteralFromEmbedding(embedding) : null;

  await database.query(
    `
      INSERT INTO ${TABLES.recentContextEvents} (
        id,
        user_id,
        agent_id,
        source,
        app_name,
        window_title,
        url,
        domain,
        repo_path,
        file_path,
        screen_summary,
        activities,
        key_elements,
        user_intent,
        metadata,
        embedding,
        content_hash,
        idempotency_key,
        created_at
      ) VALUES (
        $1,
        $2,
        $3,
        $4,
        $5,
        $6,
        $7,
        $8,
        $9,
        $10,
        $11,
        $12::jsonb,
        $13::jsonb,
        $14,
        $15::jsonb,
        CASE WHEN $16::text IS NULL THEN NULL ELSE $16::text::vector END,
        $17,
        $18,
        $19::timestamptz
      )
      ON CONFLICT (id) DO NOTHING
    `,
    [
      normalized.id,
      normalized.user_id,
      normalized.agent_id ?? null,
      normalized.source,
      normalized.app_name,
      normalized.window_title,
      normalized.url,
      normalized.domain,
      normalized.repo_path,
      normalized.file_path,
      normalized.content,
      JSON.stringify(normalized.metadata.activities),
      JSON.stringify(normalized.metadata.key_elements),
      normalized.metadata.user_intent,
      stableJson(normalized.stored_metadata),
      vectorLiteral,
      normalized.content_hash,
      normalized.idempotency_key,
      normalized.occurred_at,
    ],
  );

  if (options.enqueueGraphExtraction ?? true) {
    await enqueueMemoryJob(database, {
      userId: normalized.user_id,
      jobType: "extract_recent_context_graph",
      idempotencyKey: `recent_context:${normalized.id}`,
      payload: {
        source: "recent_context",
        source_id: normalized.id,
        content_hash: normalized.content_hash,
      },
    });
  }

  const event = await getRecentContextEventById(database, normalized.id);
  if (!event) {
    throw new Error(`Failed to load recent context event ${normalized.id}`);
  }

  return event;
}

export async function getRecentContextEvents(
  database: MemoryPgliteDatabase,
  query: RecentContextQuery,
): Promise<RecentContextEvent[]> {
  const conditions = ["user_id = $1"];
  const params: unknown[] = [requiredString(query.userId, "userId")];

  if (query.agentId) {
    params.push(query.agentId);
    conditions.push(`agent_id = $${params.length}`);
  }

  if (query.startedAt) {
    params.push(normalizeTimestamp(query.startedAt, "startedAt"));
    conditions.push(`created_at >= $${params.length}::timestamptz`);
  }

  if (query.endedAt) {
    params.push(normalizeTimestamp(query.endedAt, "endedAt"));
    conditions.push(`created_at <= $${params.length}::timestamptz`);
  }

  if (query.source) {
    assertSupportedSource(query.source);
    params.push(query.source);
    conditions.push(`source = $${params.length}`);
  }

  if (query.app) {
    params.push(query.app);
    conditions.push(`app_name = $${params.length}`);
  }

  if (query.domain) {
    params.push(normalizeDomain(query.domain));
    conditions.push(`domain = $${params.length}`);
  }

  if (query.repoPath) {
    params.push(query.repoPath);
    conditions.push(`repo_path = $${params.length}`);
  }

  if (query.filePath) {
    params.push(query.filePath);
    conditions.push(`file_path = $${params.length}`);
  }

  params.push(boundedLimit(query.limit));
  const limitPlaceholder = `$${params.length}`;

  const result = await database.query<RecentContextRow>(
    `
      SELECT *
      FROM ${TABLES.recentContextEvents}
      WHERE ${conditions.join(" AND ")}
      ORDER BY created_at DESC, id DESC
      LIMIT ${limitPlaceholder}
    `,
    params,
  );

  return result.rows.map(rowToRecentContextEvent);
}

export async function getRecentContextEventById(
  database: MemoryPgliteDatabase,
  id: string,
): Promise<RecentContextEvent | null> {
  const result = await database.query<RecentContextRow>(
    `
      SELECT *
      FROM ${TABLES.recentContextEvents}
      WHERE id = $1
      LIMIT 1
    `,
    [requiredString(id, "id")],
  );

  const row = result.rows[0];
  return row ? rowToRecentContextEvent(row) : null;
}

export async function deleteRecentContextEvent(
  database: MemoryPgliteDatabase,
  options: { userId: string; id: string },
): Promise<boolean> {
  const id = requiredString(options.id, "id");
  const userId = requiredString(options.userId, "userId");

  const result = await database.transaction(async () => {
    await database.query(
      `
        DELETE FROM ${TABLES.entityLinks}
        WHERE user_id = $1
          AND evidence_source_type = 'recent_context'
          AND evidence_source_id = $2
      `,
      [userId, id],
    );

    await database.query(
      `
        DELETE FROM ${TABLES.memoryJobs}
        WHERE user_id = $1
          AND payload->>'source' = 'recent_context'
          AND payload->>'source_id' = $2
      `,
      [userId, id],
    );

    return await database.query<DeletedRow>(
      `
        DELETE FROM ${TABLES.recentContextEvents}
        WHERE id = $1
          AND user_id = $2
        RETURNING id
      `,
      [id, userId],
    );
  });

  return result.rows.length > 0;
}

export async function cleanupExpiredRecentContext(
  database: MemoryPgliteDatabase,
  options: { olderThanHours?: number; now?: string; dryRun?: boolean } = {},
): Promise<CleanupRecentContextResult> {
  const olderThanHours = options.olderThanHours ?? DEFAULT_RECENT_CONTEXT_TTL_SECONDS / 3600;
  if (!Number.isFinite(olderThanHours) || olderThanHours <= 0) {
    throw new Error("olderThanHours must be a positive number");
  }

  const now = options.now ? new Date(normalizeTimestamp(options.now, "now")) : new Date();
  const cutoff = new Date(now.getTime() - olderThanHours * 3600 * 1000).toISOString();

  if (options.dryRun) {
    const result = await database.query<DeletedRow>(
      `
        SELECT id
        FROM ${TABLES.recentContextEvents}
        WHERE created_at < $1::timestamptz
        ORDER BY created_at ASC
      `,
      [cutoff],
    );
    return {
      deleted_ids: result.rows.map((row) => row.id),
      cutoff,
    };
  }

  const result = await database.query<DeletedRow>(
    `
      DELETE FROM ${TABLES.recentContextEvents}
      WHERE created_at < $1::timestamptz
      RETURNING id
    `,
    [cutoff],
  );

  return {
    deleted_ids: result.rows.map((row) => row.id),
    cutoff,
  };
}

export function recentContextListResponse(
  items: RecentContextEvent[],
  debug?: JsonObject,
): RecentContextListResponse {
  return debug
    ? { schema_version: "memory-v2", items, debug }
    : { schema_version: "memory-v2", items };
}

function normalizeRecentContextInput(input: RecentContextEventInput): NormalizedRecentContextInput {
  const userId = requiredString(input.user_id, "user_id");
  const idempotencyKey = requiredString(input.idempotency_key, "idempotency_key");
  const content = requiredString(input.content, "content");
  const occurredAt = normalizeTimestamp(input.occurred_at, "occurred_at");
  assertSupportedSource(input.source);
  const metadata = normalizeMetadata(input.metadata);
  const url = optionalString(metadata.url);
  const domain = optionalString(readMetadataString(metadata, "domain")) ?? domainFromUrl(url);
  const ttlSeconds = normalizePositiveInteger(
    input.ttl_seconds,
    DEFAULT_RECENT_CONTEXT_TTL_SECONDS,
    "ttl_seconds",
  );
  const importance = normalizeImportance(input.importance);
  const hash = contentHash(
    stableJson({
      user_id: userId,
      agent_id: input.agent_id ?? null,
      source: input.source,
      content,
      occurred_at: occurredAt,
      metadata,
    }),
  );

  const storedMetadata: RecentContextStoredMetadata = {
    ...metadata,
    ttl_seconds: ttlSeconds,
    content_hash: hash,
  };
  if (importance !== undefined) {
    storedMetadata.importance = importance;
  }

  const normalized: NormalizedRecentContextInput = {
    id: recentContextId(idempotencyKey),
    user_id: userId,
    idempotency_key: idempotencyKey,
    source: input.source,
    content,
    content_hash: hash,
    occurred_at: occurredAt,
    metadata,
    stored_metadata: storedMetadata,
  };

  assignOptional(normalized, "agent_id", optionalString(input.agent_id));
  assignOptional(
    normalized,
    "app_name",
    optionalString(readMetadataString(metadata, "app_name")) ?? optionalString(metadata.browser),
  );
  assignOptional(normalized, "window_title", optionalString(readMetadataString(metadata, "window_title")));
  assignOptional(normalized, "url", url);
  assignOptional(normalized, "domain", domain);
  assignOptional(normalized, "repo_path", optionalString(readMetadataString(metadata, "repo_path")));
  assignOptional(normalized, "file_path", optionalString(readMetadataString(metadata, "file_path")));

  return normalized;
}

interface NormalizedRecentContextInput {
  id: string;
  user_id: string;
  agent_id?: string;
  idempotency_key: string;
  source: string;
  content: string;
  content_hash: string;
  occurred_at: string;
  app_name?: string;
  window_title?: string;
  url?: string;
  domain?: string;
  repo_path?: string;
  file_path?: string;
  metadata: RecentContextMetadata;
  stored_metadata: RecentContextStoredMetadata;
}

type RecentContextStoredMetadata = RecentContextMetadata & {
  ttl_seconds: number;
  importance?: number;
  content_hash: string;
};

function rowToRecentContextEvent(row: RecentContextRow): RecentContextEvent {
  const metadata = normalizeMetadata(row.metadata);
  const createdAt = toIsoTimestamp(row.created_at);
  const ttlSeconds = readNumber(metadata.ttl_seconds);
  const importance = readNumber(metadata.importance);
  const event: RecentContextEvent = {
    id: row.id,
    user_id: row.user_id,
    source: row.source as RecentContextEvent["source"],
    content: row.screen_summary ?? "",
    content_hash: row.content_hash ?? contentHash(row.screen_summary ?? ""),
    occurred_at: createdAt,
    created_at: createdAt,
    metadata: {
      ...metadata,
      context: metadata.context,
      activities: normalizeStringArray(row.activities) ?? metadata.activities,
      key_elements: normalizeStringArray(row.key_elements) ?? metadata.key_elements,
      user_intent: row.user_intent ?? metadata.user_intent,
      display_num: metadata.display_num,
    },
  };

  if (row.agent_id) {
    event.agent_id = row.agent_id;
  }
  if (ttlSeconds !== undefined) {
    event.ttl_seconds = ttlSeconds;
  }
  if (importance !== undefined) {
    event.importance = importance;
  }

  return event;
}

function normalizeMetadata(value: unknown): RecentContextMetadata {
  const source = isRecord(value) ? value : {};
  return {
    ...source,
    context: optionalString(source.context) ?? "General",
    activities: normalizeStringArray(source.activities) ?? [],
    key_elements: normalizeStringArray(source.key_elements) ?? [],
    user_intent: optionalString(source.user_intent) ?? "",
    display_num: normalizeInteger(source.display_num, 0, "display_num"),
  } as RecentContextMetadata;
}

function normalizeStringArray(value: unknown): string[] | undefined {
  if (!Array.isArray(value)) {
    return undefined;
  }

  return value
    .map((entry) => (typeof entry === "string" ? entry.trim() : ""))
    .filter((entry) => entry.length > 0);
}

function requiredString(value: string | undefined, field: string): string {
  const trimmed = value?.trim();
  if (!trimmed) {
    throw new Error(`${field} is required`);
  }
  return trimmed;
}

function optionalString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

function normalizeTimestamp(value: string, field: string): string {
  const date = new Date(requiredString(value, field));
  if (Number.isNaN(date.getTime())) {
    throw new Error(`${field} must be an ISO 8601 timestamp`);
  }
  return date.toISOString();
}

function normalizeInteger(value: unknown, fallback: number, field: string): number {
  if (value === undefined || value === null || value === "") {
    return fallback;
  }
  const numberValue = Number(value);
  if (!Number.isInteger(numberValue)) {
    throw new Error(`${field} must be an integer`);
  }
  return numberValue;
}

function normalizePositiveInteger(
  value: unknown,
  fallback: number,
  field: string,
): number {
  const integerValue = normalizeInteger(value, fallback, field);
  if (integerValue <= 0) {
    throw new Error(`${field} must be positive`);
  }
  return integerValue;
}

function normalizeImportance(value: unknown): number | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  const numberValue = Number(value);
  if (!Number.isFinite(numberValue) || numberValue < 0 || numberValue > 1) {
    throw new Error("importance must be between 0 and 1");
  }
  return numberValue;
}

function boundedLimit(value: number | undefined): number {
  if (value === undefined) {
    return 50;
  }
  if (!Number.isInteger(value) || value <= 0) {
    throw new Error("limit must be a positive integer");
  }
  return Math.min(value, MAX_RECENT_CONTEXT_LIMIT);
}

function readMetadataString(metadata: RecentContextMetadata, key: string): string | undefined {
  return optionalString(metadata[key]);
}

function readNumber(value: unknown): number | undefined {
  if (value === undefined || value === null || value === "") {
    return undefined;
  }
  const numberValue = Number(value);
  return Number.isFinite(numberValue) ? numberValue : undefined;
}

function domainFromUrl(value: string | undefined): string | undefined {
  if (!value) {
    return undefined;
  }
  try {
    return normalizeDomain(new URL(value).hostname);
  } catch {
    return undefined;
  }
}

function normalizeDomain(value: string): string {
  return value.trim().toLowerCase().replace(/^www\./, "");
}

function isRecord(value: unknown): value is Record<string, JsonValue | undefined> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function recentContextId(idempotencyKey: string): string {
  return `ctx_${sha256Hex(idempotencyKey).slice(0, 24)}`;
}

async function embedText(embedder: EmbeddingProvider, text: string): Promise<number[]> {
  const result = await embedder([text]);
  const first = result[0];
  if (!Array.isArray(first) || first.length === 0) {
    throw new Error("embedder returned no embedding for recent context event");
  }
  return first.map((value) => Number(value));
}

function vectorLiteralFromEmbedding(embedding: number[]): string {
  return `[${embedding.map((value) => Number(value).toFixed(12)).join(",")}]`;
}

function toIsoTimestamp(value: string | Date): string {
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}

function assertSupportedSource(source: string): void {
  if (!(RECENT_CONTEXT_SOURCES as readonly string[]).includes(source)) {
    throw new Error(
      `Unsupported recent context source "${source}". Current schema supports: ${RECENT_CONTEXT_SOURCES.join(
        ", ",
      )}`,
    );
  }
}

function assignOptional<T extends object, K extends keyof T>(
  target: T,
  key: K,
  value: T[K] | undefined,
): void {
  if (value !== undefined) {
    target[key] = value;
  }
}
