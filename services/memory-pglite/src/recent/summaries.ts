import type { CurrentContextPacket, JsonObject, RecentContextEvent, TimeWindow } from "../contracts/index.js";
import type { MemoryPgliteDatabase } from "../database/index.js";
import { enqueueMemoryJob } from "../jobs/index.js";
import { TABLES } from "../schema/constants.js";
import type { EmbeddingProvider } from "./events.js";
import { getRecentContextEvents } from "./events.js";
import { contentHash, sha256Hex, stableJson } from "./hash.js";

const DEFAULT_CURRENT_CONTEXT_HOURS = 6;
const DEFAULT_RECENT_EVENTS_LIMIT = 10;

export interface SummarizeRecentContextInput {
  userId: string;
  agentId?: string;
  idempotencyKey: string;
  window: TimeWindow;
  embedder?: EmbeddingProvider;
  mode?: "deterministic";
}

export interface CurrentContextOptions {
  userId: string;
  agentId?: string;
  now?: string;
  hours?: number;
  recentEventsLimit?: number;
}

interface SummaryRow {
  id: string;
  user_id: string;
  agent_id: string | null;
  window_started_at: string | Date;
  window_ended_at: string | Date;
  summary: string;
  active_apps: unknown;
  websites: unknown;
  repos: unknown;
  files: unknown;
  projects: unknown;
  people: unknown;
  decisions: unknown;
  open_questions: unknown;
  source_event_ids: unknown;
  metadata: unknown;
  source_hash: string;
  generated_by: string | null;
  generated_at: string | Date | null;
  created_at: string | Date;
  updated_at: string | Date;
}

export async function summarizeRecentContext(
  database: MemoryPgliteDatabase,
  input: SummarizeRecentContextInput,
): Promise<CurrentContextPacket> {
  const window = normalizeWindow(input.window);
  const query = recentContextQuery(input.userId, input.agentId, window, 200);
  const events = await getRecentContextEvents(database, query);
  const deterministic = buildDeterministicSummary(events);
  const sourceHash = contentHash(
    stableJson(events.map((event) => ({ id: event.id, content_hash: event.content_hash }))),
  );
  const summaryId = summaryIdFromInput(input.idempotencyKey, sourceHash);
  const embedding = input.embedder ? await embedSummary(input.embedder, deterministic.summary) : null;
  const vectorLiteral = embedding ? vectorLiteralFromEmbedding(embedding) : null;
  const generatedAt = new Date().toISOString();

  await database.query(
    `
      INSERT INTO ${TABLES.recentContextSummaries} (
        id,
        user_id,
        agent_id,
        window_started_at,
        window_ended_at,
        summary,
        active_apps,
        websites,
        repos,
        files,
        projects,
        people,
        decisions,
        open_questions,
        source_event_ids,
        metadata,
        embedding,
        source_hash,
        generated_by,
        generated_at
      ) VALUES (
        $1,
        $2,
        $3,
        $4::timestamptz,
        $5::timestamptz,
        $6,
        $7::jsonb,
        $8::jsonb,
        $9::jsonb,
        $10::jsonb,
        $11::jsonb,
        $12::jsonb,
        $13::jsonb,
        $14::jsonb,
        $15::jsonb,
        $16::jsonb,
        CASE WHEN $17::text IS NULL THEN NULL ELSE $17::text::vector END,
        $18,
        $19,
        $20::timestamptz
      )
      ON CONFLICT (id) DO NOTHING
    `,
    [
      summaryId,
      input.userId,
      input.agentId ?? null,
      window.started_at,
      window.ended_at,
      deterministic.summary,
      JSON.stringify(deterministic.active_apps),
      JSON.stringify(deterministic.websites),
      JSON.stringify(deterministic.repos),
      JSON.stringify(deterministic.files),
      JSON.stringify(deterministic.projects),
      JSON.stringify(deterministic.people),
      JSON.stringify(deterministic.decisions),
      JSON.stringify(deterministic.open_questions),
      JSON.stringify(events.map((event) => event.id)),
      stableJson({
        mode: input.mode ?? "deterministic",
        generated_by: "deterministic_summarizer",
        generated_at: generatedAt,
        idempotency_key: input.idempotencyKey,
      }),
      vectorLiteral,
      sourceHash,
      "deterministic_summarizer",
      generatedAt,
    ],
  );

  await enqueueMemoryJob(database, {
    userId: input.userId,
    jobType: "summarize_recent_context",
    idempotencyKey: input.idempotencyKey,
    payload: {
      window: {
        started_at: window.started_at,
        ended_at: window.ended_at,
      },
      source_hash: sourceHash,
      summary_id: summaryId,
    },
  });

  const stored = await getSummaryById(database, summaryId);
  return summaryRowToCurrentContextPacket(stored, events);
}

export async function getCurrentContextPacket(
  database: MemoryPgliteDatabase,
  options: CurrentContextOptions,
): Promise<CurrentContextPacket> {
  const window = currentWindow(options.now, options.hours ?? DEFAULT_CURRENT_CONTEXT_HOURS);
  const events = await getRecentContextEvents(
    database,
    recentContextQuery(
      options.userId,
      options.agentId,
      window,
      options.recentEventsLimit ?? DEFAULT_RECENT_EVENTS_LIMIT,
    ),
  );
  const summary = await getLatestSummary(database, options.userId, options.agentId);

  if (summary) {
    return summaryRowToCurrentContextPacket(summary, events);
  }

  const deterministic = buildDeterministicSummary(events);
  const packet: CurrentContextPacket = {
    schema_version: "memory-v2",
    user_id: options.userId,
    generated_at: new Date().toISOString(),
    window,
    summary: deterministic.summary,
    recent_events: events,
    active_entities: [],
    metadata: {
      generated_by: "deterministic_summarizer",
      persisted: false,
    },
  };

  if (options.agentId) {
    packet.agent_id = options.agentId;
  }

  return packet;
}

function buildDeterministicSummary(events: RecentContextEvent[]): DeterministicSummary {
  if (events.length === 0) {
    return {
      summary: "No recent activity captured in this window.",
      active_apps: [],
      websites: [],
      repos: [],
      files: [],
      projects: [],
      people: [],
      decisions: [],
      open_questions: [],
    };
  }

  const activeApps = uniqueStrings(
    events.flatMap((event) => [stringFromMetadata(event.metadata, "app_name"), event.metadata.browser]),
  );
  const websites = uniqueStrings(
    events.flatMap((event) => [
      domainFromUrl(typeof event.metadata.url === "string" ? event.metadata.url : undefined),
      stringFromMetadata(event.metadata, "domain"),
    ]),
  );
  const repos = uniqueStrings(events.map((event) => stringFromMetadata(event.metadata, "repo_path")));
  const files = uniqueStrings(events.map((event) => stringFromMetadata(event.metadata, "file_path")));
  const projects = uniqueStrings(events.flatMap((event) => stringArrayFromMetadata(event.metadata, "projects")));
  const people = uniqueStrings(events.flatMap((event) => stringArrayFromMetadata(event.metadata, "people")));
  const decisions = uniqueStrings(events.flatMap((event) => stringArrayFromMetadata(event.metadata, "decisions")));
  const openQuestions = uniqueStrings(
    events.flatMap((event) => stringArrayFromMetadata(event.metadata, "open_questions")),
  );
  const latest = [...events].sort((left, right) =>
    right.occurred_at.localeCompare(left.occurred_at),
  )[0];
  const latestIntent = latest?.metadata.user_intent || latest?.content || "recent work";
  const appPhrase = activeApps.length > 0 ? ` using ${activeApps.slice(0, 3).join(", ")}` : "";
  const websitePhrase =
    websites.length > 0 ? ` across ${websites.slice(0, 3).join(", ")}` : "";

  return {
    summary: `Recent context includes ${events.length} event${events.length === 1 ? "" : "s"}${appPhrase}${websitePhrase}. Latest focus: ${latestIntent}.`,
    active_apps: activeApps,
    websites,
    repos,
    files,
    projects,
    people,
    decisions,
    open_questions: openQuestions,
  };
}

interface DeterministicSummary {
  summary: string;
  active_apps: string[];
  websites: string[];
  repos: string[];
  files: string[];
  projects: string[];
  people: string[];
  decisions: string[];
  open_questions: string[];
}

async function getSummaryById(
  database: MemoryPgliteDatabase,
  summaryId: string,
): Promise<SummaryRow> {
  const result = await database.query<SummaryRow>(
    `SELECT * FROM ${TABLES.recentContextSummaries} WHERE id = $1 LIMIT 1`,
    [summaryId],
  );
  const row = result.rows[0];
  if (!row) {
    throw new Error(`Failed to load recent context summary ${summaryId}`);
  }
  return row;
}

async function getLatestSummary(
  database: MemoryPgliteDatabase,
  userId: string,
  agentId: string | undefined,
): Promise<SummaryRow | null> {
  const params: unknown[] = [userId];
  const conditions = ["user_id = $1"];

  if (agentId) {
    params.push(agentId);
    conditions.push(`agent_id = $${params.length}`);
  }

  const result = await database.query<SummaryRow>(
    `
      SELECT *
      FROM ${TABLES.recentContextSummaries}
      WHERE ${conditions.join(" AND ")}
      ORDER BY window_ended_at DESC, created_at DESC
      LIMIT 1
    `,
    params,
  );
  return result.rows[0] ?? null;
}

function summaryRowToCurrentContextPacket(
  row: SummaryRow,
  recentEvents: RecentContextEvent[],
): CurrentContextPacket {
  const metadata = jsonObject(row.metadata);
  const packet: CurrentContextPacket = {
    schema_version: "memory-v2",
    user_id: row.user_id,
    generated_at: toIso(row.generated_at ?? row.created_at),
    window: {
      started_at: toIso(row.window_started_at),
      ended_at: toIso(row.window_ended_at),
    },
    summary: row.summary,
    recent_events: recentEvents,
    active_entities: [],
    metadata: {
      ...metadata,
      summary_id: row.id,
      source_hash: row.source_hash,
      generated_by: row.generated_by ?? "deterministic_summarizer",
    },
  };

  if (row.agent_id) {
    packet.agent_id = row.agent_id;
  }

  return packet;
}

function normalizeWindow(window: TimeWindow): TimeWindow {
  const startedAt = normalizeTimestamp(window.started_at, "window.started_at");
  const endedAt = normalizeTimestamp(window.ended_at, "window.ended_at");
  if (new Date(startedAt).getTime() >= new Date(endedAt).getTime()) {
    throw new Error("window.started_at must be before window.ended_at");
  }
  return {
    started_at: startedAt,
    ended_at: endedAt,
  };
}

function currentWindow(nowValue: string | undefined, hours: number): TimeWindow {
  if (!Number.isFinite(hours) || hours <= 0) {
    throw new Error("hours must be a positive number");
  }
  const ended = nowValue ? new Date(normalizeTimestamp(nowValue, "now")) : new Date();
  const started = new Date(ended.getTime() - hours * 3600 * 1000);
  return {
    started_at: started.toISOString(),
    ended_at: ended.toISOString(),
  };
}

function summaryIdFromInput(idempotencyKey: string, sourceHash: string): string {
  return `summary_${sha256Hex(`${idempotencyKey}:${sourceHash}`).slice(0, 24)}`;
}

async function embedSummary(embedder: EmbeddingProvider, summary: string): Promise<number[]> {
  const embeddings = await embedder([summary]);
  const first = embeddings[0];
  if (!Array.isArray(first) || first.length === 0) {
    throw new Error("embedder returned no embedding for recent context summary");
  }
  return first.map((value) => Number(value));
}

function vectorLiteralFromEmbedding(embedding: number[]): string {
  return `[${embedding.map((value) => Number(value).toFixed(12)).join(",")}]`;
}

function normalizeTimestamp(value: string, field: string): string {
  const date = new Date(value);
  if (!value || Number.isNaN(date.getTime())) {
    throw new Error(`${field} must be an ISO 8601 timestamp`);
  }
  return date.toISOString();
}

function toIso(value: string | Date): string {
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}

function uniqueStrings(values: Array<string | undefined>): string[] {
  return [...new Set(values.filter((value): value is string => Boolean(value?.trim())))];
}

function recentContextQuery(
  userId: string,
  agentId: string | undefined,
  window: TimeWindow,
  limit: number,
): { userId: string; agentId?: string; startedAt: string; endedAt: string; limit: number } {
  const query: {
    userId: string;
    agentId?: string;
    startedAt: string;
    endedAt: string;
    limit: number;
  } = {
    userId,
    startedAt: window.started_at,
    endedAt: window.ended_at,
    limit,
  };
  if (agentId) {
    query.agentId = agentId;
  }
  return query;
}

function stringFromMetadata(metadata: Record<string, unknown>, key: string): string | undefined {
  const value = metadata[key];
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

function stringArrayFromMetadata(metadata: Record<string, unknown>, key: string): string[] {
  const value = metadata[key];
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map((entry) => (typeof entry === "string" ? entry.trim() : ""))
    .filter((entry) => entry.length > 0);
}

function domainFromUrl(value: string | undefined): string | undefined {
  if (!value) {
    return undefined;
  }
  try {
    return new URL(value).hostname.toLowerCase().replace(/^www\./, "");
  } catch {
    return undefined;
  }
}

function jsonObject(value: unknown): JsonObject {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as JsonObject)
    : {};
}
