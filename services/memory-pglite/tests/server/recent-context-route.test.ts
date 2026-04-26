import assert from "node:assert/strict";
import { join } from "node:path";
import { describe, it } from "node:test";
import { openMemoryDatabase } from "../../src/database/index.js";
import { handleMemoryPgliteRequest } from "../../src/server.js";
import { withTempDir } from "../helpers/temp-dir.js";

describe("Memory PGlite recent context routes", () => {
  it("serves the Swift app recent-context lifecycle", async () => {
    await withTempDir(async (dir) => {
      const database = await openMemoryDatabase({
        dataDir: join(dir, "pglite"),
        embeddingDimensions: 3,
      });

      try {
        const insert = await handleMemoryPgliteRequest(database, {
          method: "POST",
          path: "/v2/recent-context",
          body: {
            user_id: "default_user",
            agent_id: "screen_memories_v3",
            idempotency_key: "server-recent-context-route",
            source: "browser",
            content: "Working on AuraBot graph-aware memory search while reading docs.example.com.",
            occurred_at: "2026-04-22T10:00:00.000Z",
            ttl_seconds: 21600,
            importance: 0.5,
            metadata: {
              context: "Recent context route test",
              activities: ["testing"],
              key_elements: ["AuraBot", "PGlite"],
              user_intent: "verify app memory routes",
              display_num: 1,
              app_name: "Cursor",
              browser: "Google Chrome",
              url: "https://docs.example.com/memory",
              repo_path: "/Users/administrator/Downloads/aurabot",
              projects: ["AuraBot"],
            },
          },
        });

        assert.equal(insert.status, 200);
        const inserted = insert.body as {
          schema_version: string;
          event: { id: string; user_id: string; agent_id: string; source: string };
        };
        assert.equal(inserted.schema_version, "memory-v2");
        assert.equal(inserted.event.user_id, "default_user");
        assert.equal(inserted.event.agent_id, "screen_memories_v3");
        assert.equal(inserted.event.source, "browser");

        const list = await handleMemoryPgliteRequest(database, {
          method: "GET",
          path: "/v2/recent-context",
          query: {
            user_id: "default_user",
            agent_id: "screen_memories_v3",
            limit: "10",
          },
        });

        assert.equal(list.status, 200);
        const listed = list.body as { schema_version: string; items: Array<{ id: string }> };
        assert.equal(listed.schema_version, "memory-v2");
        assert.equal(listed.items.length, 1);
        assert.equal(listed.items[0]?.id, inserted.event.id);

        const current = await handleMemoryPgliteRequest(database, {
          method: "GET",
          path: "/v2/current-context",
          query: {
            user_id: "default_user",
            agent_id: "screen_memories_v3",
            hours: "200",
          },
        });

        assert.equal(current.status, 200);
        const context = current.body as {
          schema_version: string;
          user_id: string;
          recent_events: Array<{ id: string }>;
        };
        assert.equal(context.schema_version, "memory-v2");
        assert.equal(context.user_id, "default_user");
        assert.equal(context.recent_events.length, 1);

        const graph = await handleMemoryPgliteRequest(database, {
          method: "POST",
          path: "/v2/graph/query",
          body: {
            user_id: "default_user",
            start: "AuraBot",
            depth: 2,
            direction: "both",
          },
        });

        assert.equal(graph.status, 200);
        const graphPayload = graph.body as { nodes: unknown[]; relations: unknown[] };
        assert.ok(graphPayload.nodes.length > 0);
        assert.ok(graphPayload.relations.length > 0);

        const deleted = await handleMemoryPgliteRequest(database, {
          method: "DELETE",
          path: `/v2/memories/recent_context/${inserted.event.id}`,
          query: {
            user_id: "default_user",
          },
        });

        assert.equal(deleted.status, 200);
        const deletePayload = deleted.body as { deleted: boolean; source: string; id: string };
        assert.equal(deletePayload.deleted, true);
        assert.equal(deletePayload.source, "recent_context");
        assert.equal(deletePayload.id, inserted.event.id);
      } finally {
        await database.close();
      }
    });
  });
});
