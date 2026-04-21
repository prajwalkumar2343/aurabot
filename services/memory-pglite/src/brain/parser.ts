import type { EntityType, JsonObject, JsonValue } from "../contracts/index.js";
import { ENTITY_TYPES } from "../contracts/index.js";
import { contentHash, stableJson } from "../recent/hash.js";
import { normalizeSlug, relativePathToSlug } from "./paths.js";

export interface BrainParseError {
  code: string;
  message: string;
  line?: number;
}

export interface BrainTimelineEntry {
  raw: string;
  summary: string;
  event_date?: string;
  event_timestamp?: string;
  content_hash: string;
}

export interface ParsedBrainPage {
  path?: string;
  slug: string;
  type: EntityType;
  title: string;
  frontmatter: JsonObject;
  compiled_truth: string;
  timeline_text: string;
  links: string[];
  timeline_entries: BrainTimelineEntry[];
  content_hash: string;
  source_hash: string;
  errors: BrainParseError[];
}

const BODY_DIVIDER = "---";

export function parseBrainPage(markdown: string, options: { path?: string } = {}): ParsedBrainPage {
  const normalized = markdown.replace(/\r\n?/g, "\n");
  const contentHashValue = contentHash(normalized);
  const fallbackSlug = options.path ? relativePathToSlug(options.path) : "concepts/untitled";
  const errors: BrainParseError[] = [];

  const frontmatterBounds = findFrontmatterBounds(normalized);
  if (!frontmatterBounds) {
    errors.push({
      code: "missing_frontmatter",
      message: "Brain page must start with YAML frontmatter delimited by ---.",
      line: 1,
    });
    return fallbackPage(options.path, fallbackSlug, normalized, contentHashValue, errors);
  }

  const frontmatterText = normalized.slice(frontmatterBounds.start, frontmatterBounds.end);
  const frontmatter = parseFrontmatter(frontmatterText, errors);
  const body = normalized.slice(frontmatterBounds.after).replace(/^\n+/, "");
  const split = splitBody(body, errors);
  const slug = normalizeSlug(readString(frontmatter.slug) ?? fallbackSlug);
  const type = normalizeEntityType(readString(frontmatter.type), slug, errors);
  const title = readString(frontmatter.title) ?? titleFromSlug(slug);
  const links = extractLinks(`${split.compiledTruth}\n${split.timelineText}`);
  const timelineEntries = parseTimelineEntries(split.timelineText);

  const parsed: ParsedBrainPage = {
    slug,
    type,
    title,
    frontmatter: {
      ...frontmatter,
      slug,
      type,
      title,
    },
    compiled_truth: trimTrailingBlankLines(split.compiledTruth),
    timeline_text: trimTrailingBlankLines(split.timelineText),
    links,
    timeline_entries: timelineEntries,
    content_hash: contentHashValue,
    source_hash: contentHash(stableJson({ frontmatter, body })),
    errors,
  };
  if (options.path) {
    parsed.path = options.path;
  }
  return parsed;
}

export function renderBrainPage(input: {
  slug: string;
  type: EntityType;
  title: string;
  frontmatter?: JsonObject;
  compiledTruth?: string;
  timelineText?: string;
}): string {
  const frontmatter: JsonObject = {
    ...(input.frontmatter ?? {}),
    slug: input.slug,
    type: input.type,
    title: input.title,
  };
  const compiledTruth = trimTrailingBlankLines(input.compiledTruth ?? "");
  const timelineText = trimTrailingBlankLines(input.timelineText ?? "");

  return [
    BODY_DIVIDER,
    renderFrontmatter(frontmatter),
    BODY_DIVIDER,
    "",
    compiledTruth,
    "",
    BODY_DIVIDER,
    "",
    timelineText,
    "",
  ].join("\n");
}

function findFrontmatterBounds(markdown: string): { start: number; end: number; after: number } | null {
  if (!markdown.startsWith(`${BODY_DIVIDER}\n`)) {
    return null;
  }

  const closing = markdown.indexOf(`\n${BODY_DIVIDER}\n`, BODY_DIVIDER.length + 1);
  if (closing === -1) {
    return null;
  }

  return {
    start: BODY_DIVIDER.length + 1,
    end: closing,
    after: closing + BODY_DIVIDER.length + 2,
  };
}

function parseFrontmatter(text: string, errors: BrainParseError[]): JsonObject {
  const result: JsonObject = {};
  const lines = text.split("\n");
  let arrayKey: string | null = null;

  lines.forEach((line, index) => {
    const lineNumber = index + 2;
    if (!line.trim() || line.trim().startsWith("#")) {
      return;
    }

    const arrayMatch = line.match(/^\s*-\s+(.+)$/);
    if (arrayMatch && arrayKey) {
      const current = result[arrayKey];
      const values = Array.isArray(current) ? current : [];
      result[arrayKey] = [...values, parseScalar(arrayMatch[1] ?? "")];
      return;
    }

    arrayKey = null;
    const match = line.match(/^([A-Za-z0-9_-]+):(?:\s*(.*))?$/);
    if (!match) {
      errors.push({
        code: "invalid_frontmatter",
        message: `Unsupported frontmatter line: ${line}`,
        line: lineNumber,
      });
      return;
    }

    const key = match[1] ?? "";
    const rawValue = match[2] ?? "";
    if (!rawValue.trim()) {
      result[key] = [];
      arrayKey = key;
      return;
    }

    result[key] = parseScalar(rawValue);
  });

  for (const required of ["slug", "type", "title"]) {
    if (!readString(result[required])) {
      errors.push({
        code: "missing_frontmatter_field",
        message: `Frontmatter field '${required}' is required.`,
      });
    }
  }

  return result;
}

function parseScalar(rawValue: string): JsonValue {
  const value = rawValue.trim();
  if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
    return value.slice(1, -1);
  }

  if (value === "true") {
    return true;
  }
  if (value === "false") {
    return false;
  }
  if (value === "null") {
    return null;
  }
  if (/^-?\d+(\.\d+)?$/.test(value)) {
    return Number(value);
  }
  if (value.startsWith("[") && value.endsWith("]")) {
    const inner = value.slice(1, -1).trim();
    if (!inner) {
      return [];
    }
    return inner.split(",").map((entry) => parseScalar(entry.trim()));
  }

  return value;
}

function renderFrontmatter(frontmatter: JsonObject): string {
  return Object.entries(frontmatter)
    .sort(([left], [right]) => {
      const order = ["slug", "type", "title", "created_at", "updated_at"];
      const leftIndex = order.indexOf(left);
      const rightIndex = order.indexOf(right);
      if (leftIndex !== -1 || rightIndex !== -1) {
        return (leftIndex === -1 ? order.length : leftIndex) - (rightIndex === -1 ? order.length : rightIndex);
      }
      return left.localeCompare(right);
    })
    .map(([key, value]) => `${key}: ${renderYamlValue(value)}`)
    .join("\n");
}

function renderYamlValue(value: JsonValue): string {
  if (Array.isArray(value)) {
    return `[${value.map(renderYamlValue).join(", ")}]`;
  }

  if (value && typeof value === "object") {
    return JSON.stringify(value);
  }

  if (typeof value === "string") {
    return /^[a-z0-9_./:-]+$/i.test(value) ? value : JSON.stringify(value);
  }

  return String(value);
}

function splitBody(body: string, errors: BrainParseError[]): { compiledTruth: string; timelineText: string } {
  const lines = body.split("\n");
  const dividers = lines
    .map((line, index) => ({ line, index }))
    .filter((entry) => entry.line.trim() === BODY_DIVIDER);

  if (dividers.length > 1) {
    errors.push({
      code: "duplicate_timeline_divider",
      message: "Brain page body may contain only one --- divider between compiled truth and timeline.",
      line: (dividers[1]?.index ?? 0) + 1,
    });
  }

  const firstDivider = dividers[0];
  if (!firstDivider) {
    return {
      compiledTruth: body,
      timelineText: "",
    };
  }

  return {
    compiledTruth: lines.slice(0, firstDivider.index).join("\n"),
    timelineText: lines.slice(firstDivider.index + 1).join("\n"),
  };
}

function extractLinks(markdown: string): string[] {
  const links = new Set<string>();
  const wikiPattern = /\[\[([^\]|#]+)(?:#[^\]|]+)?(?:\|[^\]]+)?\]\]/g;
  const slugPattern = /\[[^\]]+\]\(slug:([a-zA-Z0-9_./ -]+)\)/g;

  for (const match of markdown.matchAll(wikiPattern)) {
    const slug = normalizeSlug(match[1] ?? "");
    if (slug) {
      links.add(slug);
    }
  }

  for (const match of markdown.matchAll(slugPattern)) {
    const slug = normalizeSlug(match[1] ?? "");
    if (slug) {
      links.add(slug);
    }
  }

  return [...links].sort();
}

function parseTimelineEntries(timelineText: string): BrainTimelineEntry[] {
  return timelineText
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.startsWith("- "))
    .map((line) => {
      const raw = line.slice(2).trim();
      const match = raw.match(/^(\d{4}-\d{2}-\d{2})(?:[T ][0-9:.+-Z]+)?\s*[:|-]\s*(.+)$/);
      const entry: BrainTimelineEntry = {
        raw,
        summary: match?.[2]?.trim() ?? raw,
        content_hash: contentHash(raw),
      };
      if (match?.[1]) {
        entry.event_date = match[1];
      }
      return entry;
    });
}

function fallbackPage(
  path: string | undefined,
  slug: string,
  markdown: string,
  hash: string,
  errors: BrainParseError[],
): ParsedBrainPage {
  const normalizedSlug = normalizeSlug(slug);
  const fallback: ParsedBrainPage = {
    slug: normalizedSlug,
    type: "concept",
    title: titleFromSlug(normalizedSlug),
    frontmatter: {},
    compiled_truth: markdown,
    timeline_text: "",
    links: extractLinks(markdown),
    timeline_entries: [],
    content_hash: hash,
    source_hash: hash,
    errors,
  };
  if (path) {
    fallback.path = path;
  }
  return fallback;
}

function normalizeEntityType(value: string | undefined, slug: string, errors: BrainParseError[]): EntityType {
  const candidate = value ?? typeFromSlug(slug);
  if (ENTITY_TYPES.includes(candidate as EntityType)) {
    return candidate as EntityType;
  }

  errors.push({
    code: "invalid_entity_type",
    message: `Unsupported brain page type: ${candidate}`,
  });
  return typeFromSlug(slug);
}

function typeFromSlug(slug: string): EntityType {
  if (slug === "user") {
    return "user";
  }
  if (slug === "preferences") {
    return "preference";
  }

  const prefix = slug.split("/")[0];
  switch (prefix) {
    case "projects":
      return "project";
    case "people":
      return "person";
    case "companies":
      return "company";
    case "workflows":
      return "workflow";
    case "apps":
      return "app";
    case "websites":
      return "website";
    case "repos":
      return "repo";
    case "files":
      return "file";
    case "decisions":
      return "decision";
    case "timelines":
      return "document";
    default:
      return "concept";
  }
}

function titleFromSlug(slug: string): string {
  const leaf = slug.split("/").at(-1) ?? slug;
  return leaf
    .split("-")
    .filter(Boolean)
    .map((part) => `${part.charAt(0).toUpperCase()}${part.slice(1)}`)
    .join(" ");
}

function readString(value: JsonValue | undefined): string | undefined {
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

function trimTrailingBlankLines(value: string): string {
  return value.replace(/\s+$/g, "");
}
