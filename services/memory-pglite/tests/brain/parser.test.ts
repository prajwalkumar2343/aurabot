import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { describe, it } from "node:test";
import { join } from "node:path";
import {
  initializeBrainRepository,
  parseBrainPage,
  safeWriteBrainPage,
} from "../../src/brain/index.js";
import { contentHash } from "../../src/recent/hash.js";
import { withTempDir } from "../helpers/temp-dir.js";

const validPage = `---
slug: projects/aurabot
type: project
title: AuraBot
aliases: [screen memories, aura bot]
---

# AuraBot

AuraBot uses [[repos/aurabot]] for local-first memory.

---

- 2026-04-21: Decided to keep durable memory in markdown.
`;

describe("markdown brain parser and writer", () => {
  it("parses frontmatter, compiled truth, timeline, and links", () => {
    const page = parseBrainPage(validPage, { path: "projects/aurabot.md" });

    assert.deepEqual(page.errors, []);
    assert.equal(page.slug, "projects/aurabot");
    assert.equal(page.type, "project");
    assert.equal(page.title, "AuraBot");
    assert.match(page.compiled_truth, /local-first memory/);
    assert.match(page.timeline_text, /durable memory/);
    assert.deepEqual(page.links, ["repos/aurabot"]);
    assert.equal(page.timeline_entries.length, 1);
    assert.equal(page.timeline_entries[0]?.event_date, "2026-04-21");
  });

  it("reports missing frontmatter and duplicate body dividers as recoverable errors", () => {
    const missing = parseBrainPage("# Missing frontmatter", { path: "concepts/missing.md" });
    assert.equal(missing.errors[0]?.code, "missing_frontmatter");

    const duplicate = parseBrainPage(`${validPage}\n---\nextra`, {
      path: "projects/aurabot.md",
    });
    assert.equal(duplicate.errors.some((error) => error.code === "duplicate_timeline_divider"), true);
  });

  it("scaffolds starter brain files without overwriting existing pages", async () => {
    await withTempDir(async (dir) => {
      const first = await initializeBrainRepository(dir);
      assert.equal(first.created_paths.length, 2);

      const second = await initializeBrainRepository(dir);
      assert.equal(second.created_paths.length, 0);
      assert.equal(second.existing_paths.length, 2);

      const user = await readFile(join(dir, "USER.md"), "utf8");
      assert.match(user, /slug: user/);
    });
  });

  it("uses expected hashes to avoid overwriting user edits", async () => {
    await withTempDir(async (dir) => {
      const first = await safeWriteBrainPage({
        rootDir: dir,
        slug: "projects/aurabot",
        type: "project",
        title: "AuraBot",
        compiledTruth: "# AuraBot\n\nInitial truth.",
        timelineText: "- 2026-04-21: Existing event.",
        now: "2026-04-21T00:00:00.000Z",
      });
      assert.equal(first.status, "written");

      const path = join(dir, "projects", "aurabot.md");
      const existing = await readFile(path, "utf8");
      const missingHash = await safeWriteBrainPage({
        rootDir: dir,
        slug: "projects/aurabot",
        type: "project",
        title: "AuraBot",
        compiledTruth: "# AuraBot\n\nUpdated truth.",
        now: "2026-04-21T00:01:00.000Z",
      });
      assert.equal(missingHash.status, "conflict");

      const conflict = await safeWriteBrainPage({
        rootDir: dir,
        slug: "projects/aurabot",
        type: "project",
        title: "AuraBot",
        compiledTruth: "# AuraBot\n\nUpdated truth.",
        expectedHash: contentHash(`${existing}\nuser edit`),
        now: "2026-04-21T00:01:00.000Z",
      });
      assert.equal(conflict.status, "conflict");

      const written = await safeWriteBrainPage({
        rootDir: dir,
        slug: "projects/aurabot",
        type: "project",
        title: "AuraBot",
        compiledTruth: "# AuraBot\n\nUpdated truth.",
        appendTimelineEntries: ["2026-04-21: Appended event."],
        expectedHash: contentHash(existing),
        now: "2026-04-21T00:02:00.000Z",
      });
      assert.equal(written.status, "written");

      const updated = await readFile(path, "utf8");
      assert.match(updated, /updated_at: 2026-04-21T00:02:00.000Z/);
      assert.match(updated, /- 2026-04-21: Existing event/);
      assert.match(updated, /- 2026-04-21: Appended event/);
    });
  });
});
