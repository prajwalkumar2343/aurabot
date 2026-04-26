#!/usr/bin/env node

import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import { resolveBrainDir } from "./brain/index.js";
import { graphQuery, type GraphDirection } from "./graph/index.js";
import { processGraphExtractionJobs } from "./graph/jobs.js";
import { openMemoryDatabase, type MemoryPgliteDatabase } from "./database/index.js";
import type { MemorySource, RecentContextEventInput, RecentContextSource, RelationType } from "./contracts/index.js";
import { RELATION_TYPES } from "./contracts/index.js";
import {
  deleteRecentContextEvent,
  getRecentContextEvents,
  insertRecentContextEvent,
  recentContextListResponse,
} from "./recent/events.js";
import {
  getCurrentContextPacket,
  summarizeRecentContext,
  type CurrentContextOptions,
  type SummarizeRecentContextInput,
} from "./recent/summaries.js";
import { searchMemory, type SearchScope } from "./search/index.js";

const DEFAULT_HOST = "127.0.0.1";
const DEFAULT_PORT = 8766;
const MAX_REQUEST_BYTES = 1_000_000;

export interface MemoryPgliteServerOptions {
  database?: MemoryPgliteDatabase;
  brainRootDir?: string;
}

export interface ListenOptions extends MemoryPgliteServerOptions {
  host?: string;
  port?: number;
}

export interface MemoryPgliteRequest {
  method: string;
  path: string;
  query?: Record<string, string | undefined>;
  body?: unknown;
}

export interface MemoryPgliteResponse {
  status: number;
  body: unknown;
}

interface GraphQueryRequest {
  user_id: string;
  start: string;
  relation_types?: RelationType[];
  depth?: number;
  direction?: GraphDirection;
  limit?: number;
}

interface SearchMemoryRequest {
  query: string;
  user_id: string;
  agent_id?: string;
  scopes?: SearchScope[];
  limit?: number;
  debug?: boolean;
}

interface RecentContextQueryRequest {
  user_id: string;
  agent_id?: string;
  started_at?: string;
  ended_at?: string;
  source?: string;
  app?: string;
  domain?: string;
  repo_path?: string;
  file_path?: string;
  limit?: number;
}

interface SummarizeRecentContextRequest {
  user_id: string;
  agent_id?: string;
  idempotency_key: string;
  window: {
    started_at: string;
    ended_at: string;
  };
  mode?: "deterministic";
  write_markdown?: boolean;
}

export function createMemoryPgliteServer(options: MemoryPgliteServerOptions = {}): Server {
  const database = options.database;
  if (!database) {
    throw new Error("createMemoryPgliteServer requires an open database");
  }
  const requestOptions = { brainRootDir: options.brainRootDir ?? resolveBrainDir() };

  return createServer((request, response) => {
    void handleRequest(database, request, response, requestOptions);
  });
}

export async function listenMemoryPgliteServer(options: ListenOptions = {}): Promise<{
  server: Server;
  database: MemoryPgliteDatabase;
}> {
  const database = options.database ?? (await openMemoryDatabase());
  const serverOptions: MemoryPgliteServerOptions = { database };
  if (options.brainRootDir) {
    serverOptions.brainRootDir = options.brainRootDir;
  }
  const server = createMemoryPgliteServer(serverOptions);
  const host = options.host ?? process.env.AURABOT_MEMORY_PGLITE_HOST ?? DEFAULT_HOST;
  const port = options.port ?? parsePort(process.env.AURABOT_MEMORY_PGLITE_PORT, DEFAULT_PORT);

  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, host, () => {
      server.off("error", reject);
      resolve();
    });
  });

  return { server, database };
}

async function handleRequest(
  database: MemoryPgliteDatabase,
  request: IncomingMessage,
  response: ServerResponse,
  options: Pick<MemoryPgliteServerOptions, "brainRootDir"> = {},
): Promise<void> {
  const url = new URL(request.url ?? "/", "http://localhost");
  let body: unknown;

  if (request.method === "POST") {
    try {
      body = await readJsonBody(request);
    } catch (error) {
      sendJson(response, error instanceof RequestError ? error.status : 400, {
        schema_version: "memory-v2",
        error: {
          code: "invalid_request",
          message: error instanceof Error ? error.message : "Invalid JSON request body",
        },
      });
      return;
    }
  }

  const result = await handleMemoryPgliteRequest(
    database,
    {
      method: request.method ?? "GET",
      path: url.pathname,
      query: Object.fromEntries(url.searchParams.entries()),
      body,
    },
    options,
  );
  sendJson(response, result.status, result.body);
}

export async function handleMemoryPgliteRequest(
  database: MemoryPgliteDatabase,
  request: MemoryPgliteRequest,
  options: Pick<MemoryPgliteServerOptions, "brainRootDir"> = {},
): Promise<MemoryPgliteResponse> {
  if (request.method === "OPTIONS") {
    return { status: 200, body: {} };
  }

  if (request.method === "GET" && request.path === "/v2/health") {
    return {
      status: 200,
      body: {
        schema_version: "memory-v2",
        status: "ok",
        service: {
          name: "aurabot-memory-pglite",
          version: "0.1.0",
        },
        database: {
          path: database.dataDir,
        },
        generated_at: new Date().toISOString(),
      },
    };
  }

  if (request.method === "POST" && request.path === "/v2/graph/query") {
    return handleGraphQuery(database, request.body);
  }

  if (request.method === "POST" && request.path === "/v2/search") {
    return handleSearchMemory(database, request.body);
  }

  if (request.method === "POST" && request.path === "/v2/recent-context") {
    return handleInsertRecentContext(database, request.body);
  }

  if (request.method === "GET" && request.path === "/v2/recent-context") {
    return handleListRecentContext(database, request.query ?? {});
  }

  if (request.method === "GET" && request.path === "/v2/current-context") {
    return handleCurrentContext(database, request.query ?? {});
  }

  if (request.method === "POST" && request.path === "/v2/recent-context/summaries") {
    return handleSummarizeRecentContext(database, request.body, options);
  }

  const deleteMatch = request.path.match(/^\/v2\/memories\/([^/]+)\/([^/]+)$/);
  if (request.method === "DELETE" && deleteMatch) {
    return handleDeleteMemory(database, deleteMatch[1] ?? "", deleteMatch[2] ?? "", request.query ?? {});
  }

  return {
    status: 404,
    body: {
      schema_version: "memory-v2",
      error: {
        code: "not_found",
        message: "Route not found",
      },
    },
  };
}

async function handleInsertRecentContext(
  database: MemoryPgliteDatabase,
  body: unknown,
): Promise<MemoryPgliteResponse> {
  try {
    const input = parseRecentContextEventInput(body);
    const event = await insertRecentContextEvent(database, input);
    await processGraphExtractionJobs(database, { limit: 10 });
    return {
      status: 200,
      body: {
        schema_version: "memory-v2",
        event,
      },
    };
  } catch (error) {
    return {
      status: 400,
      body: {
        schema_version: "memory-v2",
        error: {
          code: "invalid_recent_context",
          message: error instanceof Error ? error.message : "Recent context insert failed",
        },
      },
    };
  }
}

async function handleListRecentContext(
  database: MemoryPgliteDatabase,
  query: Record<string, string | undefined>,
): Promise<MemoryPgliteResponse> {
  try {
    const input = parseRecentContextQueryRequest(query);
    const recentQuery: Parameters<typeof getRecentContextEvents>[1] = {
      userId: input.user_id,
    };
    if (input.agent_id) {
      recentQuery.agentId = input.agent_id;
    }
    if (input.started_at) {
      recentQuery.startedAt = input.started_at;
    }
    if (input.ended_at) {
      recentQuery.endedAt = input.ended_at;
    }
    if (input.source) {
      recentQuery.source = input.source;
    }
    if (input.app) {
      recentQuery.app = input.app;
    }
    if (input.domain) {
      recentQuery.domain = input.domain;
    }
    if (input.repo_path) {
      recentQuery.repoPath = input.repo_path;
    }
    if (input.file_path) {
      recentQuery.filePath = input.file_path;
    }
    if (input.limit !== undefined) {
      recentQuery.limit = input.limit;
    }

    const result = await getRecentContextEvents(database, recentQuery);
    return { status: 200, body: recentContextListResponse(result) };
  } catch (error) {
    return {
      status: 400,
      body: {
        schema_version: "memory-v2",
        error: {
          code: "invalid_recent_context_query",
          message: error instanceof Error ? error.message : "Recent context query failed",
        },
      },
    };
  }
}

async function handleCurrentContext(
  database: MemoryPgliteDatabase,
  query: Record<string, string | undefined>,
): Promise<MemoryPgliteResponse> {
  try {
    const userId = requiredString(query.user_id, "user_id");
    const input: CurrentContextOptions = {
      userId,
    };
    const agentId = optionalString(query.agent_id);
    if (agentId) {
      input.agentId = agentId;
    }
    if (query.hours !== undefined) {
      input.hours = optionalNumber(query.hours, "hours");
    }
    if (query.limit !== undefined) {
      input.recentEventsLimit = optionalInteger(query.limit, "limit");
    }

    const result = await getCurrentContextPacket(database, input);
    return { status: 200, body: result };
  } catch (error) {
    return {
      status: 400,
      body: {
        schema_version: "memory-v2",
        error: {
          code: "invalid_current_context",
          message: error instanceof Error ? error.message : "Current context query failed",
        },
      },
    };
  }
}

async function handleDeleteMemory(
  database: MemoryPgliteDatabase,
  source: string,
  id: string,
  query: Record<string, string | undefined>,
): Promise<MemoryPgliteResponse> {
  try {
    const decodedSource = decodeURIComponent(source) as MemorySource;
    const decodedId = decodeURIComponent(id);
    const userId = requiredString(query.user_id, "user_id");

    if (decodedSource !== "recent_context") {
      return {
        status: 400,
        body: {
          schema_version: "memory-v2",
          error: {
            code: "unsupported_delete_source",
            message: `Delete is not supported for source: ${decodedSource}`,
          },
        },
      };
    }

    const deleted = await deleteRecentContextEvent(database, {
      userId,
      id: decodedId,
    });

    return {
      status: deleted ? 200 : 404,
      body: {
        schema_version: "memory-v2",
        deleted,
        source: decodedSource,
        id: decodedId,
        generated_at: new Date().toISOString(),
      },
    };
  } catch (error) {
    return {
      status: 400,
      body: {
        schema_version: "memory-v2",
        error: {
          code: "invalid_delete",
          message: error instanceof Error ? error.message : "Delete failed",
        },
      },
    };
  }
}

async function handleSummarizeRecentContext(
  database: MemoryPgliteDatabase,
  body: unknown,
  options: Pick<MemoryPgliteServerOptions, "brainRootDir">,
): Promise<MemoryPgliteResponse> {
  try {
    const input = parseSummarizeRecentContextRequest(body);
    const writeMarkdown = input.write_markdown ?? true;
    const summaryInput: SummarizeRecentContextInput = {
      userId: input.user_id,
      idempotencyKey: input.idempotency_key,
      window: input.window,
    };
    if (input.agent_id) {
      summaryInput.agentId = input.agent_id;
    }
    if (input.mode) {
      summaryInput.mode = input.mode;
    }
    if (writeMarkdown) {
      summaryInput.markdown = {
        rootDir: options.brainRootDir ?? resolveBrainDir(),
        syncAfterWrite: true,
      };
    }

    const result = await summarizeRecentContext(database, summaryInput);
    return { status: 200, body: result };
  } catch (error) {
    return {
      status: 400,
      body: {
        schema_version: "memory-v2",
        error: {
          code: "invalid_recent_context_summary",
          message: error instanceof Error ? error.message : "Recent context summary failed",
        },
      },
    };
  }
}

async function handleGraphQuery(
  database: MemoryPgliteDatabase,
  body: unknown,
): Promise<MemoryPgliteResponse> {
  try {
    const input = parseGraphQueryRequest(body);
    const graphInput: {
      userId: string;
      start: string;
      relationTypes?: RelationType[];
      depth?: number;
      direction?: GraphDirection;
      limit?: number;
    } = {
      userId: input.user_id,
      start: input.start,
    };
    if (input.relation_types) {
      graphInput.relationTypes = input.relation_types;
    }
    if (input.depth !== undefined) {
      graphInput.depth = input.depth;
    }
    if (input.direction) {
      graphInput.direction = input.direction;
    }
    if (input.limit !== undefined) {
      graphInput.limit = input.limit;
    }

    const result = await graphQuery(database, graphInput);
    return { status: 200, body: result };
  } catch (error) {
    return {
      status: 400,
      body: {
        schema_version: "memory-v2",
        error: {
          code: "invalid_graph_query",
          message: error instanceof Error ? error.message : "Graph query failed",
        },
      },
    };
  }
}

async function handleSearchMemory(
  database: MemoryPgliteDatabase,
  body: unknown,
): Promise<MemoryPgliteResponse> {
  try {
    const input = parseSearchMemoryRequest(body);
    const searchInput: {
      query: string;
      userId: string;
      scopes?: SearchScope[];
      limit?: number;
      debug?: boolean;
    } = {
      query: input.query,
      userId: input.user_id,
    };
    if (input.scopes) {
      searchInput.scopes = input.scopes;
    }
    if (input.limit !== undefined) {
      searchInput.limit = input.limit;
    }
    if (input.debug !== undefined) {
      searchInput.debug = input.debug;
    }

    const result = await searchMemory(database, searchInput);
    return { status: 200, body: result };
  } catch (error) {
    return {
      status: 400,
      body: {
        schema_version: "memory-v2",
        error: {
          code: "invalid_search",
          message: error instanceof Error ? error.message : "Search failed",
        },
      },
    };
  }
}

function parseGraphQueryRequest(value: unknown): GraphQueryRequest {
  if (!isRecord(value)) {
    throw new RequestError("Request body must be an object", 400);
  }

  const userId = requiredString(value.user_id, "user_id");
  const start = requiredString(value.start, "start");
  const request: GraphQueryRequest = {
    user_id: userId,
    start,
  };

  const relationTypes = optionalStringArray(value.relation_types, "relation_types");
  if (relationTypes) {
    request.relation_types = relationTypes.map((entry) => {
      if (!RELATION_TYPES.includes(entry as RelationType)) {
        throw new RequestError(`Unsupported relation type: ${entry}`, 400);
      }
      return entry as RelationType;
    });
  }

  if (value.depth !== undefined) {
    request.depth = optionalInteger(value.depth, "depth");
  }
  if (value.limit !== undefined) {
    request.limit = optionalInteger(value.limit, "limit");
  }
  if (value.direction !== undefined) {
    const direction = requiredString(value.direction, "direction");
    if (!["in", "out", "both"].includes(direction)) {
      throw new RequestError("direction must be one of: in, out, both", 400);
    }
    request.direction = direction as GraphDirection;
  }

  return request;
}

function parseSearchMemoryRequest(value: unknown): SearchMemoryRequest {
  if (!isRecord(value)) {
    throw new RequestError("Request body must be an object", 400);
  }

  const request: SearchMemoryRequest = {
    query: requiredString(value.query, "query"),
    user_id: requiredString(value.user_id, "user_id"),
  };

  if (value.agent_id !== undefined) {
    request.agent_id = requiredString(value.agent_id, "agent_id");
  }
  const scopes = optionalStringArray(value.scopes, "scopes");
  if (scopes) {
    request.scopes = scopes.map((scope) => {
      if (!["recent", "long_term", "graph", "all"].includes(scope)) {
        throw new RequestError(`Unsupported search scope: ${scope}`, 400);
      }
      return scope as SearchScope;
    });
  }
  if (value.limit !== undefined) {
    request.limit = optionalInteger(value.limit, "limit");
  }
  if (value.debug !== undefined) {
    if (typeof value.debug !== "boolean") {
      throw new RequestError("debug must be a boolean", 400);
    }
    request.debug = value.debug;
  }

  return request;
}

function parseRecentContextEventInput(value: unknown): RecentContextEventInput {
  if (!isRecord(value)) {
    throw new RequestError("Request body must be an object", 400);
  }

  const source = requiredString(value.source, "source") as RecentContextSource;
  if (!["screen", "app", "browser", "repo", "file", "terminal", "system"].includes(source)) {
    throw new RequestError(`Unsupported recent context source: ${source}`, 400);
  }

  const metadata = isRecord(value.metadata) ? value.metadata : {};
  const input: RecentContextEventInput = {
    user_id: requiredString(value.user_id, "user_id"),
    idempotency_key: requiredString(value.idempotency_key, "idempotency_key"),
    source,
    content: requiredString(value.content, "content"),
    occurred_at: requiredString(value.occurred_at, "occurred_at"),
    metadata: metadata as RecentContextEventInput["metadata"],
  };

  if (value.agent_id !== undefined) {
    input.agent_id = requiredString(value.agent_id, "agent_id");
  }
  if (value.ttl_seconds !== undefined) {
    input.ttl_seconds = optionalInteger(value.ttl_seconds, "ttl_seconds");
  }
  if (value.importance !== undefined) {
    input.importance = optionalNumber(value.importance, "importance");
  }

  return input;
}

function parseRecentContextQueryRequest(
  value: Record<string, string | undefined>,
): RecentContextQueryRequest {
  const request: RecentContextQueryRequest = {
    user_id: requiredString(value.user_id, "user_id"),
  };

  assignOptionalString(request, "agent_id", value.agent_id);
  assignOptionalString(request, "started_at", value.started_at);
  assignOptionalString(request, "ended_at", value.ended_at);
  assignOptionalString(request, "source", value.source);
  assignOptionalString(request, "app", value.app);
  assignOptionalString(request, "domain", value.domain);
  assignOptionalString(request, "repo_path", value.repo_path);
  assignOptionalString(request, "file_path", value.file_path);
  if (value.limit !== undefined) {
    request.limit = optionalInteger(value.limit, "limit");
  }

  return request;
}

function parseSummarizeRecentContextRequest(value: unknown): SummarizeRecentContextRequest {
  if (!isRecord(value)) {
    throw new RequestError("Request body must be an object", 400);
  }

  const window = isRecord(value.window) ? value.window : undefined;
  if (!window) {
    throw new RequestError("window is required", 400);
  }

  const request: SummarizeRecentContextRequest = {
    user_id: requiredString(value.user_id, "user_id"),
    idempotency_key: requiredString(value.idempotency_key, "idempotency_key"),
    window: {
      started_at: requiredString(window.started_at, "window.started_at"),
      ended_at: requiredString(window.ended_at, "window.ended_at"),
    },
  };

  if (value.agent_id !== undefined) {
    request.agent_id = requiredString(value.agent_id, "agent_id");
  }
  if (value.mode !== undefined) {
    const mode = requiredString(value.mode, "mode");
    if (mode !== "deterministic") {
      throw new RequestError("mode must be deterministic", 400);
    }
    request.mode = mode;
  }
  if (value.write_markdown !== undefined) {
    request.write_markdown = optionalBoolean(value.write_markdown, "write_markdown");
  }

  return request;
}

async function readJsonBody(request: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  let totalBytes = 0;

  for await (const chunk of request) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    totalBytes += buffer.length;
    if (totalBytes > MAX_REQUEST_BYTES) {
      throw new RequestError("Request body too large", 413);
    }
    chunks.push(buffer);
  }

  const rawBody = Buffer.concat(chunks).toString("utf8").trim();
  if (!rawBody) {
    return {};
  }

  try {
    return JSON.parse(rawBody) as unknown;
  } catch {
    throw new RequestError("Invalid JSON body", 400);
  }
}

function sendJson(response: ServerResponse, status: number, payload: unknown): void {
  response.writeHead(status, {
    "Access-Control-Allow-Headers": "authorization, content-type",
    "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
    "Access-Control-Allow-Origin": "*",
    "Content-Type": "application/json",
  });
  response.end(JSON.stringify(payload));
}

function requiredString(value: unknown, field: string): string {
  if (typeof value !== "string" || !value.trim()) {
    throw new RequestError(`${field} is required`, 400);
  }
  return value.trim();
}

function optionalStringArray(value: unknown, field: string): string[] | undefined {
  if (value === undefined) {
    return undefined;
  }
  if (!Array.isArray(value)) {
    throw new RequestError(`${field} must be an array`, 400);
  }
  return value.map((entry) => requiredString(entry, `${field}[]`));
}

function optionalInteger(value: unknown, field: string): number {
  const numberValue = Number(value);
  if (!Number.isInteger(numberValue)) {
    throw new RequestError(`${field} must be an integer`, 400);
  }
  return numberValue;
}

function optionalNumber(value: unknown, field: string): number {
  const numberValue = Number(value);
  if (!Number.isFinite(numberValue)) {
    throw new RequestError(`${field} must be a number`, 400);
  }
  return numberValue;
}

function optionalString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

function assignOptionalString<T extends object, K extends keyof T>(
  target: T,
  key: K,
  value: unknown,
): void {
  const normalized = optionalString(value);
  if (normalized) {
    target[key] = normalized as T[K];
  }
}

function optionalBoolean(value: unknown, field: string): boolean {
  if (typeof value !== "boolean") {
    throw new RequestError(`${field} must be a boolean`, 400);
  }
  return value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function parsePort(value: string | undefined, fallback: number): number {
  if (!value) {
    return fallback;
  }
  const port = Number(value);
  return Number.isInteger(port) && port > 0 && port <= 65535 ? port : fallback;
}

class RequestError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
    this.name = "RequestError";
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const { server, database } = await listenMemoryPgliteServer();
  const address = server.address();
  const addressText =
    typeof address === "object" && address
      ? `${address.address}:${address.port}`
      : String(address ?? "unknown");
  console.log(`AuraBot Memory PGlite listening on ${addressText}`);

  async function shutdown(): Promise<void> {
    await new Promise<void>((resolve) => server.close(() => resolve()));
    await database.close();
  }

  process.once("SIGINT", () => {
    void shutdown().then(() => process.exit(0));
  });
  process.once("SIGTERM", () => {
    void shutdown().then(() => process.exit(0));
  });
}
