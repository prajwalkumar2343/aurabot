import { readdir, readFile } from "node:fs/promises";
import { join, relative } from "node:path";
import type { BrainSyncResponse, JsonObject } from "../contracts/index.js";
import type { MemoryPgliteDatabase } from "../database/index.js";
import { enqueueMemoryJob } from "../jobs/index.js";
import { contentHash, sha256Hex, stableJson } from "../recent/hash.js";
import { BRAIN_CHUNK_TYPES, TABLES } from "../schema/constants.js";
import type { ParsedBrainPage } from "../brain/parser.js";
import { parseBrainPage } from "../brain/parser.js";

export type BrainEmbeddingProvider = (texts: string[]) => Promise<number[][]> | number[][];

export interface SyncBrainPagesOptions {
  rootDir: string;
  userId: string;
  embedder?: BrainEmbeddingProvider;
  enqueueGraphExtraction?: boolean;
  now?: string;
}

export interface SyncBrainPagesResult extends BrainSyncResponse {
  skipped_pages: Array<{
    id: string;
    slug: string;
    path: string;
    source_hash: string;
  }>;
  deleted_pages: Array<{
    id: string;
    slug: string;
    path: string;
  }>;
}

interface BrainPageRow {
  id: string;
  slug: string;
  path: string;
  type: string;
  title: string;
  source_hash: string;
  updated_at: string | Date;
}

interface ExistingBrainPageRow {
  id: string;
  slug: string;
  path: string;
  source_hash: string;
}

interface DeletedBrainPageRow {
  id: string;
  slug: string;
  path: string;
}

export async function syncBrainPages(
  database: MemoryPgliteDatabase,
  options: SyncBrainPagesOptions,
): Promise<SyncBrainPagesResult> {
  const now = options.now ?? new Date().toISOString();
  const files = await scanMarkdownFiles(options.rootDir);
  const existingPages = await getExistingBrainPages(database, options.userId);
  const existingByPath = new Map(existingPages.map((row) => [row.path, row]));
  const seenPaths = new Set<string>();
  const syncedRows: BrainPageRow[] = [];
  const skippedRows: ExistingBrainPageRow[] = [];
  const errors: SyncBrainPagesResult["errors"] = [];

  for (const file of files) {
    const relativePath = relative(options.rootDir, file).replace(/\\/g, "/");
    seenPaths.add(relativePath);
    const markdown = await readFile(file, "utf8");
    const parsed = parseBrainPage(markdown, { path: relativePath });

    if (parsed.errors.length > 0) {
      errors.push(
        ...parsed.errors.map((error) => ({
          path: relativePath,
          code: error.code,
          message: error.message,
        })),
      );
      continue;
    }

    const existing = existingByPath.get(relativePath);
    if (existing?.source_hash === parsed.source_hash) {
      skippedRows.push(existing);
      continue;
    }

    const row = await upsertBrainPage(database, options.userId, relativePath, parsed, now);
    await replaceBrainChunks(database, options.userId, row.id, parsed, options.embedder);
    await replaceTimelineEvents(database, options.userId, row.id, parsed, now);
    syncedRows.push(row);

    if (options.enqueueGraphExtraction ?? true) {
      await enqueueMemoryJob(database, {
        userId: options.userId,
        jobType: "extract_brain_page_graph",
        idempotencyKey: `brain_page:${row.id}:${parsed.source_hash}`,
        payload: {
          source: "brain_page",
          source_id: row.id,
          slug: parsed.slug,
          source_hash: parsed.source_hash,
        },
      });
    }
  }

  const deletedRows = await deleteRemovedPages(database, options.userId, seenPaths);
  const job = await enqueueMemoryJob(database, {
    userId: options.userId,
    jobType: "sync_brain_pages",
    idempotencyKey: `brain_sync:${options.userId}:${contentHash([...seenPaths].sort().join("\n"))}`,
    payload: {
      root_dir: options.rootDir,
      seen_paths: [...seenPaths].sort(),
      synced_count: syncedRows.length,
      skipped_count: skippedRows.length,
      deleted_count: deletedRows.length,
      error_count: errors.length,
    },
  });

  return {
    schema_version: "memory-v2",
    job,
    synced_pages: syncedRows.map((row) => ({
      id: row.id,
      slug: row.slug,
      path: row.path,
      type: row.type as SyncBrainPagesResult["synced_pages"][number]["type"],
      title: row.title,
      source_hash: row.source_hash,
      updated_at: toIso(row.updated_at),
    })),
    skipped_pages: skippedRows.map((row) => ({
      id: row.id,
      slug: row.slug,
      path: row.path,
      source_hash: row.source_hash,
    })),
    deleted_pages: deletedRows,
    errors,
  };
}

async function scanMarkdownFiles(rootDir: string): Promise<string[]> {
  const files: string[] = [];

  async function visit(dir: string): Promise<void> {
    const entries = await readdir(dir, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.name.startsWith(".")) {
        continue;
      }

      const path = join(dir, entry.name);
      if (entry.isDirectory()) {
        await visit(path);
      } else if (entry.isFile() && entry.name.toLowerCase().endsWith(".md")) {
        files.push(path);
      }
    }
  }

  await visit(rootDir);
  return files.sort();
}

async function getExistingBrainPages(
  database: MemoryPgliteDatabase,
  userId: string,
): Promise<ExistingBrainPageRow[]> {
  const result = await database.query<ExistingBrainPageRow>(
    `
      SELECT id, slug, path, source_hash
      FROM ${TABLES.brainPages}
      WHERE user_id = $1
    `,
    [userId],
  );
  return result.rows;
}

async function upsertBrainPage(
  database: MemoryPgliteDatabase,
  userId: string,
  path: string,
  page: ParsedBrainPage,
  now: string,
): Promise<BrainPageRow> {
  const id = brainPageId(userId, page.slug);
  const result = await database.query<BrainPageRow>(
    `
      INSERT INTO ${TABLES.brainPages} (
        id,
        user_id,
        slug,
        path,
        page_type,
        title,
        frontmatter,
        compiled_truth,
        timeline_text,
        content_hash,
        source_hash,
        last_indexed_at,
        updated_at
      ) VALUES (
        $1,
        $2,
        $3,
        $4,
        $5,
        $6,
        $7::jsonb,
        $8,
        $9,
        $10,
        $11,
        $12::timestamptz,
        $12::timestamptz
      )
      ON CONFLICT (user_id, slug) DO UPDATE SET
        path = EXCLUDED.path,
        page_type = EXCLUDED.page_type,
        title = EXCLUDED.title,
        frontmatter = EXCLUDED.frontmatter,
        compiled_truth = EXCLUDED.compiled_truth,
        timeline_text = EXCLUDED.timeline_text,
        content_hash = EXCLUDED.content_hash,
        source_hash = EXCLUDED.source_hash,
        last_indexed_at = EXCLUDED.last_indexed_at,
        updated_at = EXCLUDED.updated_at
      RETURNING
        id,
        slug,
        path,
        page_type AS type,
        title,
        source_hash,
        updated_at
    `,
    [
      id,
      userId,
      page.slug,
      path,
      page.type,
      page.title,
      stableJson(page.frontmatter),
      page.compiled_truth,
      page.timeline_text,
      page.content_hash,
      page.source_hash,
      now,
    ],
  );

  const row = result.rows[0];
  if (!row) {
    throw new Error(`Failed to upsert brain page ${page.slug}`);
  }
  return row;
}

async function replaceBrainChunks(
  database: MemoryPgliteDatabase,
  userId: string,
  pageId: string,
  page: ParsedBrainPage,
  embedder: BrainEmbeddingProvider | undefined,
): Promise<void> {
  const chunks = [
    {
      type: "frontmatter",
      content: stableJson(page.frontmatter),
      metadata: { slug: page.slug, links: page.links } satisfies JsonObject,
    },
    {
      type: "compiled_truth",
      content: page.compiled_truth,
      metadata: { slug: page.slug, links: page.links } satisfies JsonObject,
    },
    {
      type: "timeline",
      content: page.timeline_text,
      metadata: { slug: page.slug, timeline_count: page.timeline_entries.length } satisfies JsonObject,
    },
  ].filter((chunk) => chunk.content.trim().length > 0);

  const embeddings = embedder ? await embedChunks(embedder, chunks.map((chunk) => chunk.content)) : [];
  const activeIds: string[] = [];

  for (const [index, chunk] of chunks.entries()) {
    if (!BRAIN_CHUNK_TYPES.includes(chunk.type as (typeof BRAIN_CHUNK_TYPES)[number])) {
      throw new Error(`Unsupported brain chunk type: ${chunk.type}`);
    }
    const chunkId = brainChunkId(pageId, chunk.type, index);
    activeIds.push(chunkId);
    const embedding = embeddings[index];
    if (embedding && embedding.length !== database.embeddingDimensions) {
      throw new Error(
        `Embedding dimension mismatch for ${page.slug}:${chunk.type}; expected ${database.embeddingDimensions}, got ${embedding.length}`,
      );
    }
    await database.query(
      `
        INSERT INTO ${TABLES.brainChunks} (
          id,
          user_id,
          page_id,
          slug,
          chunk_type,
          chunk_index,
          content,
          metadata,
          embedding,
          content_hash
        ) VALUES (
          $1,
          $2,
          $3,
          $4,
          $5,
          $6,
          $7,
          $8::jsonb,
          CASE WHEN $9::text IS NULL THEN NULL ELSE $9::text::vector END,
          $10
        )
        ON CONFLICT (page_id, chunk_type, chunk_index) DO UPDATE SET
          slug = EXCLUDED.slug,
          content = EXCLUDED.content,
          metadata = EXCLUDED.metadata,
          embedding = EXCLUDED.embedding,
          content_hash = EXCLUDED.content_hash,
          updated_at = NOW()
      `,
      [
        chunkId,
        userId,
        pageId,
        page.slug,
        chunk.type,
        index,
        chunk.content,
        stableJson(chunk.metadata),
        embedding ? vectorLiteralFromEmbedding(embedding) : null,
        contentHash(chunk.content),
      ],
    );
  }

  if (activeIds.length === 0) {
    await database.query(`DELETE FROM ${TABLES.brainChunks} WHERE page_id = $1`, [pageId]);
    return;
  }

  await database.query(
    `
      DELETE FROM ${TABLES.brainChunks}
      WHERE page_id = $1
        AND id <> ALL($2::text[])
    `,
    [pageId, activeIds],
  );
}

async function replaceTimelineEvents(
  database: MemoryPgliteDatabase,
  userId: string,
  pageId: string,
  page: ParsedBrainPage,
  now: string,
): Promise<void> {
  const activeIds: string[] = [];

  for (const entry of page.timeline_entries) {
    const id = timelineEventId(pageId, entry.content_hash);
    activeIds.push(id);
    await database.query(
      `
        INSERT INTO ${TABLES.timelineEvents} (
          id,
          user_id,
          page_id,
          event_date,
          event_timestamp,
          summary,
          evidence,
          metadata,
          content_hash,
          updated_at
        ) VALUES (
          $1,
          $2,
          $3,
          $4::date,
          $5::timestamptz,
          $6,
          $7::jsonb,
          $8::jsonb,
          $9,
          $10::timestamptz
        )
        ON CONFLICT (user_id, page_id, content_hash) DO UPDATE SET
          event_date = EXCLUDED.event_date,
          event_timestamp = EXCLUDED.event_timestamp,
          summary = EXCLUDED.summary,
          evidence = EXCLUDED.evidence,
          metadata = EXCLUDED.metadata,
          updated_at = EXCLUDED.updated_at
      `,
      [
        id,
        userId,
        pageId,
        entry.event_date ?? null,
        entry.event_timestamp ?? null,
        entry.summary,
        stableJson([
          {
            source: "brain_page",
            source_id: pageId,
            excerpt: entry.raw,
            content_hash: entry.content_hash,
            created_at: now,
          },
        ]),
        stableJson({ slug: page.slug, raw: entry.raw }),
        entry.content_hash,
        now,
      ],
    );
  }

  if (activeIds.length === 0) {
    await database.query(`DELETE FROM ${TABLES.timelineEvents} WHERE page_id = $1`, [pageId]);
    return;
  }

  await database.query(
    `
      DELETE FROM ${TABLES.timelineEvents}
      WHERE page_id = $1
        AND id <> ALL($2::text[])
    `,
    [pageId, activeIds],
  );
}

async function deleteRemovedPages(
  database: MemoryPgliteDatabase,
  userId: string,
  seenPaths: Set<string>,
): Promise<DeletedBrainPageRow[]> {
  const paths = [...seenPaths];
  if (paths.length === 0) {
    const result = await database.query<DeletedBrainPageRow>(
      `
        DELETE FROM ${TABLES.brainPages}
        WHERE user_id = $1
        RETURNING id, slug, path
      `,
      [userId],
    );
    return result.rows;
  }

  const result = await database.query<DeletedBrainPageRow>(
    `
      DELETE FROM ${TABLES.brainPages}
      WHERE user_id = $1
        AND path <> ALL($2::text[])
      RETURNING id, slug, path
    `,
    [userId, paths],
  );
  return result.rows;
}

async function embedChunks(embedder: BrainEmbeddingProvider, texts: string[]): Promise<number[][]> {
  const embeddings = await embedder(texts);
  if (embeddings.length !== texts.length) {
    throw new Error(`embedder returned ${embeddings.length} embeddings for ${texts.length} brain chunks`);
  }
  return embeddings.map((embedding) => embedding.map((value) => Number(value)));
}

function brainPageId(userId: string, slug: string): string {
  return `brain_page_${sha256Hex(`${userId}:${slug}`).slice(0, 24)}`;
}

function brainChunkId(pageId: string, chunkType: string, chunkIndex: number): string {
  return `brain_chunk_${sha256Hex(`${pageId}:${chunkType}:${chunkIndex}`).slice(0, 24)}`;
}

function timelineEventId(pageId: string, eventHash: string): string {
  return `timeline_${sha256Hex(`${pageId}:${eventHash}`).slice(0, 24)}`;
}

function vectorLiteralFromEmbedding(embedding: number[]): string {
  return `[${embedding.map((value) => Number(value).toFixed(12)).join(",")}]`;
}

function toIso(value: string | Date): string {
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}
