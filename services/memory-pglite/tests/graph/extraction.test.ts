import assert from "node:assert/strict";
import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { describe, it } from "node:test";
import { openMemoryDatabase } from "../../src/database/index.js";
import {
  canonicalEntityKey,
  extractGraphForBrainPage,
  extractGraphForRecentContextEvent,
  graphQuery,
  normalizeAlias,
  upsertEntity,
} from "../../src/graph/index.js";
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
websites: [https://docs.example.com]
---

AuraBot Memory v2 uses the local aurabot repo and [[decisions/local-first-memory-storage]].

---

- 2026-04-21: Decided memory storage should stay local-first.
`;

describe("graph extraction", () => {
  it("normalizes aliases and canonical keys consistently", async () => {
    assert.equal(normalizeAlias("https://www.Example.com/path?q=1"), "example.com");
    assert.equal(canonicalEntityKey("website", "https://www.Example.com/a"), "example.com");

    await withTempDir(async (dir) => {
      const database = await openMemoryDatabase({
        dataDir: join(dir, "pglite"),
        embeddingDimensions: 3,
      });
      try {
        const first = await upsertEntity(database, {
          userId,
          type: "website",
          key: "https://www.Example.com/docs",
          name: "Example Docs",
          aliases: ["Example Docs"],
        });
        const second = await upsertEntity(database, {
          userId,
          type: "website",
          key: "example.com",
          name: "example.com",
          aliases: ["https://example.com"],
        });

        assert.equal(first.id, second.id);
      } finally {
        await database.close();
      }
    });
  });

  it("extracts recent context entities and evidence-backed relations idempotently", async () => {
    await withTempDir(async (dir) => {
      const database = await openMemoryDatabase({
        dataDir: join(dir, "pglite"),
        embeddingDimensions: 3,
      });
      try {
        const event = await insertRecentContextEvent(database, {
          user_id: userId,
          idempotency_key: "graph-recent-context-1",
          source: "browser",
          content: "Editing AuraBot memory code while reading docs.example.com.",
          occurred_at: "2026-04-21T09:00:00.000Z",
          metadata: {
            context: "Memory v2 graph work",
            activities: ["editing"],
            key_elements: ["AuraBot", "docs.example.com"],
            user_intent: "wire graph extraction",
            display_num: 1,
            app_name: "Cursor",
            url: "https://docs.example.com/memory",
            repo_path: "/Users/administrator/Downloads/aurabot",
            file_path: "/Users/administrator/Downloads/aurabot/services/memory-pglite/src/graph/index.ts",
            projects: ["AuraBot"],
          },
        });

        const first = await extractGraphForRecentContextEvent(database, event.id, {
          now: "2026-04-21T09:01:00.000Z",
        });
        const second = await extractGraphForRecentContextEvent(database, event.id, {
          now: "2026-04-21T09:01:00.000Z",
        });

        assert.equal(second.entities.length, first.entities.length);
        assert.equal(second.relations.length, first.relations.length);
        assert.ok(first.entities.some((entity) => entity.entity_type === "website"));
        assert.ok(first.entities.some((entity) => entity.entity_type === "repo"));
        assert.ok(first.relations.some((relation) => relation.relation_type === "visited"));
        assert.ok(first.relations.some((relation) => relation.relation_type === "edited"));
        assert.ok(first.relations.every((relation) => relation.evidence.length > 0));
        assert.ok(first.relations.every((relation) => relation.evidence[0]?.source_id === event.id));

        const linkCount = await database.query<{ count: number }>(
          "SELECT COUNT(*)::int AS count FROM entity_links WHERE evidence_source_id = $1",
          [event.id],
        );
        assert.equal(linkCount.rows[0]?.count, first.relations.length);
      } finally {
        await database.close();
      }
    });
  });

  it("extracts markdown page links and traverses the bounded graph", async () => {
    await withTempDir(async (dir) => {
      const brainDir = join(dir, "brain");
      await mkdir(join(brainDir, "projects"), { recursive: true });
      await writeFile(join(brainDir, "projects", "aurabot.md"), projectPage, "utf8");

      const database = await openMemoryDatabase({
        dataDir: join(dir, "pglite"),
        embeddingDimensions: 3,
      });
      try {
        const sync = await syncBrainPages(database, {
          rootDir: brainDir,
          userId,
          now: "2026-04-21T09:10:00.000Z",
        });
        assert.equal(sync.errors.length, 0);

        const pageId = sync.synced_pages[0]?.id;
        assert.ok(pageId);

        const extracted = await extractGraphForBrainPage(database, pageId, {
          now: "2026-04-21T09:11:00.000Z",
        });
        assert.ok(extracted.entities.some((entity) => entity.slug === "projects/aurabot"));
        assert.ok(extracted.entities.some((entity) => entity.entity_type === "repo"));
        assert.ok(extracted.entities.some((entity) => entity.entity_type === "app"));
        assert.ok(extracted.entities.some((entity) => entity.entity_type === "website"));
        assert.ok(extracted.relations.some((relation) => relation.relation_type === "uses"));
        assert.ok(extracted.relations.every((relation) => relation.evidence[0]?.source === "brain_page"));

        const traversal = await graphQuery(database, {
          userId,
          start: "projects/aurabot",
          depth: 6,
          direction: "both",
          limit: 10,
          now: "2026-04-21T09:12:00.000Z",
        });

        assert.equal(traversal.schema_version, "memory-v2");
        assert.equal(traversal.depth, 4);
        assert.ok(traversal.nodes.length <= 10);
        assert.ok(traversal.nodes.some((node) => node.type === "repo"));
        assert.ok(traversal.relations.every((relation) => relation.evidence.length > 0));
      } finally {
        await database.close();
      }
    });
  });
});
