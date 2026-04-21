export const SCHEMA_VERSION = "memory-v2" as const;

export const ENTITY_TYPES = [
  "user",
  "person",
  "company",
  "project",
  "app",
  "website",
  "repo",
  "file",
  "workflow",
  "concept",
  "decision",
  "task",
  "meeting",
  "document",
  "preference",
] as const;

export const RELATION_TYPES = [
  "works_on",
  "uses",
  "visited",
  "opened",
  "edited",
  "mentioned_in",
  "discussed_with",
  "decided_in",
  "evidence_for",
  "related_to",
  "depends_on",
  "blocks",
  "belongs_to",
  "part_of",
  "authored",
  "created",
  "prefers",
] as const;

export const MEMORY_SOURCES = [
  "recent_context",
  "recent_summary",
  "brain_page",
  "brain_chunk",
  "graph",
] as const;

export const RECENT_CONTEXT_SOURCES = [
  "screen",
  "app",
  "browser",
  "repo",
  "file",
  "terminal",
  "system",
] as const;

export const JOB_STATUSES = [
  "queued",
  "running",
  "succeeded",
  "failed",
  "cancelled",
  "skipped",
] as const;

export const PROMOTION_MODES = ["draft", "apply"] as const;

export type EntityType = (typeof ENTITY_TYPES)[number];
export type RelationType = (typeof RELATION_TYPES)[number];
export type MemorySource = (typeof MEMORY_SOURCES)[number];
export type RecentContextSource = (typeof RECENT_CONTEXT_SOURCES)[number];
export type JobStatus = (typeof JOB_STATUSES)[number];
export type PromotionMode = (typeof PROMOTION_MODES)[number];

export type JsonPrimitive = string | number | boolean | null;
export type JsonValue = JsonPrimitive | JsonValue[] | { [key: string]: JsonValue };
export type JsonObject = { [key: string]: JsonValue };

export interface Evidence {
  source: MemorySource | "timeline_event" | "promotion_candidate";
  source_id: string;
  excerpt?: string;
  content_hash?: string;
  created_at?: string;
  metadata?: JsonObject;
}

export interface RelationRef {
  id: string;
  relation_type: RelationType;
  source_entity_id: string;
  target_entity_id: string;
  confidence: number;
  evidence: Evidence[];
}

export interface MemoryScoreBreakdown {
  vector: number;
  keyword: number;
  graph: number;
  recency: number;
}

export interface RecentContextMetadata {
  context: string;
  activities: string[];
  key_elements: string[];
  user_intent: string;
  display_num: number;
  browser?: string;
  url?: string;
  capture_reason?: string;
  [key: string]: JsonValue | undefined;
}

export interface RecentContextEvent {
  id: string;
  user_id: string;
  agent_id?: string;
  source: RecentContextSource;
  content: string;
  content_hash: string;
  occurred_at: string;
  created_at: string;
  ttl_seconds?: number;
  importance?: number;
  metadata: RecentContextMetadata;
}

export interface RecentContextEventInput {
  user_id: string;
  agent_id?: string;
  idempotency_key: string;
  source: RecentContextSource;
  content: string;
  occurred_at: string;
  ttl_seconds?: number;
  importance?: number;
  metadata: RecentContextMetadata;
}

export interface RecentContextEventResponse {
  schema_version: typeof SCHEMA_VERSION;
  event: RecentContextEvent;
}

export interface RecentContextListResponse {
  schema_version: typeof SCHEMA_VERSION;
  items: RecentContextEvent[];
  debug?: JsonObject;
}

export interface TimeWindow {
  started_at: string;
  ended_at: string;
}

export interface CurrentContextPacket {
  schema_version: typeof SCHEMA_VERSION;
  user_id: string;
  agent_id?: string;
  generated_at: string;
  window: TimeWindow;
  summary: string;
  recent_events: RecentContextEvent[];
  active_entities: string[];
  metadata: JsonObject;
}

export interface SearchMemoryItem {
  id: string;
  source: MemorySource;
  content: string;
  user_id: string;
  entity_ids: string[];
  relations: RelationRef[];
  evidence: Evidence[];
  score: number;
  scores: MemoryScoreBreakdown;
  created_at: string;
  metadata: JsonObject;
}

export interface SearchMemoryResponse {
  schema_version: typeof SCHEMA_VERSION;
  query: string;
  items: SearchMemoryItem[];
  debug: {
    matched_entities: string[];
    ranking: JsonObject;
  };
}

export interface HealthResponse {
  schema_version: typeof SCHEMA_VERSION;
  status: "ok" | "degraded" | "error";
  service: {
    name: string;
    version: string;
  };
  migration_version: string;
  database: {
    path: string;
    schema_ready: boolean;
    vector_ready: boolean;
  };
  checks: Array<{
    name: string;
    status: "ok" | "degraded" | "error";
    message: string;
  }>;
  generated_at: string;
}

export interface GraphNode {
  id: string;
  type: EntityType;
  name: string;
  aliases: string[];
  metadata: JsonObject;
}

export interface GraphQueryResponse {
  schema_version: typeof SCHEMA_VERSION;
  start: string;
  nodes: GraphNode[];
  relations: RelationRef[];
  depth: number;
  direction: "in" | "out" | "both";
  generated_at: string;
}

export interface MemoryJobRef {
  id: string;
  status: JobStatus;
  idempotency_key: string;
}

export interface BrainSyncResponse {
  schema_version: typeof SCHEMA_VERSION;
  job: MemoryJobRef;
  synced_pages: Array<{
    id: string;
    slug: string;
    path: string;
    type: EntityType;
    title: string;
    source_hash: string;
    updated_at: string;
  }>;
  errors: Array<{
    path: string;
    code: string;
    message: string;
  }>;
}

export interface PromotionResponse {
  schema_version: typeof SCHEMA_VERSION;
  candidate_id: string;
  mode: PromotionMode;
  status: "drafted" | "applied" | "conflict" | "rejected";
  target_slug: string;
  suggested_edit: string;
  evidence: Evidence[];
  metadata: JsonObject;
}

export interface DeleteResponse {
  schema_version: typeof SCHEMA_VERSION;
  deleted: boolean;
  source: MemorySource | "timeline_event" | "promotion_candidate";
  id: string;
  generated_at: string;
}

export type ContractFixture =
  | RecentContextEventResponse
  | RecentContextListResponse
  | CurrentContextPacket
  | SearchMemoryResponse
  | HealthResponse
  | GraphQueryResponse
  | BrainSyncResponse
  | PromotionResponse
  | DeleteResponse;

export function assertContractFixture(value: unknown): asserts value is ContractFixture {
  const object = expectRecord(value, "fixture");
  expectSchemaVersion(object);

  if ("event" in object) {
    assertRecentContextEventResponse(object);
    return;
  }
  if ("query" in object && "items" in object) {
    assertSearchMemoryResponse(object);
    return;
  }
  if ("items" in object) {
    assertRecentContextListResponse(object);
    return;
  }
  if ("recent_events" in object) {
    assertCurrentContextPacket(object);
    return;
  }
  if ("checks" in object) {
    assertHealthResponse(object);
    return;
  }
  if ("nodes" in object && "relations" in object) {
    assertGraphQueryResponse(object);
    return;
  }
  if ("synced_pages" in object) {
    assertBrainSyncResponse(object);
    return;
  }
  if ("candidate_id" in object) {
    assertPromotionResponse(object);
    return;
  }
  if ("deleted" in object) {
    assertDeleteResponse(object);
    return;
  }

  throw new ContractValidationError("fixture shape is not a known Memory v2 response");
}

export function assertRecentContextEventResponse(
  value: unknown,
): asserts value is RecentContextEventResponse {
  const object = expectVersionedRecord(value, "RecentContextEventResponse");
  assertRecentContextEvent(object.event, "event");
}

export function assertRecentContextListResponse(
  value: unknown,
): asserts value is RecentContextListResponse {
  const object = expectVersionedRecord(value, "RecentContextListResponse");
  expectArray(object.items, "items").forEach((event, index) => {
    assertRecentContextEvent(event, `items[${index}]`);
  });
}

export function assertCurrentContextPacket(value: unknown): asserts value is CurrentContextPacket {
  const object = expectVersionedRecord(value, "CurrentContextPacket");
  expectString(object.user_id, "user_id");
  expectString(object.generated_at, "generated_at");
  expectString(object.summary, "summary");
  const window = expectRecord(object.window, "window");
  expectString(window.started_at, "window.started_at");
  expectString(window.ended_at, "window.ended_at");
  expectArray(object.recent_events, "recent_events").forEach((event, index) => {
    assertRecentContextEvent(event, `recent_events[${index}]`);
  });
  expectArray(object.active_entities, "active_entities").forEach((entity, index) => {
    expectString(entity, `active_entities[${index}]`);
  });
  expectRecord(object.metadata, "metadata");
}

export function assertSearchMemoryResponse(value: unknown): asserts value is SearchMemoryResponse {
  const object = expectVersionedRecord(value, "SearchMemoryResponse");
  expectString(object.query, "query");
  expectArray(object.items, "items").forEach((item, index) => {
    assertSearchMemoryItem(item, `items[${index}]`);
  });
  const debug = expectRecord(object.debug, "debug");
  expectArray(debug.matched_entities, "debug.matched_entities");
  expectRecord(debug.ranking, "debug.ranking");
}

export function assertHealthResponse(value: unknown): asserts value is HealthResponse {
  const object = expectVersionedRecord(value, "HealthResponse");
  expectEnum(object.status, ["ok", "degraded", "error"], "status");
  const service = expectRecord(object.service, "service");
  expectString(service.name, "service.name");
  expectString(service.version, "service.version");
  expectString(object.migration_version, "migration_version");
  const database = expectRecord(object.database, "database");
  expectString(database.path, "database.path");
  expectBoolean(database.schema_ready, "database.schema_ready");
  expectBoolean(database.vector_ready, "database.vector_ready");
  expectArray(object.checks, "checks");
  expectString(object.generated_at, "generated_at");
}

export function assertGraphQueryResponse(value: unknown): asserts value is GraphQueryResponse {
  const object = expectVersionedRecord(value, "GraphQueryResponse");
  expectString(object.start, "start");
  expectNumber(object.depth, "depth");
  expectEnum(object.direction, ["in", "out", "both"], "direction");
  expectArray(object.nodes, "nodes").forEach((node, index) => assertGraphNode(node, `nodes[${index}]`));
  expectArray(object.relations, "relations").forEach((relation, index) => {
    assertRelationRef(relation, `relations[${index}]`);
  });
  expectString(object.generated_at, "generated_at");
}

export function assertBrainSyncResponse(value: unknown): asserts value is BrainSyncResponse {
  const object = expectVersionedRecord(value, "BrainSyncResponse");
  assertMemoryJobRef(object.job, "job");
  expectArray(object.synced_pages, "synced_pages");
  expectArray(object.errors, "errors");
}

export function assertPromotionResponse(value: unknown): asserts value is PromotionResponse {
  const object = expectVersionedRecord(value, "PromotionResponse");
  expectString(object.candidate_id, "candidate_id");
  expectEnum(object.mode, PROMOTION_MODES, "mode");
  expectEnum(object.status, ["drafted", "applied", "conflict", "rejected"], "status");
  expectString(object.target_slug, "target_slug");
  expectString(object.suggested_edit, "suggested_edit");
  expectArray(object.evidence, "evidence").forEach((evidence, index) => {
    assertEvidence(evidence, `evidence[${index}]`);
  });
  expectRecord(object.metadata, "metadata");
}

export function assertDeleteResponse(value: unknown): asserts value is DeleteResponse {
  const object = expectVersionedRecord(value, "DeleteResponse");
  expectBoolean(object.deleted, "deleted");
  expectString(object.source, "source");
  expectString(object.id, "id");
  expectString(object.generated_at, "generated_at");
}

export class ContractValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ContractValidationError";
  }
}

function assertRecentContextEvent(value: unknown, path: string): asserts value is RecentContextEvent {
  const object = expectRecord(value, path);
  expectString(object.id, `${path}.id`);
  expectString(object.user_id, `${path}.user_id`);
  expectEnum(object.source, RECENT_CONTEXT_SOURCES, `${path}.source`);
  expectString(object.content, `${path}.content`);
  expectString(object.content_hash, `${path}.content_hash`);
  expectString(object.occurred_at, `${path}.occurred_at`);
  expectString(object.created_at, `${path}.created_at`);
  const metadata = expectRecord(object.metadata, `${path}.metadata`);
  expectString(metadata.context, `${path}.metadata.context`);
  expectArray(metadata.activities, `${path}.metadata.activities`);
  expectArray(metadata.key_elements, `${path}.metadata.key_elements`);
  expectString(metadata.user_intent, `${path}.metadata.user_intent`);
  expectNumber(metadata.display_num, `${path}.metadata.display_num`);
}

function assertSearchMemoryItem(value: unknown, path: string): asserts value is SearchMemoryItem {
  const object = expectRecord(value, path);
  expectString(object.id, `${path}.id`);
  expectEnum(object.source, MEMORY_SOURCES, `${path}.source`);
  expectString(object.content, `${path}.content`);
  expectString(object.user_id, `${path}.user_id`);
  expectArray(object.entity_ids, `${path}.entity_ids`).forEach((entityId, index) => {
    expectString(entityId, `${path}.entity_ids[${index}]`);
  });
  expectArray(object.relations, `${path}.relations`).forEach((relation, index) => {
    assertRelationRef(relation, `${path}.relations[${index}]`);
  });
  expectArray(object.evidence, `${path}.evidence`).forEach((evidence, index) => {
    assertEvidence(evidence, `${path}.evidence[${index}]`);
  });
  expectNumber(object.score, `${path}.score`);
  const scores = expectRecord(object.scores, `${path}.scores`);
  expectNumber(scores.vector, `${path}.scores.vector`);
  expectNumber(scores.keyword, `${path}.scores.keyword`);
  expectNumber(scores.graph, `${path}.scores.graph`);
  expectNumber(scores.recency, `${path}.scores.recency`);
  expectString(object.created_at, `${path}.created_at`);
  expectRecord(object.metadata, `${path}.metadata`);
}

function assertGraphNode(value: unknown, path: string): asserts value is GraphNode {
  const object = expectRecord(value, path);
  expectString(object.id, `${path}.id`);
  expectEnum(object.type, ENTITY_TYPES, `${path}.type`);
  expectString(object.name, `${path}.name`);
  expectArray(object.aliases, `${path}.aliases`);
  expectRecord(object.metadata, `${path}.metadata`);
}

function assertRelationRef(value: unknown, path: string): asserts value is RelationRef {
  const object = expectRecord(value, path);
  expectString(object.id, `${path}.id`);
  expectEnum(object.relation_type, RELATION_TYPES, `${path}.relation_type`);
  expectString(object.source_entity_id, `${path}.source_entity_id`);
  expectString(object.target_entity_id, `${path}.target_entity_id`);
  expectNumber(object.confidence, `${path}.confidence`);
  expectArray(object.evidence, `${path}.evidence`).forEach((evidence, index) => {
    assertEvidence(evidence, `${path}.evidence[${index}]`);
  });
}

function assertEvidence(value: unknown, path: string): asserts value is Evidence {
  const object = expectRecord(value, path);
  expectString(object.source, `${path}.source`);
  expectString(object.source_id, `${path}.source_id`);
}

function assertMemoryJobRef(value: unknown, path: string): asserts value is MemoryJobRef {
  const object = expectRecord(value, path);
  expectString(object.id, `${path}.id`);
  expectEnum(object.status, JOB_STATUSES, `${path}.status`);
  expectString(object.idempotency_key, `${path}.idempotency_key`);
}

function expectVersionedRecord(value: unknown, path: string): Record<string, unknown> {
  const object = expectRecord(value, path);
  expectSchemaVersion(object);
  return object;
}

function expectSchemaVersion(object: Record<string, unknown>): void {
  if (object.schema_version !== SCHEMA_VERSION) {
    throw new ContractValidationError(`schema_version must be ${SCHEMA_VERSION}`);
  }
}

function expectRecord(value: unknown, path: string): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new ContractValidationError(`${path} must be an object`);
  }
  return value as Record<string, unknown>;
}

function expectArray(value: unknown, path: string): unknown[] {
  if (!Array.isArray(value)) {
    throw new ContractValidationError(`${path} must be an array`);
  }
  return value;
}

function expectString(value: unknown, path: string): string {
  if (typeof value !== "string") {
    throw new ContractValidationError(`${path} must be a string`);
  }
  return value;
}

function expectNumber(value: unknown, path: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new ContractValidationError(`${path} must be a finite number`);
  }
  return value;
}

function expectBoolean(value: unknown, path: string): boolean {
  if (typeof value !== "boolean") {
    throw new ContractValidationError(`${path} must be a boolean`);
  }
  return value;
}

function expectEnum<T extends readonly string[]>(value: unknown, values: T, path: string): T[number] {
  if (typeof value !== "string" || !values.includes(value)) {
    throw new ContractValidationError(`${path} has unsupported value ${String(value)}`);
  }
  return value;
}
