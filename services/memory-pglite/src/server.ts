#!/usr/bin/env node

import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import { graphQuery, type GraphDirection } from "./graph/index.js";
import { openMemoryDatabase, type MemoryPgliteDatabase } from "./database/index.js";
import type { RelationType } from "./contracts/index.js";
import { RELATION_TYPES } from "./contracts/index.js";
import { searchMemory, type SearchScope } from "./search/index.js";

const DEFAULT_HOST = "127.0.0.1";
const DEFAULT_PORT = 8766;
const MAX_REQUEST_BYTES = 1_000_000;

export interface MemoryPgliteServerOptions {
  database?: MemoryPgliteDatabase;
}

export interface ListenOptions extends MemoryPgliteServerOptions {
  host?: string;
  port?: number;
}

export interface MemoryPgliteRequest {
  method: string;
  path: string;
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
  scopes?: SearchScope[];
  limit?: number;
  debug?: boolean;
}

export function createMemoryPgliteServer(options: MemoryPgliteServerOptions = {}): Server {
  const database = options.database;
  if (!database) {
    throw new Error("createMemoryPgliteServer requires an open database");
  }

  return createServer((request, response) => {
    void handleRequest(database, request, response);
  });
}

export async function listenMemoryPgliteServer(options: ListenOptions = {}): Promise<{
  server: Server;
  database: MemoryPgliteDatabase;
}> {
  const database = options.database ?? (await openMemoryDatabase());
  const server = createMemoryPgliteServer({ database });
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

  const result = await handleMemoryPgliteRequest(database, {
    method: request.method ?? "GET",
    path: url.pathname,
    body,
  });
  sendJson(response, result.status, result.body);
}

export async function handleMemoryPgliteRequest(
  database: MemoryPgliteDatabase,
  request: MemoryPgliteRequest,
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
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
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
