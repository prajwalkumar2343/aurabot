import { createHash } from "node:crypto";

export function sha256Hex(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

export function contentHash(value: string): string {
  return `sha256:${sha256Hex(value)}`;
}

export function stableJson(value: unknown): string {
  return JSON.stringify(sortJson(value));
}

function sortJson(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(sortJson);
  }

  if (value && typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>).sort(([left], [right]) =>
      left.localeCompare(right),
    );
    return Object.fromEntries(entries.map(([key, entryValue]) => [key, sortJson(entryValue)]));
  }

  return value;
}
