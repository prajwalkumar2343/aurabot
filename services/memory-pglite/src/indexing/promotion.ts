import type { Evidence, PromotionResponse, RecentContextEvent } from "../contracts/index.js";
import { contentHash, sha256Hex, stableJson } from "../recent/hash.js";
import { normalizeSlug } from "../brain/paths.js";

export interface PromotionDraft {
  candidate_id: string;
  target_slug: string;
  suggested_edit: string;
  timeline_entry: string;
  confidence: number;
  evidence: Evidence[];
  metadata: {
    reason: string;
    occurrence_count: number;
    generated_by: string;
    generated_at: string;
  };
}

export interface DetectPromotionCandidatesOptions {
  events: RecentContextEvent[];
  now?: string;
  minOccurrences?: number;
}

const DEFAULT_MIN_OCCURRENCES = 2;

export function detectPromotionCandidates(
  options: DetectPromotionCandidatesOptions,
): PromotionDraft[] {
  const now = options.now ?? new Date().toISOString();
  const minOccurrences = options.minOccurrences ?? DEFAULT_MIN_OCCURRENCES;
  const candidates = [
    ...detectRepeatedMetadata(options.events, "projects", "projects", minOccurrences, now),
    ...detectRepeatedMetadata(options.events, "people", "people", minOccurrences, now),
    ...detectRepeatedMetadata(options.events, "companies", "companies", minOccurrences, now),
    ...detectRepeatedMetadata(options.events, "workflows", "workflows", minOccurrences, now),
    ...detectExplicitPreferences(options.events, now),
    ...detectExplicitDecisions(options.events, now),
  ];

  return candidates.sort((left, right) => right.confidence - left.confidence);
}

export function promotionDraftToResponse(draft: PromotionDraft): PromotionResponse {
  return {
    schema_version: "memory-v2",
    candidate_id: draft.candidate_id,
    mode: "draft",
    status: "drafted",
    target_slug: draft.target_slug,
    suggested_edit: draft.suggested_edit,
    evidence: draft.evidence,
    metadata: {
      ...draft.metadata,
      confidence: draft.confidence,
      timeline_entry: draft.timeline_entry,
    },
  };
}

function detectRepeatedMetadata(
  events: RecentContextEvent[],
  metadataKey: string,
  targetPrefix: string,
  minOccurrences: number,
  now: string,
): PromotionDraft[] {
  const grouped = new Map<string, RecentContextEvent[]>();
  for (const event of events) {
    for (const value of stringArray(event.metadata[metadataKey])) {
      const key = normalizeSlug(value);
      if (!key) {
        continue;
      }
      grouped.set(key, [...(grouped.get(key) ?? []), event]);
    }
  }

  return [...grouped.entries()]
    .filter(([, groupedEvents]) => groupedEvents.length >= minOccurrences)
    .map(([slugLeaf, groupedEvents]) =>
      buildDraft({
        targetSlug: `${targetPrefix}/${slugLeaf}`,
        suggestedEdit: `- ${titleFromSlug(slugLeaf)} appears repeatedly in recent context and may be durable.`,
        timelineEntry: `- ${now.slice(0, 10)}: ${titleFromSlug(slugLeaf)} appeared in ${groupedEvents.length} recent context events.`,
        reason: `repeated_${metadataKey}`,
        events: groupedEvents,
        now,
      }),
    );
}

function detectExplicitPreferences(events: RecentContextEvent[], now: string): PromotionDraft[] {
  return events
    .filter((event) => hasExplicitSignal(event, ["prefer", "preference", "likes", "always", "never"]))
    .map((event) =>
      buildDraft({
        targetSlug: "preferences",
        suggestedEdit: `- ${event.content}`,
        timelineEntry: `- ${event.occurred_at.slice(0, 10)}: Preference evidence captured: ${event.content}`,
        reason: "explicit_preference",
        events: [event],
        now,
      }),
    );
}

function detectExplicitDecisions(events: RecentContextEvent[], now: string): PromotionDraft[] {
  return events
    .filter((event) => hasExplicitSignal(event, ["decided", "decision", "will use", "settled on"]))
    .map((event) =>
      buildDraft({
        targetSlug: `decisions/${normalizeSlug(event.content).slice(0, 48)}`,
        suggestedEdit: `- ${event.content}`,
        timelineEntry: `- ${event.occurred_at.slice(0, 10)}: Decision evidence captured: ${event.content}`,
        reason: "explicit_decision",
        events: [event],
        now,
      }),
    );
}

function buildDraft(input: {
  targetSlug: string;
  suggestedEdit: string;
  timelineEntry: string;
  reason: string;
  events: RecentContextEvent[];
  now: string;
}): PromotionDraft {
  const evidence = input.events.map(eventToEvidence);
  const occurrenceCount = input.events.length;
  const candidateHash = contentHash(
    stableJson({
      target_slug: input.targetSlug,
      evidence: evidence.map((entry) => entry.source_id),
      reason: input.reason,
    }),
  );

  return {
    candidate_id: `promotion_${sha256Hex(candidateHash).slice(0, 24)}`,
    target_slug: input.targetSlug,
    suggested_edit: input.suggestedEdit,
    timeline_entry: input.timelineEntry,
    confidence: Math.min(0.95, 0.45 + occurrenceCount * 0.18),
    evidence,
    metadata: {
      reason: input.reason,
      occurrence_count: occurrenceCount,
      generated_by: "deterministic_promotion_detector",
      generated_at: input.now,
    },
  };
}

function eventToEvidence(event: RecentContextEvent): Evidence {
  return {
    source: "recent_context",
    source_id: event.id,
    excerpt: event.content,
    content_hash: event.content_hash,
    created_at: event.created_at,
    metadata: {
      occurred_at: event.occurred_at,
      source: event.source,
    },
  };
}

function hasExplicitSignal(event: RecentContextEvent, signals: string[]): boolean {
  const text = `${event.content} ${event.metadata.user_intent ?? ""}`.toLowerCase();
  return signals.some((signal) => text.includes(signal));
}

function stringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map((entry) => (typeof entry === "string" ? entry.trim() : ""))
    .filter(Boolean);
}

function titleFromSlug(slug: string): string {
  return slug
    .split("-")
    .filter(Boolean)
    .map((part) => `${part.charAt(0).toUpperCase()}${part.slice(1)}`)
    .join(" ");
}
