import assert from "node:assert/strict";
import { join } from "node:path";
import { describe, it } from "node:test";
import { openMemoryDatabase } from "../../src/database/index.js";
import { extractGraphForRecentContextEvent } from "../../src/graph/index.js";
import { insertRecentContextEvent } from "../../src/recent/events.js";
import { handleMemoryPgliteRequest } from "../../src/server.js";
import { withTempDir } from "../helpers/temp-dir.js";

describe("Memory PGlite search route", () => {
  it("serves POST /v2/search from searchMemory()", async () => {
    await withTempDir(async (dir) => {
      const database = await openMemoryDatabase({
        dataDir: join(dir, "pglite"),
        embeddingDimensions: 3,
      });

      try {
        const event = await insertRecentContextEvent(database, {
          user_id: "default_user",
          idempotency_key: "server-search-route",
          source: "browser",
          content: "Using AuraBot graph search with docs.example.com.",
          occurred_at: "2026-04-22T09:10:00.000Z",
          metadata: {
            context: "Search route test",
            activities: ["testing"],
            key_elements: ["AuraBot", "docs.example.com"],
            user_intent: "verify /v2/search",
            display_num: 1,
            app_name: "Cursor",
            url: "https://docs.example.com/search",
            projects: ["AuraBot"],
          },
        });
        await extractGraphForRecentContextEvent(database, event.id, {
          now: "2026-04-22T09:11:00.000Z",
        });

        const response = await handleMemoryPgliteRequest(database, {
          method: "POST",
          path: "/v2/search",
          body: {
            user_id: "default_user",
            query: "AuraBot docs.example.com",
            scopes: ["all"],
            limit: 5,
          },
        });

        assert.equal(response.status, 200);
        const payload = response.body as {
          schema_version: string;
          query: string;
          items: Array<{ source: string; evidence: Array<{ source_id: string }> }>;
        };
        assert.equal(payload.schema_version, "memory-v2");
        assert.equal(payload.query, "AuraBot docs.example.com");
        assert.ok(payload.items.length > 0);
        assert.ok(payload.items.some((item) => item.evidence.some((evidence) => evidence.source_id === event.id)));
      } finally {
        await database.close();
      }
    });
  });

  it("rejects malformed search requests", async () => {
    await withTempDir(async (dir) => {
      const database = await openMemoryDatabase({
        dataDir: join(dir, "pglite"),
        embeddingDimensions: 3,
      });

      try {
        const response = await handleMemoryPgliteRequest(database, {
          method: "POST",
          path: "/v2/search",
          body: {
            user_id: "default_user",
            scopes: ["unsupported"],
          },
        });

        assert.equal(response.status, 400);
        const payload = response.body as { schema_version: string; error: { code: string } };
        assert.equal(payload.schema_version, "memory-v2");
        assert.equal(payload.error.code, "invalid_search");
      } finally {
        await database.close();
      }
    });
  });
});
