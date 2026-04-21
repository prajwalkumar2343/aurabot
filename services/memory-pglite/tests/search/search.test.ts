import assert from "node:assert/strict";
import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { describe, it } from "node:test";
import { openMemoryDatabase } from "../../src/database/index.js";
import { extractGraphForBrainPage, extractGraphForRecentContextEvent } from "../../src/graph/index.js";
import { syncBrainPages } from "../../src/indexing/index.js";
import { insertRecentContextEvent } from "../../src/recent/events.js";
import { searchMemory } from "../../src/search/index.js";
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

AuraBot Memory v2 stores durable personalization in markdown brain files and recent noisy activity in PGlite tables.

---

- 2026-04-21: Connected the AuraBot project to its repo, editor, and docs website.
`;

const decisionPage = `---
slug: decisions/local-first-memory-storage
type: decision
title: Local-first memory storage
projects: [AuraBot]
---

Memory storage is local-first: stable personalization lives in markdown brain files, while recent context lives in PGlite.

---

- 2026-04-21: Decided the durable source of truth is markdown with PGlite as the local retrieval index.
`;

const workflowPage = `---
slug: workflows/release-review
type: workflow
title: Release review
websites: [https://docs.example.com]
apps: [Cursor]
---

Release review uses the docs website and Cursor.

---

- 2026-04-21: Added graph-aware retrieval checks to the release review workflow.
`;

describe("graph-aware search", () => {
  it("returns v2 search results with keyword and graph evidence", async () => {
    await withTempDir(async (dir) => {
      const { database } = await seedSearchFixture(dir);
      try {
        const result = await searchMemory(database, {
          userId,
          query: "what did we decide about memory storage?",
          limit: 5,
          now: "2026-04-21T10:00:00.000Z",
        });

        assert.equal(result.schema_version, "memory-v2");
        assert.equal(result.query, "what did we decide about memory storage?");
        assert.ok(result.items.length > 0);
        assert.ok(result.debug.matched_entities.length > 0);
        assert.ok(result.debug.ranking.strategy === "rrf");

        const decisionHit = result.items.find(
          (item) => item.source === "brain_chunk" && item.content.toLowerCase().includes("local-first"),
        );
        assert.ok(decisionHit);
        assert.ok(decisionHit.score > 0);
        assert.ok(decisionHit.evidence.length > 0);
        assert.ok(decisionHit.relations.some((relation) => relation.relation_type === "decided_in"));
      } finally {
        await database.close();
      }
    });
  });

  it("uses graph neighbors for project-repo and workflow-website queries", async () => {
    await withTempDir(async (dir) => {
      const { database } = await seedSearchFixture(dir);
      try {
        const projectResult = await searchMemory(database, {
          userId,
          query: "what project uses aurabot repo?",
          scopes: ["graph"],
          limit: 5,
          now: "2026-04-21T10:00:00.000Z",
        });

        assert.ok(projectResult.items.length > 0);
        assert.ok(
          projectResult.items.some(
            (item) =>
              item.source === "graph" &&
              item.content.toLowerCase().includes("aurabot") &&
              item.relations.some((relation) => relation.relation_type === "uses"),
          ),
        );

        const workflowResult = await searchMemory(database, {
          userId,
          query: "what sites are connected to release review workflow?",
          scopes: ["graph"],
          limit: 5,
          now: "2026-04-21T10:00:00.000Z",
        });

        assert.ok(
          workflowResult.items.some((item) => item.content.toLowerCase().includes("docs.example.com")),
        );
      } finally {
        await database.close();
      }
    });
  });

  it("includes recent context evidence when graph extraction links an event", async () => {
    await withTempDir(async (dir) => {
      const { database, recentEventId } = await seedSearchFixture(dir);
      try {
        const result = await searchMemory(database, {
          userId,
          query: "docs.example.com Cursor AuraBot",
          limit: 5,
          now: "2026-04-21T10:00:00.000Z",
        });

        const recentHit = result.items.find((item) => item.id === recentEventId);
        assert.ok(recentHit);
        assert.equal(recentHit.source, "recent_context");
        assert.ok(recentHit.entity_ids.length > 0);
        assert.ok(recentHit.evidence.some((evidence) => evidence.source_id === recentEventId));
      } finally {
        await database.close();
      }
    });
  });
});

async function seedSearchFixture(dir: string): Promise<{
  database: Awaited<ReturnType<typeof openMemoryDatabase>>;
  recentEventId: string;
}> {
  const brainDir = join(dir, "brain");
  await mkdir(join(brainDir, "projects"), { recursive: true });
  await mkdir(join(brainDir, "decisions"), { recursive: true });
  await mkdir(join(brainDir, "workflows"), { recursive: true });
  await writeFile(join(brainDir, "projects", "aurabot.md"), projectPage, "utf8");
  await writeFile(join(brainDir, "decisions", "local-first-memory-storage.md"), decisionPage, "utf8");
  await writeFile(join(brainDir, "workflows", "release-review.md"), workflowPage, "utf8");

  const database = await openMemoryDatabase({
    dataDir: join(dir, "pglite"),
    embeddingDimensions: 3,
  });

  const sync = await syncBrainPages(database, {
    rootDir: brainDir,
    userId,
    now: "2026-04-21T09:15:00.000Z",
  });
  assert.equal(sync.errors.length, 0);

  for (const page of sync.synced_pages) {
    await extractGraphForBrainPage(database, page.id, {
      now: "2026-04-21T09:16:00.000Z",
    });
  }

  const recent = await insertRecentContextEvent(database, {
    user_id: userId,
    idempotency_key: `search-recent-${dir}`,
    source: "browser",
    content: "Reading docs.example.com in Cursor while implementing AuraBot graph-aware search.",
    occurred_at: "2026-04-21T09:20:00.000Z",
    metadata: {
      context: "Graph-aware retrieval",
      activities: ["reading", "editing"],
      key_elements: ["docs.example.com", "Cursor", "AuraBot"],
      user_intent: "test graph search",
      display_num: 1,
      app_name: "Cursor",
      url: "https://docs.example.com/memory",
      repo_path: "/Users/administrator/Downloads/aurabot",
      projects: ["AuraBot"],
    },
  });
  await extractGraphForRecentContextEvent(database, recent.id, {
    now: "2026-04-21T09:21:00.000Z",
  });

  return {
    database,
    recentEventId: recent.id,
  };
}
