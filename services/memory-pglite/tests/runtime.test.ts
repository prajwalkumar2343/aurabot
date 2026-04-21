import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { openMemoryDatabase } from "../src/database/index.js";
import { checkSchema } from "../src/schema/check.js";
import { withTempDir } from "./helpers/temp-dir.js";

describe("PGlite runtime", () => {
  it("opens a database, applies migrations, and supports vector casts", async () => {
    await withTempDir(async (dir) => {
      const database = await openMemoryDatabase({ dataDir: dir, embeddingDimensions: 3 });
      try {
        const result = await database.query<{ ok: number }>("SELECT 1 AS ok");
        assert.equal(result.rows[0]?.ok, 1);

        await database.assertVectorReady();

        const schema = await checkSchema(database);
        assert.equal(schema.ok, true);
        assert.equal(schema.missing_tables.length, 0);
        assert.equal(schema.vector_ready, true);
      } finally {
        await database.close();
      }
    });
  });

  it("guards against multiple open service instances for the same data directory", async () => {
    await withTempDir(async (dir) => {
      const database = await openMemoryDatabase({ dataDir: dir, embeddingDimensions: 3 });
      try {
        await assert.rejects(
          () => openMemoryDatabase({ dataDir: dir, embeddingDimensions: 3 }),
          /appears to be in use/,
        );
      } finally {
        await database.close();
      }
    });
  });
});
