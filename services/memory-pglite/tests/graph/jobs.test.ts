import assert from "node:assert/strict";
import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { describe, it } from "node:test";
import { openMemoryDatabase } from "../../src/database/index.js";
import { processGraphExtractionJobs } from "../../src/graph/jobs.js";
import { syncBrainPages } from "../../src/indexing/index.js";
import { insertRecentContextEvent } from "../../src/recent/events.js";
import { withTempDir } from "../helpers/temp-dir.js";

const userId = "default_user";

const projectPage = `---
slug: projects/aurabot
type: project
title: AuraBot
repos: [/Users/administrator/Downloads/aurabot]
apps: [Cursor]
---

AuraBot uses Cursor and the local aurabot repository.

---

- 2026-04-22: Queued markdown graph extraction through brain sync.
`;

describe("graph extraction job processing", () => {
  it("processes queued recent-context and brain-page graph jobs", async () => {
    await withTempDir(async (dir) => {
      const brainDir = join(dir, "brain");
      await mkdir(join(brainDir, "projects"), { recursive: true });
      await writeFile(join(brainDir, "projects", "aurabot.md"), projectPage, "utf8");

      const database = await openMemoryDatabase({
        dataDir: join(dir, "pglite"),
        embeddingDimensions: 3,
      });

      try {
        const event = await insertRecentContextEvent(database, {
          user_id: userId,
          idempotency_key: "graph-jobs-recent",
          source: "browser",
          content: "Editing AuraBot graph extraction jobs while using Cursor.",
          occurred_at: "2026-04-22T09:20:00.000Z",
          metadata: {
            context: "Graph jobs",
            activities: ["editing"],
            key_elements: ["AuraBot", "Cursor"],
            user_intent: "verify graph job processing",
            display_num: 1,
            app_name: "Cursor",
            repo_path: "/Users/administrator/Downloads/aurabot",
            projects: ["AuraBot"],
          },
        });

        const sync = await syncBrainPages(database, {
          rootDir: brainDir,
          userId,
          now: "2026-04-22T09:21:00.000Z",
        });
        assert.equal(sync.errors.length, 0);

        const processed = await processGraphExtractionJobs(database, {
          limit: 10,
          now: "2026-04-22T09:22:00.000Z",
        });

        assert.equal(processed.length, 2);
        assert.ok(processed.every((job) => job.status === "completed"));
        assert.ok(processed.some((job) => job.source_id === event.id));
        assert.ok(processed.some((job) => job.source_id === sync.synced_pages[0]?.id));
        assert.ok(processed.every((job) => (job.relations ?? 0) > 0));

        const jobs = await database.query<{ status: string; count: number }>(
          `
            SELECT status, COUNT(*)::int AS count
            FROM memory_jobs
            WHERE job_type IN ('extract_recent_context_graph', 'extract_brain_page_graph')
            GROUP BY status
          `,
        );
        assert.deepEqual(jobs.rows, [{ status: "completed", count: 2 }]);

        const links = await database.query<{ count: number }>(
          "SELECT COUNT(*)::int AS count FROM entity_links WHERE user_id = $1",
          [userId],
        );
        assert.ok((links.rows[0]?.count ?? 0) > 0);

        const second = await processGraphExtractionJobs(database, { limit: 10 });
        assert.equal(second.length, 0);
      } finally {
        await database.close();
      }
    });
  });

  it("marks malformed graph jobs failed with an error", async () => {
    await withTempDir(async (dir) => {
      const database = await openMemoryDatabase({
        dataDir: join(dir, "pglite"),
        embeddingDimensions: 3,
      });

      try {
        await database.query(
          `
            INSERT INTO memory_jobs (
              id,
              user_id,
              job_type,
              status,
              idempotency_key,
              payload
            ) VALUES (
              'job_bad_graph_payload',
              $1,
              'extract_recent_context_graph',
              'queued',
              'bad-graph-payload',
              '{}'::jsonb
            )
          `,
          [userId],
        );

        const processed = await processGraphExtractionJobs(database, {
          now: "2026-04-22T09:25:00.000Z",
        });

        assert.equal(processed.length, 1);
        assert.equal(processed[0]?.status, "failed");
        assert.match(processed[0]?.error ?? "", /payload.source_id/);

        const job = await database.query<{ status: string; error: string | null }>(
          "SELECT status, error FROM memory_jobs WHERE id = 'job_bad_graph_payload'",
        );
        assert.equal(job.rows[0]?.status, "failed");
        assert.match(job.rows[0]?.error ?? "", /payload.source_id/);
      } finally {
        await database.close();
      }
    });
  });
});
