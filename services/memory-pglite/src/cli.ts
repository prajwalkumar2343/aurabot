#!/usr/bin/env node

import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { initializeBrainRepository, resolveBrainDir } from "./brain/index.js";
import { openMemoryDatabase } from "./database/index.js";
import { extractGraphForRecentContextEvent, graphQuery } from "./graph/index.js";
import { syncBrainPages } from "./indexing/index.js";
import { insertRecentContextEvent } from "./recent/events.js";
import { searchMemory } from "./search/index.js";
import { checkSchema } from "./schema/check.js";

const command = process.argv[2];

async function main(): Promise<void> {
  switch (command) {
    case "smoke":
      await smoke();
      break;
    case "schema:check":
      await schemaCheck();
      break;
    case "brain:init":
      await brainInit();
      break;
    case "brain:sync":
      await brainSync();
      break;
    case "graph:smoke":
      await graphSmoke();
      break;
    case "search:smoke":
      await searchSmoke();
      break;
    default:
      console.error(`Unknown command: ${command ?? "(missing)"}`);
      console.error(
        "Available commands: smoke, schema:check, brain:init, brain:sync, graph:smoke, search:smoke",
      );
      process.exitCode = 2;
  }
}

async function smoke(): Promise<void> {
  const dataDir =
    process.env.AURABOT_PGLITE_TEST_DIR ?? (await mkdtemp(join(tmpdir(), "aurabot-pglite-")));
  const database = await openMemoryDatabase({ dataDir });

  try {
    const selectResult = await database.query<{ ok: number }>("SELECT 1 AS ok");
    await database.assertVectorReady();
    const schema = await checkSchema(database);

    console.log(
      JSON.stringify(
        {
          ok: selectResult.rows[0]?.ok === 1 && schema.ok,
          data_dir: dataDir,
          schema,
        },
        null,
        2,
      ),
    );

    if (selectResult.rows[0]?.ok !== 1 || !schema.ok) {
      process.exitCode = 1;
    }
  } finally {
    await database.close();
  }
}

async function schemaCheck(): Promise<void> {
  const database = await openMemoryDatabase();
  try {
    const result = await checkSchema(database);
    console.log(JSON.stringify(result, null, 2));
    if (!result.ok) {
      process.exitCode = 1;
    }
  } finally {
    await database.close();
  }
}

async function brainInit(): Promise<void> {
  const rootDir = resolveBrainDir();
  const result = await initializeBrainRepository(rootDir);
  console.log(JSON.stringify(result, null, 2));
}

async function brainSync(): Promise<void> {
  const rootDir = resolveBrainDir();
  const userId = process.env.AURABOT_MEMORY_USER_ID?.trim() || "default_user";
  const database = await openMemoryDatabase();
  try {
    const result = await syncBrainPages(database, {
      rootDir,
      userId,
    });
    console.log(JSON.stringify(result, null, 2));
    if (result.errors.length > 0) {
      process.exitCode = 1;
    }
  } finally {
    await database.close();
  }
}

async function graphSmoke(): Promise<void> {
  const dataDir =
    process.env.AURABOT_PGLITE_TEST_DIR ?? (await mkdtemp(join(tmpdir(), "aurabot-pglite-graph-")));
  const database = await openMemoryDatabase({ dataDir });
  try {
    const event = await seedSmokeRecentContext(database);
    const extracted = await extractGraphForRecentContextEvent(database, event.id);
    const graph = await graphQuery(database, {
      userId: event.user_id,
      start: "AuraBot",
      depth: 2,
      direction: "both",
    });
    const ok =
      extracted.entities.length > 0 &&
      extracted.relations.length > 0 &&
      graph.nodes.length > 0 &&
      graph.relations.every((relation) => relation.evidence.length > 0);

    console.log(
      JSON.stringify(
        {
          ok,
          data_dir: dataDir,
          extracted: {
            entities: extracted.entities.length,
            relations: extracted.relations.length,
          },
          graph,
        },
        null,
        2,
      ),
    );
    if (!ok) {
      process.exitCode = 1;
    }
  } finally {
    await database.close();
  }
}

async function searchSmoke(): Promise<void> {
  const dataDir =
    process.env.AURABOT_PGLITE_TEST_DIR ?? (await mkdtemp(join(tmpdir(), "aurabot-pglite-search-")));
  const database = await openMemoryDatabase({ dataDir });
  try {
    const event = await seedSmokeRecentContext(database);
    await extractGraphForRecentContextEvent(database, event.id);
    const result = await searchMemory(database, {
      userId: event.user_id,
      query: "AuraBot docs.example.com graph search",
      limit: 5,
    });
    const ok =
      result.schema_version === "memory-v2" &&
      result.items.length > 0 &&
      result.items.some((item) => item.evidence.some((evidence) => evidence.source_id === event.id));

    console.log(
      JSON.stringify(
        {
          ok,
          data_dir: dataDir,
          result,
        },
        null,
        2,
      ),
    );
    if (!ok) {
      process.exitCode = 1;
    }
  } finally {
    await database.close();
  }
}

async function seedSmokeRecentContext(database: Awaited<ReturnType<typeof openMemoryDatabase>>) {
  return insertRecentContextEvent(database, {
    user_id: process.env.AURABOT_MEMORY_USER_ID?.trim() || "default_user",
    idempotency_key: `agent4-smoke-${database.dataDir}`,
    source: "browser",
    content: "Working on AuraBot graph-aware memory search while reading docs.example.com.",
    occurred_at: new Date().toISOString(),
    metadata: {
      context: "Agent 4 graph smoke",
      activities: ["reading", "editing"],
      key_elements: ["AuraBot", "docs.example.com"],
      user_intent: "verify graph-aware retrieval",
      display_num: 1,
      app_name: "Cursor",
      url: "https://docs.example.com/memory",
      repo_path: "/Users/administrator/Downloads/aurabot",
      projects: ["AuraBot"],
    },
  });
}

await main();
