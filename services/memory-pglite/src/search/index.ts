import type {
  Evidence,
  JsonObject,
  MemoryScoreBreakdown,
  MemorySource,
  RelationRef,
  SearchMemoryItem,
  SearchMemoryResponse,
} from "../contracts/index.js";
import type { MemoryPgliteDatabase } from "../database/index.js";
import {
  graphQuery,
  loadRelationsForEntities,
  lookupEntitiesFromQuery,
  type EntityRecord,
} from "../graph/index.js";
import { contentHash } from "../recent/hash.js";
import { TABLES } from "../schema/constants.js";

const DEFAULT_SEARCH_LIMIT = 10;
const MAX_SEARCH_LIMIT = 50;
const RRF_K = 60;

export type SearchScope = "recent" | "long_term" | "graph" | "all";
export type SearchEmbeddingProvider = (texts: string[]) => Promise<number[][]> | number[][];

export interface SearchMemoryInput {
  query: string;
  userId: string;
  scopes?: SearchScope[];
  limit?: number;
  debug?: boolean;
  embedder?: SearchEmbeddingProvider;
  now?: string;
}

interface Candidate {
  id: string;
  source: MemorySource;
  content: string;
  user_id: string;
  entity_ids: string[];
  relations: RelationRef[];
  evidence: Evidence[];
  created_at: string;
  metadata: JsonObject;
  scores: MemoryScoreBreakdown;
  rrf: number;
}

interface BrainChunkRow {
  id: string;
  user_id: string;
  page_id: string;
  slug: string;
  chunk_type: string;
  content: string;
  metadata: unknown;
  content_hash: string;
  created_at: string | Date;
  updated_at: string | Date;
  distance?: number;
}

interface BrainPageRow {
  id: string;
  user_id: string;
  slug: string;
  page_type: string;
  title: string;
  content_hash: string;
  source_hash: string;
  updated_at: string | Date;
}

interface RecentEventRow {
  id: string;
  user_id: string;
  agent_id: string | null;
  source: string;
  screen_summary: string | null;
  metadata: unknown;
  content_hash: string | null;
  created_at: string | Date;
  distance?: number;
}

interface RecentSummaryRow {
  id: string;
  user_id: string;
  agent_id: string | null;
  summary: string;
  source_event_ids: unknown;
  metadata: unknown;
  source_hash: string;
  window_started_at: string | Date;
  window_ended_at: string | Date;
  created_at: string | Date;
  updated_at: string | Date;
  distance?: number;
}

interface EntityIdRow {
  id: string;
}

export async function searchMemory(
  database: MemoryPgliteDatabase,
  input: SearchMemoryInput,
): Promise<SearchMemoryResponse> {
  const query = input.query.trim();
  if (!query) {
    throw new Error("query is required");
  }

  const limit = boundedLimit(input.limit);
  const scopes = normalizeScopes(input.scopes);
  const now = input.now ?? new Date().toISOString();
  const matchedEntities = scopes.graph
    ? await lookupEntitiesFromQuery(database, { userId: input.userId, query, limit: 12 })
    : [];
  const lists: Array<{ component: keyof MemoryScoreBreakdown; candidates: Candidate[] }> = [];

  if (scopes.longTerm || scopes.recent) {
    const keywordCandidates = await keywordSearch(database, {
      userId: input.userId,
      query,
      scopes,
      limit: limit * 4,
      now,
    });
    lists.push({ component: "keyword", candidates: keywordCandidates });
  }

  if (input.embedder && (scopes.longTerm || scopes.recent)) {
    const vectorCandidates = await vectorSearch(database, {
      userId: input.userId,
      query,
      scopes,
      limit: limit * 3,
      embedder: input.embedder,
      now,
    });
    lists.push({ component: "vector", candidates: vectorCandidates });
  }

  if (scopes.graph) {
    const graphCandidates = await graphSearch(database, {
      userId: input.userId,
      query,
      matchedEntities,
      limit: limit * 3,
      now,
    });
    lists.push({ component: "graph", candidates: graphCandidates });
  }

  const merged = mergeCandidates(lists, now)
    .sort((left, right) => scoreCandidate(right) - scoreCandidate(left))
    .slice(0, limit);

  return {
    schema_version: "memory-v2",
    query,
    items: merged.map(candidateToSearchItem),
    debug: {
      matched_entities: matchedEntities.map((entity) => entity.id),
      ranking: {
        strategy: "rrf",
        components: lists.map((list) => list.component),
        limits: {
          requested: limit,
          returned: merged.length,
        },
        query_terms: tokenize(query),
      },
    },
  };
}

async function keywordSearch(
  database: MemoryPgliteDatabase,
  input: {
    userId: string;
    query: string;
    scopes: NormalizedScopes;
    limit: number;
    now: string;
  },
): Promise<Candidate[]> {
  const terms = tokenize(input.query);
  const candidates: Candidate[] = [];

  if (input.scopes.longTerm) {
    const chunks = await loadKeywordBrainChunks(database, input.userId, terms, input.limit);
    for (const row of chunks) {
      candidates.push(await brainChunkCandidate(database, row, keywordScore(row.content, terms), input.now));
    }
  }

  if (input.scopes.recent) {
    const summaries = await loadKeywordRecentSummaries(database, input.userId, terms, input.limit);
    for (const row of summaries) {
      candidates.push(
        await recentSummaryCandidate(database, row, keywordScore(row.summary, terms), input.now),
      );
    }

    const events = await loadKeywordRecentEvents(database, input.userId, terms, input.limit);
    for (const row of events) {
      candidates.push(
        await recentEventCandidate(database, row, keywordScore(row.screen_summary ?? "", terms), input.now),
      );
    }
  }

  return candidates.sort((left, right) => right.scores.keyword - left.scores.keyword).slice(0, input.limit);
}

async function vectorSearch(
  database: MemoryPgliteDatabase,
  input: {
    userId: string;
    query: string;
    scopes: NormalizedScopes;
    limit: number;
    embedder: SearchEmbeddingProvider;
    now: string;
  },
): Promise<Candidate[]> {
  const embedding = await embedQuery(input.embedder, input.query);
  const vectorLiteral = vectorLiteralFromEmbedding(embedding);
  const candidates: Candidate[] = [];

  if (input.scopes.longTerm) {
    const chunks = await database.query<BrainChunkRow>(
      `
        SELECT id, user_id, page_id, slug, chunk_type, content, metadata, content_hash, created_at, updated_at,
               (embedding <=> $2::vector) AS distance
        FROM ${TABLES.brainChunks}
        WHERE user_id = $1
          AND embedding IS NOT NULL
        ORDER BY embedding <=> $2::vector
        LIMIT $3
      `,
      [input.userId, vectorLiteral, input.limit],
    );
    for (const row of chunks.rows) {
      candidates.push(await brainChunkCandidate(database, row, vectorDistanceScore(row.distance), input.now, "vector"));
    }
  }

  if (input.scopes.recent) {
    const summaries = await database.query<RecentSummaryRow>(
      `
        SELECT id, user_id, agent_id, summary, source_event_ids, metadata, source_hash,
               window_started_at, window_ended_at, created_at, updated_at,
               (embedding <=> $2::vector) AS distance
        FROM ${TABLES.recentContextSummaries}
        WHERE user_id = $1
          AND embedding IS NOT NULL
        ORDER BY embedding <=> $2::vector
        LIMIT $3
      `,
      [input.userId, vectorLiteral, input.limit],
    );
    for (const row of summaries.rows) {
      candidates.push(
        await recentSummaryCandidate(database, row, vectorDistanceScore(row.distance), input.now, "vector"),
      );
    }
  }

  return candidates.sort((left, right) => right.scores.vector - left.scores.vector).slice(0, input.limit);
}

async function graphSearch(
  database: MemoryPgliteDatabase,
  input: {
    userId: string;
    query: string;
    matchedEntities: EntityRecord[];
    limit: number;
    now: string;
  },
): Promise<Candidate[]> {
  const candidates = new Map<string, Candidate>();

  for (const entity of input.matchedEntities) {
    const result = await graphQuery(database, {
      userId: input.userId,
      start: entity.id,
      depth: 2,
      direction: "both",
      limit: 40,
      now: input.now,
    });
    const nodeName = new Map(result.nodes.map((node) => [node.id, node.name]));

    for (const relation of result.relations) {
      const sourceName = nodeName.get(relation.source_entity_id) ?? relation.source_entity_id;
      const targetName = nodeName.get(relation.target_entity_id) ?? relation.target_entity_id;
      const content = `${sourceName} ${relation.relation_type.replace(/_/g, " ")} ${targetName}`;
      const createdAt = newestEvidenceTimestamp(relation.evidence) ?? input.now;
      const candidate: Candidate = {
        id: `graph_${relation.id}`,
        source: "graph",
        content,
        user_id: input.userId,
        entity_ids: uniqueStrings([relation.source_entity_id, relation.target_entity_id]),
        relations: [relation],
        evidence: relation.evidence,
        created_at: createdAt,
        metadata: {
          relation_id: relation.id,
          matched_entity_id: entity.id,
          explanation: "graph_neighbor",
        },
        scores: {
          vector: 0,
          keyword: keywordScore(content, tokenize(input.query)),
          graph: clamp01(0.55 + relation.confidence * 0.4),
          recency: recencyScore(createdAt, input.now),
        },
        rrf: 0,
      };
      candidates.set(`${candidate.source}:${candidate.id}`, candidate);
    }

    for (const relation of result.relations) {
      for (const evidence of relation.evidence) {
        const evidenceCandidate = await candidateFromEvidence(database, input.userId, evidence, relation, input.now);
        if (evidenceCandidate) {
          const key = `${evidenceCandidate.source}:${evidenceCandidate.id}`;
          const existing = candidates.get(key);
          if (existing) {
            existing.scores.graph = Math.max(existing.scores.graph, relation.confidence);
            existing.relations = mergeRelations(existing.relations, [relation]);
            existing.entity_ids = uniqueStrings([
              ...existing.entity_ids,
              relation.source_entity_id,
              relation.target_entity_id,
            ]);
          } else {
            candidates.set(key, evidenceCandidate);
          }
        }
      }
    }
  }

  return [...candidates.values()]
    .sort((left, right) => right.scores.graph - left.scores.graph)
    .slice(0, input.limit);
}

async function candidateFromEvidence(
  database: MemoryPgliteDatabase,
  userId: string,
  evidence: Evidence,
  relation: RelationRef,
  now: string,
): Promise<Candidate | null> {
  if (evidence.source === "brain_chunk") {
    const result = await database.query<BrainChunkRow>(
      `
        SELECT id, user_id, page_id, slug, chunk_type, content, metadata, content_hash, created_at, updated_at
        FROM ${TABLES.brainChunks}
        WHERE user_id = $1
          AND id = $2
        LIMIT 1
      `,
      [userId, evidence.source_id],
    );
    const row = result.rows[0];
    return row ? brainChunkCandidate(database, row, relation.confidence, now, "graph", [relation]) : null;
  }

  if (evidence.source === "brain_page") {
    const result = await database.query<BrainPageRow>(
      `
        SELECT id, user_id, slug, page_type, title, content_hash, source_hash, updated_at
        FROM ${TABLES.brainPages}
        WHERE user_id = $1
          AND id = $2
        LIMIT 1
      `,
      [userId, evidence.source_id],
    );
    const row = result.rows[0];
    if (!row) {
      return null;
    }
    const entityIds = await entityIdsForSlug(database, userId, row.slug);
    return {
      id: row.id,
      source: "brain_page",
      content: row.title,
      user_id: row.user_id,
      entity_ids: entityIds,
      relations: [relation],
      evidence: [
        {
          source: "brain_page",
          source_id: row.id,
          excerpt: row.title,
          content_hash: row.source_hash,
          created_at: toIso(row.updated_at),
        },
      ],
      created_at: toIso(row.updated_at),
      metadata: {
        slug: row.slug,
        page_type: row.page_type,
      },
      scores: {
        vector: 0,
        keyword: 0,
        graph: relation.confidence,
        recency: recencyScore(toIso(row.updated_at), now),
      },
      rrf: 0,
    };
  }

  if (evidence.source === "recent_context") {
    const result = await database.query<RecentEventRow>(
      `
        SELECT id, user_id, agent_id, source, screen_summary, metadata, content_hash, created_at
        FROM ${TABLES.recentContextEvents}
        WHERE user_id = $1
          AND id = $2
        LIMIT 1
      `,
      [userId, evidence.source_id],
    );
    const row = result.rows[0];
    return row ? recentEventCandidate(database, row, relation.confidence, now, "graph", [relation]) : null;
  }

  return null;
}

async function loadKeywordBrainChunks(
  database: MemoryPgliteDatabase,
  userId: string,
  terms: string[],
  limit: number,
): Promise<BrainChunkRow[]> {
  if (terms.length === 0) {
    return [];
  }

  const { condition, params } = likeCondition("content", terms, 2);
  const result = await database.query<BrainChunkRow>(
    `
      SELECT id, user_id, page_id, slug, chunk_type, content, metadata, content_hash, created_at, updated_at
      FROM ${TABLES.brainChunks}
      WHERE user_id = $1
        AND (${condition})
      ORDER BY updated_at DESC
      LIMIT $${params.length + 2}
    `,
    [userId, ...params, limit],
  );
  return result.rows;
}

async function loadKeywordRecentSummaries(
  database: MemoryPgliteDatabase,
  userId: string,
  terms: string[],
  limit: number,
): Promise<RecentSummaryRow[]> {
  if (terms.length === 0) {
    return [];
  }

  const { condition, params } = likeCondition("summary", terms, 2);
  const result = await database.query<RecentSummaryRow>(
    `
      SELECT id, user_id, agent_id, summary, source_event_ids, metadata, source_hash,
             window_started_at, window_ended_at, created_at, updated_at
      FROM ${TABLES.recentContextSummaries}
      WHERE user_id = $1
        AND (${condition})
      ORDER BY window_ended_at DESC
      LIMIT $${params.length + 2}
    `,
    [userId, ...params, limit],
  );
  return result.rows;
}

async function loadKeywordRecentEvents(
  database: MemoryPgliteDatabase,
  userId: string,
  terms: string[],
  limit: number,
): Promise<RecentEventRow[]> {
  if (terms.length === 0) {
    return [];
  }

  const { condition, params } = likeCondition("screen_summary", terms, 2);
  const result = await database.query<RecentEventRow>(
    `
      SELECT id, user_id, agent_id, source, screen_summary, metadata, content_hash, created_at
      FROM ${TABLES.recentContextEvents}
      WHERE user_id = $1
        AND screen_summary IS NOT NULL
        AND (${condition})
      ORDER BY created_at DESC
      LIMIT $${params.length + 2}
    `,
    [userId, ...params, limit],
  );
  return result.rows;
}

async function brainChunkCandidate(
  database: MemoryPgliteDatabase,
  row: BrainChunkRow,
  score: number,
  now: string,
  component: keyof MemoryScoreBreakdown = "keyword",
  seedRelations: RelationRef[] = [],
): Promise<Candidate> {
  const createdAt = toIso(row.updated_at);
  const entityIds = await entityIdsForSlug(database, row.user_id, row.slug);
  const relations = mergeRelations(
    seedRelations,
    await loadRelationsForEntities(database, row.user_id, entityIds, 20),
  );
  return {
    id: row.id,
    source: "brain_chunk",
    content: row.content,
    user_id: row.user_id,
    entity_ids: entityIds,
    relations,
    evidence: [
      {
        source: "brain_chunk",
        source_id: row.id,
        excerpt: excerpt(row.content),
        content_hash: row.content_hash,
        created_at: createdAt,
      },
    ],
    created_at: createdAt,
    metadata: {
      ...jsonObject(row.metadata),
      slug: row.slug,
      chunk_type: row.chunk_type,
    },
    scores: componentScore(component, score, createdAt, now, chunkBoost(row.chunk_type)),
    rrf: 0,
  };
}

async function recentSummaryCandidate(
  database: MemoryPgliteDatabase,
  row: RecentSummaryRow,
  score: number,
  now: string,
  component: keyof MemoryScoreBreakdown = "keyword",
): Promise<Candidate> {
  const createdAt = toIso(row.created_at);
  const evidence = sourceEventIds(row.source_event_ids).map((id) => ({
    source: "recent_context" as const,
    source_id: id,
    excerpt: row.summary,
    content_hash: row.source_hash,
    created_at: createdAt,
  }));
  const relations = await relationsForEvidenceIds(database, row.user_id, evidence.map((entry) => entry.source_id));
  const entityIds = entityIdsFromRelations(relations);
  return {
    id: row.id,
    source: "recent_summary",
    content: row.summary,
    user_id: row.user_id,
    entity_ids: entityIds,
    relations,
    evidence:
      evidence.length > 0
        ? evidence
        : [
            {
              source: "recent_summary",
              source_id: row.id,
              excerpt: row.summary,
              content_hash: row.source_hash,
              created_at: createdAt,
            },
          ],
    created_at: createdAt,
    metadata: {
      ...jsonObject(row.metadata),
      window_started_at: toIso(row.window_started_at),
      window_ended_at: toIso(row.window_ended_at),
    },
    scores: componentScore(component, score, createdAt, now, 0.03),
    rrf: 0,
  };
}

async function recentEventCandidate(
  database: MemoryPgliteDatabase,
  row: RecentEventRow,
  score: number,
  now: string,
  component: keyof MemoryScoreBreakdown = "keyword",
  seedRelations: RelationRef[] = [],
): Promise<Candidate> {
  const createdAt = toIso(row.created_at);
  const relations = mergeRelations(seedRelations, await relationsForEvidenceIds(database, row.user_id, [row.id]));
  return {
    id: row.id,
    source: "recent_context",
    content: row.screen_summary ?? "",
    user_id: row.user_id,
    entity_ids: entityIdsFromRelations(relations),
    relations,
    evidence: [
      {
        source: "recent_context",
        source_id: row.id,
        excerpt: excerpt(row.screen_summary ?? ""),
        content_hash: row.content_hash ?? contentHash(row.screen_summary ?? ""),
        created_at: createdAt,
      },
    ],
    created_at: createdAt,
    metadata: {
      ...jsonObject(row.metadata),
      source: row.source,
    },
    scores: componentScore(component, score, createdAt, now, 0.05),
    rrf: 0,
  };
}

async function entityIdsForSlug(
  database: MemoryPgliteDatabase,
  userId: string,
  slug: string,
): Promise<string[]> {
  const result = await database.query<EntityIdRow>(
    `
      SELECT id
      FROM ${TABLES.entities}
      WHERE user_id = $1
        AND slug = $2
    `,
    [userId, slug],
  );
  return result.rows.map((row) => row.id);
}

async function relationsForEvidenceIds(
  database: MemoryPgliteDatabase,
  userId: string,
  evidenceIds: string[],
): Promise<RelationRef[]> {
  const ids = uniqueStrings(evidenceIds);
  if (ids.length === 0) {
    return [];
  }

  const result = await database.query<{
    id: string;
    source_entity_id: string;
    target_entity_id: string;
    relation_type: string;
    confidence: number;
    evidence: unknown;
  }>(
    `
      SELECT id, source_entity_id, target_entity_id, relation_type, confidence, evidence
      FROM ${TABLES.entityLinks}
      WHERE user_id = $1
        AND evidence_source_id = ANY($2::text[])
      ORDER BY confidence DESC, updated_at DESC
      LIMIT 50
    `,
    [userId, ids],
  );
  return result.rows.map((row) => ({
    id: row.id,
    relation_type: row.relation_type as RelationRef["relation_type"],
    source_entity_id: row.source_entity_id,
    target_entity_id: row.target_entity_id,
    confidence: row.confidence,
    evidence: evidenceArray(row.evidence),
  }));
}

function mergeCandidates(
  lists: Array<{ component: keyof MemoryScoreBreakdown; candidates: Candidate[] }>,
  now: string,
): Candidate[] {
  const merged = new Map<string, Candidate>();

  for (const list of lists) {
    list.candidates.forEach((candidate, index) => {
      const key = `${candidate.source}:${candidate.id}`;
      const existing = merged.get(key);
      const rrf = 1 / (RRF_K + index + 1);
      if (!existing) {
        candidate.rrf += rrf;
        candidate.scores.recency = Math.max(candidate.scores.recency, recencyScore(candidate.created_at, now));
        merged.set(key, candidate);
        return;
      }

      existing.rrf += rrf;
      existing.scores[list.component] = Math.max(
        existing.scores[list.component],
        candidate.scores[list.component],
      );
      existing.scores.recency = Math.max(existing.scores.recency, candidate.scores.recency);
      existing.entity_ids = uniqueStrings([...existing.entity_ids, ...candidate.entity_ids]);
      existing.relations = mergeRelations(existing.relations, candidate.relations);
      existing.evidence = mergeEvidence(existing.evidence, candidate.evidence);
      existing.metadata = {
        ...existing.metadata,
        ranking_components: uniqueStrings([
          ...stringList(existing.metadata.ranking_components),
          list.component,
        ]),
      };
    });
  }

  return [...merged.values()];
}

function candidateToSearchItem(candidate: Candidate): SearchMemoryItem {
  const score = scoreCandidate(candidate);
  return {
    id: candidate.id,
    source: candidate.source,
    content: candidate.content,
    user_id: candidate.user_id,
    entity_ids: candidate.entity_ids,
    relations: candidate.relations,
    evidence: candidate.evidence,
    score,
    scores: {
      vector: roundScore(candidate.scores.vector),
      keyword: roundScore(candidate.scores.keyword),
      graph: roundScore(candidate.scores.graph),
      recency: roundScore(candidate.scores.recency),
    },
    created_at: candidate.created_at,
    metadata: {
      ...candidate.metadata,
      ranking: {
        rrf: roundScore(candidate.rrf),
        explanation: rankingExplanation(candidate),
      },
    },
  };
}

function scoreCandidate(candidate: Candidate): number {
  const weighted =
    candidate.scores.vector * 0.32 +
    candidate.scores.keyword * 0.26 +
    candidate.scores.graph * 0.32 +
    candidate.scores.recency * 0.1 +
    candidate.rrf;
  return roundScore(clamp01(weighted));
}

function componentScore(
  component: keyof MemoryScoreBreakdown,
  score: number,
  createdAt: string,
  now: string,
  boost = 0,
): MemoryScoreBreakdown {
  return {
    vector: component === "vector" ? clamp01(score + boost) : 0,
    keyword: component === "keyword" ? clamp01(score + boost) : 0,
    graph: component === "graph" ? clamp01(score + boost) : 0,
    recency: recencyScore(createdAt, now),
  };
}

function chunkBoost(chunkType: string): number {
  if (chunkType === "compiled_truth") {
    return 0.12;
  }
  if (chunkType === "timeline") {
    return 0.07;
  }
  return 0.02;
}

function keywordScore(content: string, terms: string[]): number {
  if (!content || terms.length === 0) {
    return 0;
  }
  const lower = content.toLowerCase();
  const hits = terms.filter((term) => lower.includes(term)).length;
  const density = hits / Math.max(terms.length, 1);
  const phraseBoost = lower.includes(terms.join(" ")) ? 0.2 : 0;
  return clamp01(density * 0.8 + phraseBoost);
}

function vectorDistanceScore(distance: number | undefined): number {
  if (distance === undefined || !Number.isFinite(distance)) {
    return 0;
  }
  return clamp01(1 - Math.max(0, distance));
}

function recencyScore(createdAt: string, now: string): number {
  const then = new Date(createdAt).getTime();
  const current = new Date(now).getTime();
  if (!Number.isFinite(then) || !Number.isFinite(current) || then > current) {
    return 0;
  }
  const hours = (current - then) / 3_600_000;
  if (hours <= 6) {
    return 1;
  }
  if (hours >= 24 * 30) {
    return 0.05;
  }
  return clamp01(1 / (1 + hours / 24));
}

function likeCondition(column: string, terms: string[], startIndex: number): { condition: string; params: string[] } {
  const params = terms.map((term) => `%${term.toLowerCase()}%`);
  const condition = params
    .map((_, index) => `LOWER(${column}) LIKE $${startIndex + index}`)
    .join(" OR ");
  return { condition, params };
}

function normalizeScopes(scopes: SearchScope[] | undefined): NormalizedScopes {
  const values = new Set(scopes ?? ["all"]);
  return {
    recent: values.has("all") || values.has("recent"),
    longTerm: values.has("all") || values.has("long_term"),
    graph: values.has("all") || values.has("graph"),
  };
}

interface NormalizedScopes {
  recent: boolean;
  longTerm: boolean;
  graph: boolean;
}

function tokenize(query: string): string[] {
  const stopWords = new Set(["a", "an", "and", "are", "about", "did", "do", "for", "is", "of", "the", "this", "to", "we", "what"]);
  return uniqueStrings(
    query
      .toLowerCase()
      .replace(/[^a-z0-9./:-]+/g, " ")
      .split(/\s+/)
      .map((term) => term.trim())
      .filter((term) => term.length >= 2 && !stopWords.has(term)),
  );
}

function boundedLimit(value: number | undefined): number {
  if (value === undefined) {
    return DEFAULT_SEARCH_LIMIT;
  }
  if (!Number.isInteger(value) || value <= 0) {
    throw new Error("limit must be a positive integer");
  }
  return Math.min(value, MAX_SEARCH_LIMIT);
}

async function embedQuery(embedder: SearchEmbeddingProvider, query: string): Promise<number[]> {
  const result = await embedder([query]);
  const embedding = result[0];
  if (!Array.isArray(embedding) || embedding.length === 0) {
    throw new Error("embedder returned no embedding for search query");
  }
  return embedding.map((value) => Number(value));
}

function vectorLiteralFromEmbedding(embedding: number[]): string {
  return `[${embedding.map((value) => Number(value).toFixed(12)).join(",")}]`;
}

function evidenceArray(value: unknown): Evidence[] {
  const parsed = parseJson(value);
  if (!Array.isArray(parsed)) {
    return [];
  }
  return parsed
    .filter((entry): entry is Record<string, unknown> => Boolean(entry) && typeof entry === "object")
    .map((entry) => {
      const evidence: Evidence = {
        source: (typeof entry.source === "string" ? entry.source : "graph") as Evidence["source"],
        source_id: typeof entry.source_id === "string" ? entry.source_id : "",
      };
      if (typeof entry.excerpt === "string") {
        evidence.excerpt = entry.excerpt;
      }
      if (typeof entry.content_hash === "string") {
        evidence.content_hash = entry.content_hash;
      }
      if (typeof entry.created_at === "string") {
        evidence.created_at = entry.created_at;
      }
      const metadata = jsonObject(entry.metadata);
      if (Object.keys(metadata).length > 0) {
        evidence.metadata = metadata;
      }
      return evidence;
    })
    .filter((entry) => entry.source_id.length > 0);
}

function jsonObject(value: unknown): JsonObject {
  const parsed = parseJson(value);
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    return {};
  }
  return parsed as JsonObject;
}

function parseJson(value: unknown): unknown {
  if (typeof value !== "string") {
    return value;
  }
  try {
    return JSON.parse(value) as unknown;
  } catch {
    return value;
  }
}

function sourceEventIds(value: unknown): string[] {
  return stringList(value);
}

function stringList(value: unknown): string[] {
  const parsed = parseJson(value);
  if (Array.isArray(parsed)) {
    return parsed.filter((entry): entry is string => typeof entry === "string" && entry.trim().length > 0);
  }
  return [];
}

function entityIdsFromRelations(relations: RelationRef[]): string[] {
  return uniqueStrings(relations.flatMap((relation) => [relation.source_entity_id, relation.target_entity_id]));
}

function mergeRelations(left: RelationRef[], right: RelationRef[]): RelationRef[] {
  const relations = new Map<string, RelationRef>();
  for (const relation of [...left, ...right]) {
    relations.set(relation.id, relation);
  }
  return [...relations.values()];
}

function mergeEvidence(left: Evidence[], right: Evidence[]): Evidence[] {
  const evidence = new Map<string, Evidence>();
  for (const item of [...left, ...right]) {
    evidence.set(`${item.source}:${item.source_id}:${item.content_hash ?? ""}`, item);
  }
  return [...evidence.values()];
}

function newestEvidenceTimestamp(evidence: Evidence[]): string | undefined {
  return evidence
    .map((entry) => entry.created_at)
    .filter((value): value is string => Boolean(value))
    .sort()
    .at(-1);
}

function rankingExplanation(candidate: Candidate): string[] {
  const explanations: string[] = [];
  if (candidate.scores.vector > 0) {
    explanations.push("vector_match");
  }
  if (candidate.scores.keyword > 0) {
    explanations.push("keyword_match");
  }
  if (candidate.scores.graph > 0) {
    explanations.push("graph_neighbor");
  }
  if (candidate.scores.recency > 0.7) {
    explanations.push("recent_context_boost");
  }
  return explanations;
}

function uniqueStrings(values: string[]): string[] {
  return [...new Set(values.map((value) => value.trim()).filter(Boolean))];
}

function clamp01(value: number): number {
  if (!Number.isFinite(value)) {
    return 0;
  }
  return Math.max(0, Math.min(1, value));
}

function roundScore(value: number): number {
  return Math.round(clamp01(value) * 10000) / 10000;
}

function excerpt(value: string): string {
  return value.replace(/\s+/g, " ").trim().slice(0, 280);
}

function toIso(value: string | Date): string {
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}
