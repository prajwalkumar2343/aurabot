import assert from "node:assert/strict";
import { mkdir, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { describe, it } from "node:test";
import { openMemoryDatabase } from "../../src/database/index.js";
import { syncBrainPages } from "../../src/indexing/index.js";
import { withTempDir } from "../helpers/temp-dir.js";

const projectPage = `---
slug: projects/aurabot
type: project
title: AuraBot
---

# AuraBot

AuraBot stores durable memory in markdown brain pages.

---

- 2026-04-21: Indexed the first markdown brain page.
`;

describe("markdown brain sync", () => {
  it("indexes changed pages, chunks, timeline entries, and skips unchanged pages", async () => {
    await withTempDir(async (dir) => {
      const brainDir = join(dir, "brain");
      await mkdir(join(brainDir, "projects"), { recursive: true });
      await writeFile(join(brainDir, "projects", "aurabot.md"), projectPage, "utf8");

      const database = await openMemoryDatabase({
        dataDir: join(dir, "pglite"),
        embeddingDimensions: 3,
      });
      try {
        const first = await syncBrainPages(database, {
          rootDir: brainDir,
          userId: "default_user",
          embedder: (texts) => texts.map(() => [0.1, 0.2, 0.3]),
          now: "2026-04-21T09:00:00.000Z",
        });

        assert.equal(first.errors.length, 0);
        assert.equal(first.synced_pages.length, 1);
        assert.equal(first.synced_pages[0]?.slug, "projects/aurabot");

        const chunks = await database.query<{ count: number }>(
          "SELECT COUNT(*)::int AS count FROM brain_chunks WHERE slug = $1",
          ["projects/aurabot"],
        );
        assert.equal(chunks.rows[0]?.count, 3);

        const timeline = await database.query<{ count: number }>(
          "SELECT COUNT(*)::int AS count FROM timeline_events WHERE user_id = $1",
          ["default_user"],
        );
        assert.equal(timeline.rows[0]?.count, 1);

        const second = await syncBrainPages(database, {
          rootDir: brainDir,
          userId: "default_user",
          now: "2026-04-21T09:01:00.000Z",
        });
        assert.equal(second.synced_pages.length, 0);
        assert.equal(second.skipped_pages.length, 1);

        await rm(join(brainDir, "projects", "aurabot.md"));
        const third = await syncBrainPages(database, {
          rootDir: brainDir,
          userId: "default_user",
          now: "2026-04-21T09:02:00.000Z",
        });
        assert.equal(third.deleted_pages.length, 1);
      } finally {
        await database.close();
      }
    });
  });

  it("returns parser errors without indexing malformed pages", async () => {
    await withTempDir(async (dir) => {
      const brainDir = join(dir, "brain");
      await mkdir(join(brainDir, "projects"), { recursive: true });
      await writeFile(join(brainDir, "projects", "broken.md"), "# Missing frontmatter", "utf8");

      const database = await openMemoryDatabase({
        dataDir: join(dir, "pglite"),
        embeddingDimensions: 3,
      });
      try {
        const result = await syncBrainPages(database, {
          rootDir: brainDir,
          userId: "default_user",
        });

        assert.equal(result.errors.length, 1);
        assert.equal(result.errors[0]?.code, "missing_frontmatter");
        assert.equal(result.synced_pages.length, 0);
      } finally {
        await database.close();
      }
    });
  });

  it("validates embedding dimensions before storing chunks", async () => {
    await withTempDir(async (dir) => {
      const brainDir = join(dir, "brain");
      await mkdir(join(brainDir, "projects"), { recursive: true });
      await writeFile(join(brainDir, "projects", "aurabot.md"), projectPage, "utf8");

      const database = await openMemoryDatabase({
        dataDir: join(dir, "pglite"),
        embeddingDimensions: 3,
      });
      try {
        await assert.rejects(
          () =>
            syncBrainPages(database, {
              rootDir: brainDir,
              userId: "default_user",
              embedder: (texts) => texts.map(() => [0.1, 0.2]),
            }),
          /Embedding dimension mismatch/,
        );
      } finally {
        await database.close();
      }
    });
  });
});
