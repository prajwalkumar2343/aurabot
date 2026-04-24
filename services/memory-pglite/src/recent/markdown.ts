import { mkdir, writeFile } from "node:fs/promises";
import { dirname, relative } from "node:path";
import { renderBrainPage } from "../brain/parser.js";
import { normalizeSlug, slugToAbsolutePath } from "../brain/paths.js";
import type { JsonObject, RecentContextEvent, TimeWindow } from "../contracts/index.js";
import { contentHash } from "./hash.js";

export interface RecentContextSummaryFacts {
  active_apps: string[];
  websites: string[];
  repos: string[];
  files: string[];
  projects: string[];
  people: string[];
  decisions: string[];
  open_questions: string[];
}

export interface WriteRecentContextSummaryMarkdownInput {
  rootDir: string;
  userId: string;
  agentId?: string;
  summaryId: string;
  window: TimeWindow;
  summary: string;
  facts: RecentContextSummaryFacts;
  sourceHash: string;
  sourceEvents: RecentContextEvent[];
  generatedAt: string;
}

export interface RecentContextSummaryMarkdownRef {
  root_dir: string;
  path: string;
  slug: string;
  content_hash: string;
  generated_at: string;
}

export async function writeRecentContextSummaryMarkdown(
  input: WriteRecentContextSummaryMarkdownInput,
): Promise<RecentContextSummaryMarkdownRef> {
  const slug = recentContextSummarySlug(input.userId, input.agentId);
  const path = slugToAbsolutePath(input.rootDir, slug);
  const rendered = renderBrainPage({
    slug,
    type: "document",
    title: input.agentId ? `Recent Context: ${input.agentId}` : "Recent Context",
    frontmatter: frontmatter(input),
    compiledTruth: compiledTruth(input),
    timelineText: timelineText(input),
  });

  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, rendered, "utf8");

  return {
    root_dir: input.rootDir,
    path: relative(input.rootDir, path).replace(/\\/g, "/"),
    slug,
    content_hash: contentHash(rendered),
    generated_at: input.generatedAt,
  };
}

export function recentContextSummarySlug(userId: string, agentId?: string): string {
  const userSegment = normalizeSlug(userId) || "default-user";
  const agentSegment = normalizeSlug(agentId ?? "global") || "global";
  return `timelines/recent-context/${userSegment}/${agentSegment}/current`;
}

function frontmatter(input: WriteRecentContextSummaryMarkdownInput): JsonObject {
  const value: JsonObject = {
    generated_at: input.generatedAt,
    generated_by: "deterministic_summarizer",
    source: "recent_context_summary",
    source_hash: input.sourceHash,
    summary_id: input.summaryId,
    tags: ["generated", "recent-context"],
    updated_at: input.generatedAt,
    user_id: input.userId,
    window_ended_at: input.window.ended_at,
    window_started_at: input.window.started_at,
  };

  if (input.agentId) {
    value.agent_id = input.agentId;
  }

  return value;
}

function compiledTruth(input: WriteRecentContextSummaryMarkdownInput): string {
  return [
    "# Recent Context",
    "",
    input.summary,
    "",
    listSection("Active Apps", input.facts.active_apps),
    listSection("Websites", input.facts.websites),
    listSection("Repos", input.facts.repos),
    listSection("Files", input.facts.files),
    listSection("Projects", input.facts.projects),
    listSection("People", input.facts.people),
    listSection("Decisions", input.facts.decisions),
    listSection("Open Questions", input.facts.open_questions),
    eventEvidenceSection(input.sourceEvents),
  ]
    .filter((section) => section.trim().length > 0)
    .join("\n\n");
}

function timelineText(input: WriteRecentContextSummaryMarkdownInput): string {
  const eventIds = input.sourceEvents
    .slice(0, 12)
    .map((event) => event.id)
    .join(", ");
  const evidence = eventIds ? ` Source events: ${eventIds}.` : "";
  return `- ${input.window.ended_at.slice(0, 10)}: ${input.summary}${evidence}`;
}

function listSection(title: string, values: string[]): string {
  if (values.length === 0) {
    return "";
  }

  return [`## ${title}`, ...values.slice(0, 20).map((value) => `- ${value}`)].join("\n");
}

function eventEvidenceSection(events: RecentContextEvent[]): string {
  if (events.length === 0) {
    return "";
  }

  return [
    "## Source Event Excerpts",
    ...events.slice(0, 12).map((event) => `- ${event.id}: ${oneLine(event.content, 180)}`),
  ].join("\n");
}

function oneLine(value: string, maxLength: number): string {
  const normalized = value.replace(/\s+/g, " ").trim();
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return `${normalized.slice(0, maxLength - 3).trimEnd()}...`;
}
