import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { RecentContextEventInput } from "../../src/contracts/index.js";
import { openMemoryDatabase } from "../../src/database/index.js";
import { insertRecentContextEvent } from "../../src/recent/events.js";
import {
  getCurrentContextPacket,
  summarizeRecentContext,
} from "../../src/recent/summaries.js";
import { withTempDir } from "../helpers/temp-dir.js";

function eventInput(overrides: Partial<RecentContextEventInput> = {}): RecentContextEventInput {
  return {
    user_id: "default_user",
    agent_id: "screen_memories_v3",
    idempotency_key: "event_default",
    source: "repo",
    content: "Editing Swift MemoryService to call Memory v2 endpoints.",
    occurred_at: "2026-04-21T09:08:00Z",
    metadata: {
      context: "Code",
      activities: ["editing", "testing"],
      key_elements: ["MemoryService.swift", "v2 search"],
      user_intent: "implement Agent 5 cutover",
      display_num: 1,
      repo_path: "/Users/administrator/Downloads/aurabot",
      file_path: "apps/macos/Sources/AuraBot/Services/MemoryService.swift",
      projects: ["AuraBot"],
      decisions: ["Use Memory v2 endpoints directly"],
    },
    ...overrides,
  };
}

describe("recent context summaries", () => {
  it("creates an idempotent deterministic summary", async () => {
    await withTempDir(async (dir) => {
      const database = await openMemoryDatabase({ dataDir: dir, embeddingDimensions: 3 });
      try {
        await insertRecentContextEvent(database, eventInput());
        await insertRecentContextEvent(
          database,
          eventInput({
            idempotency_key: "event_browser",
            source: "browser",
            content: "Reading AuraBot Memory v2 implementation plan.",
            occurred_at: "2026-04-21T09:00:00Z",
            metadata: {
              context: "Browse",
              activities: ["reading"],
              key_elements: ["Memory v2", "contracts"],
              user_intent: "implementation planning",
              display_num: 1,
              browser: "Safari",
              url: "https://example.test/aurabot/memory-v2",
            },
          }),
        );

        const first = await summarizeRecentContext(database, {
          userId: "default_user",
          agentId: "screen_memories_v3",
          idempotencyKey: "summary_window",
          window: {
            started_at: "2026-04-21T09:00:00Z",
            ended_at: "2026-04-21T09:30:00Z",
          },
          embedder: async () => [[0.1, 0.2, 0.3]],
        });
        const second = await summarizeRecentContext(database, {
          userId: "default_user",
          agentId: "screen_memories_v3",
          idempotencyKey: "summary_window",
          window: {
            started_at: "2026-04-21T09:00:00Z",
            ended_at: "2026-04-21T09:30:00Z",
          },
        });

        assert.equal(first.schema_version, "memory-v2");
        assert.equal(first.summary, second.summary);
        assert.equal(first.recent_events.length, 2);
        assert.match(first.summary, /Recent context includes 2 events/);
        assert.equal(first.metadata.summary_id, second.metadata.summary_id);
        assert.equal(first.metadata.generated_by, "deterministic_summarizer");
      } finally {
        await database.close();
      }
    });
  });

  it("returns the latest summary in the current context packet", async () => {
    await withTempDir(async (dir) => {
      const database = await openMemoryDatabase({ dataDir: dir, embeddingDimensions: 3 });
      try {
        await insertRecentContextEvent(database, eventInput());
        const summary = await summarizeRecentContext(database, {
          userId: "default_user",
          agentId: "screen_memories_v3",
          idempotencyKey: "summary_window",
          window: {
            started_at: "2026-04-21T09:00:00Z",
            ended_at: "2026-04-21T09:30:00Z",
          },
        });

        const current = await getCurrentContextPacket(database, {
          userId: "default_user",
          agentId: "screen_memories_v3",
          now: "2026-04-21T09:30:00Z",
        });

        assert.equal(current.summary, summary.summary);
        assert.equal(current.metadata.summary_id, summary.metadata.summary_id);
        assert.equal(current.recent_events.length, 1);
        assert.deepEqual(current.active_entities, []);
      } finally {
        await database.close();
      }
    });
  });

  it("builds a non-persisted current context packet when no summary exists", async () => {
    await withTempDir(async (dir) => {
      const database = await openMemoryDatabase({ dataDir: dir, embeddingDimensions: 3 });
      try {
        await insertRecentContextEvent(database, eventInput());

        const current = await getCurrentContextPacket(database, {
          userId: "default_user",
          agentId: "screen_memories_v3",
          now: "2026-04-21T09:30:00Z",
        });

        assert.equal(current.schema_version, "memory-v2");
        assert.equal(current.metadata.persisted, false);
        assert.match(current.summary, /Recent context includes 1 event/);
      } finally {
        await database.close();
      }
    });
  });

  it("validates summary windows", async () => {
    await withTempDir(async (dir) => {
      const database = await openMemoryDatabase({ dataDir: dir, embeddingDimensions: 3 });
      try {
        await assert.rejects(
          () =>
            summarizeRecentContext(database, {
              userId: "default_user",
              idempotencyKey: "bad_window",
              window: {
                started_at: "2026-04-21T09:30:00Z",
                ended_at: "2026-04-21T09:00:00Z",
              },
            }),
          /window.started_at must be before window.ended_at/,
        );
      } finally {
        await database.close();
      }
    });
  });
});
