import assert from "node:assert/strict";
import { join } from "node:path";
import { describe, it } from "node:test";
import { openMemoryDatabase } from "../../src/database/index.js";
import { extractGraphForRecentContextEvent } from "../../src/graph/index.js";
import { insertRecentContextEvent } from "../../src/recent/events.js";
import { handleMemoryPgliteRequest } from "../../src/server.js";
import { withTempDir } from "../helpers/temp-dir.js";

describe("Memory PGlite HTTP server", () => {
  it("serves POST /v2/graph/query from graphQuery()", async () => {
    await withTempDir(async (dir) => {
      const database = await openMemoryDatabase({
        dataDir: join(dir, "pglite"),
        embeddingDimensions: 3,
      });

      try {
        const event = await insertRecentContextEvent(database, {
          user_id: "default_user",
          idempotency_key: "server-graph-query-route",
          source: "browser",
          content: "Using AuraBot with docs.example.com for graph query route testing.",
          occurred_at: "2026-04-22T09:00:00.000Z",
          metadata: {
            context: "Graph route test",
            activities: ["testing"],
            key_elements: ["AuraBot", "docs.example.com"],
            user_intent: "verify /v2/graph/query",
            display_num: 1,
            app_name: "Cursor",
            url: "https://docs.example.com/graph",
            projects: ["AuraBot"],
          },
        });
        await extractGraphForRecentContextEvent(database, event.id, {
          now: "2026-04-22T09:01:00.000Z",
        });

        const response = await handleMemoryPgliteRequest(database, {
          method: "POST",
          path: "/v2/graph/query",
          body: {
            user_id: "default_user",
            start: "AuraBot",
            depth: 2,
            direction: "both",
            relation_types: ["uses", "visited"],
          },
        });

        assert.equal(response.status, 200);
        const payload = response.body as {
          schema_version: string;
          nodes: Array<{ type: string; name: string }>;
          relations: Array<{ relation_type: string; evidence: unknown[] }>;
        };
        assert.equal(payload.schema_version, "memory-v2");
        assert.ok(payload.nodes.some((node) => node.type === "website"));
        assert.ok(payload.relations.some((relation) => relation.relation_type === "visited"));
        assert.ok(payload.relations.every((relation) => relation.evidence.length > 0));
      } finally {
        await database.close();
      }
    });
  });

  it("rejects malformed graph query requests", async () => {
    await withTempDir(async (dir) => {
      const database = await openMemoryDatabase({
        dataDir: join(dir, "pglite"),
        embeddingDimensions: 3,
      });

      try {
        const response = await handleMemoryPgliteRequest(database, {
          method: "POST",
          path: "/v2/graph/query",
          body: {
            user_id: "default_user",
            relation_types: ["not_a_relation"],
          },
        });

        assert.equal(response.status, 400);
        const payload = response.body as { schema_version: string; error: { code: string } };
        assert.equal(payload.schema_version, "memory-v2");
        assert.equal(payload.error.code, "invalid_graph_query");
      } finally {
        await database.close();
      }
    });
  });
});
