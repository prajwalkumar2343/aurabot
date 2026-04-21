import { homedir } from "node:os";
import { resolve, sep } from "node:path";
import { resolveAuraBotHome } from "../config/paths.js";

const DEFAULT_BRAIN_RELATIVE_DIR = "brain";
const TYPED_PREFIXES = [
  "projects",
  "people",
  "companies",
  "workflows",
  "apps",
  "websites",
  "repos",
  "files",
  "concepts",
  "decisions",
  "timelines",
] as const;

export type BrainPagePrefix = (typeof TYPED_PREFIXES)[number];

function expandHome(value: string): string {
  if (value === "~") {
    return homedir();
  }

  if (value.startsWith("~/")) {
    return resolve(homedir(), value.slice(2));
  }

  return value;
}

function requiredNonEmpty(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

export function resolveBrainDir(env: NodeJS.ProcessEnv = process.env): string {
  const configured = requiredNonEmpty(env.AURABOT_BRAIN_DIR);
  if (configured) {
    return resolve(expandHome(configured));
  }

  return resolve(resolveAuraBotHome(env), DEFAULT_BRAIN_RELATIVE_DIR);
}

export function normalizeSlug(value: string): string {
  const withoutExtension = value
    .trim()
    .replace(/\\/g, "/")
    .replace(/\.md$/i, "");
  return withoutExtension
    .toLowerCase()
    .replace(/_/g, "-")
    .replace(/\s+/g, "-")
    .replace(/[^a-z0-9/-]+/g, "-")
    .replace(/\/+/g, "/")
    .replace(/-+/g, "-")
    .replace(/(^\/|\/$)/g, "")
    .replace(/(^-|-$)/g, "");
}

export function assertValidBrainSlug(slug: string): void {
  if (slug !== "user" && slug !== "preferences") {
    const prefix = slug.split("/")[0];
    if (!TYPED_PREFIXES.includes(prefix as BrainPagePrefix)) {
      throw new Error(`brain slug must use a typed prefix: ${slug}`);
    }
  }

  if (!/^[a-z0-9/-]+$/.test(slug) || slug.includes("//")) {
    throw new Error(`brain slug contains unsupported characters: ${slug}`);
  }

  if (slug.split("/").some((part) => part.length === 0 || part === "." || part === "..")) {
    throw new Error(`brain slug contains unsafe path components: ${slug}`);
  }
}

export function slugToRelativePath(slug: string): string {
  const normalized = normalizeSlug(slug);
  assertValidBrainSlug(normalized);

  if (normalized === "user") {
    return "USER.md";
  }

  if (normalized === "preferences") {
    return "PREFERENCES.md";
  }

  return `${normalized}.md`;
}

export function slugToAbsolutePath(rootDir: string, slug: string): string {
  const root = resolve(rootDir);
  const target = resolve(root, slugToRelativePath(slug));
  const rootWithSeparator = root.endsWith(sep) ? root : `${root}${sep}`;

  if (target !== root && !target.startsWith(rootWithSeparator)) {
    throw new Error(`brain slug resolves outside brain directory: ${slug}`);
  }

  return target;
}

export function relativePathToSlug(path: string): string {
  const normalizedPath = path.replace(/\\/g, "/");
  if (normalizedPath === "USER.md") {
    return "user";
  }

  if (normalizedPath === "PREFERENCES.md") {
    return "preferences";
  }

  return normalizeSlug(normalizedPath);
}

export function brainPagePrefixes(): readonly BrainPagePrefix[] {
  return TYPED_PREFIXES;
}
