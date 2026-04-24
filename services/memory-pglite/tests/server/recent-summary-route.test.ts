import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { describe, it } from "node:test";
import { openMemoryDatabase } from "../../src/database/index.js";
import { insertRecentContextEvent } from "../../src/recent/events.js";
import { handleMemoryPgliteRequest } from "../../src/server.js";
import { withTempDir } from "../helpers/temp-dir.js";

describe("Memory PGlite recent summary route", () => {
  it("writes and indexes a generated markdown page by default", async () => {
    await withTempDir(async (dir) => {
      const database = await openMemoryDatabase({
        dataDir: join(dir, "pglite"),
        embeddingDimensions: 3,
      });
      const brainRootDir = join(dir, "brain");

      try {
        await insertRecentContextEvent(database, {
          user_id: "default_user",
          agent_id: "screen_memories_v3",
          idempotency_key: "server-summary-route-event",
          source: "repo",
          content: "Implementing generated markdown for AuraBot recent context summaries.",
          occurred_at: "2026-04-22T10:00:00.000Z",
          metadata: {
            context: "Recent summary route test",
            activities: ["testing"],
            key_elements: ["markdown", "recent context"],
            user_intent: "verify summary markdown materialization",
            display_num: 1,
            repo_path: "/Users/administrator/Downloads/aurabot",
            projects: ["AuraBot"],
          },
        });

        const response = await handleMemoryPgliteRequest(
          database,
          {
            method: "POST",
            path: "/v2/recent-context/summaries",
            body: {
              user_id: "default_user",
              agent_id: "screen_memories_v3",
              idempotency_key: "server-summary-route-window",
              window: {
                started_at: "2026-04-22T09:45:00.000Z",
                ended_at: "2026-04-22T10:15:00.000Z",
              },
            },
          },
          { brainRootDir },
        );

        assert.equal(response.status, 200);
        const payload = response.body as {
          schema_version: string;
          metadata: {
            markdown?: {
              path: string;
              slug: string;
              synced: boolean;
            };
          };
        };
        assert.equal(payload.schema_version, "memory-v2");
        assert.ok(payload.metadata.markdown);
        assert.equal(payload.metadata.markdown.synced, true);

        const generated = await readFile(join(brainRootDir, payload.metadata.markdown.path), "utf8");
        assert.match(generated, /generated markdown for AuraBot recent context summaries/);

        const indexed = await database.query<{ slug: string }>(
          "SELECT slug FROM brain_pages WHERE slug = $1 LIMIT 1",
          [payload.metadata.markdown.slug],
        );
        assert.equal(indexed.rows[0]?.slug, payload.metadata.markdown.slug);
      } finally {
        await database.close();
      }
    });
  });
});
