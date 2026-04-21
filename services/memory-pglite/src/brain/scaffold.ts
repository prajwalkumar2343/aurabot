import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import type { EntityType, JsonObject } from "../contracts/index.js";
import { contentHash } from "../recent/hash.js";
import { parseBrainPage, renderBrainPage } from "./parser.js";
import { brainPagePrefixes, slugToAbsolutePath } from "./paths.js";

export interface BrainScaffoldResult {
  root_dir: string;
  created_paths: string[];
  existing_paths: string[];
}

export interface SafeWriteBrainPageInput {
  rootDir: string;
  slug: string;
  type: EntityType;
  title: string;
  frontmatter?: JsonObject;
  compiledTruth?: string;
  timelineText?: string;
  appendTimelineEntries?: string[];
  expectedHash?: string;
  now?: string;
}

export type SafeWriteBrainPageResult =
  | {
      status: "written";
      path: string;
      content_hash: string;
    }
  | {
      status: "conflict";
      path: string;
      expected_hash?: string;
      actual_hash: string;
    };

export async function initializeBrainRepository(rootDir: string): Promise<BrainScaffoldResult> {
  const createdPaths: string[] = [];
  const existingPaths: string[] = [];

  await mkdir(rootDir, { recursive: true });
  for (const prefix of brainPagePrefixes()) {
    await mkdir(join(rootDir, prefix), { recursive: true });
  }

  for (const starter of starterPages()) {
    const path = slugToAbsolutePath(rootDir, starter.slug);
    await mkdir(dirname(path), { recursive: true });
    const existing = await readExisting(path);
    if (existing !== null) {
      existingPaths.push(path);
      continue;
    }

    await writeFile(path, renderBrainPage(starter), "utf8");
    createdPaths.push(path);
  }

  return {
    root_dir: rootDir,
    created_paths: createdPaths,
    existing_paths: existingPaths,
  };
}

export async function safeWriteBrainPage(
  input: SafeWriteBrainPageInput,
): Promise<SafeWriteBrainPageResult> {
  const path = slugToAbsolutePath(input.rootDir, input.slug);
  await mkdir(dirname(path), { recursive: true });
  const existing = await readExisting(path);
  const actualHash = existing === null ? undefined : contentHash(existing.replace(/\r\n?/g, "\n"));

  if (existing !== null && !input.expectedHash) {
    return {
      status: "conflict",
      path,
      actual_hash: actualHash ?? contentHash(existing),
    };
  }

  if (existing !== null && input.expectedHash && actualHash !== input.expectedHash) {
    return {
      status: "conflict",
      path,
      expected_hash: input.expectedHash,
      actual_hash: actualHash ?? contentHash(existing),
    };
  }

  const existingPage = existing === null ? null : parseBrainPage(existing);
  const compiledTruth = input.compiledTruth ?? existingPage?.compiled_truth ?? "";
  const timelineText = appendTimeline(
    input.timelineText ?? existingPage?.timeline_text ?? "",
    input.appendTimelineEntries ?? [],
  );
  const now = input.now ?? new Date().toISOString();
  const rendered = renderBrainPage({
    slug: input.slug,
    type: input.type,
    title: input.title,
    frontmatter: {
      ...(existingPage?.frontmatter ?? {}),
      ...(input.frontmatter ?? {}),
      updated_at: now,
    },
    compiledTruth,
    timelineText,
  });

  await writeFile(path, rendered, "utf8");
  return {
    status: "written",
    path,
    content_hash: contentHash(rendered),
  };
}

function starterPages(): Array<{
  slug: string;
  type: EntityType;
  title: string;
  frontmatter: JsonObject;
  compiledTruth: string;
  timelineText: string;
}> {
  const now = new Date(0).toISOString();
  return [
    {
      slug: "user",
      type: "user",
      title: "User",
      frontmatter: { created_at: now, updated_at: now },
      compiledTruth: "# User\n\nDurable facts about the user belong here.",
      timelineText: "",
    },
    {
      slug: "preferences",
      type: "preference",
      title: "Preferences",
      frontmatter: { created_at: now, updated_at: now },
      compiledTruth: "# Preferences\n\nStable user preferences belong here.",
      timelineText: "",
    },
  ];
}

async function readExisting(path: string): Promise<string | null> {
  try {
    return await readFile(path, "utf8");
  } catch (error) {
    if (isMissingFileError(error)) {
      return null;
    }
    throw error;
  }
}

function isMissingFileError(error: unknown): boolean {
  return Boolean(error && typeof error === "object" && "code" in error && error.code === "ENOENT");
}

function appendTimeline(existing: string, entries: string[]): string {
  const normalizedExisting = existing.trimEnd();
  const normalizedEntries = entries
    .map((entry) => entry.trim())
    .filter(Boolean)
    .map((entry) => (entry.startsWith("- ") ? entry : `- ${entry}`));

  if (normalizedEntries.length === 0) {
    return normalizedExisting;
  }

  return [normalizedExisting, ...normalizedEntries].filter(Boolean).join("\n");
}
