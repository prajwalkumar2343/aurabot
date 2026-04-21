#!/usr/bin/env node

import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { openMemoryDatabase } from "./database/index.js";
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
    default:
      console.error(`Unknown command: ${command ?? "(missing)"}`);
      console.error("Available commands: smoke, schema:check");
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

await main();
