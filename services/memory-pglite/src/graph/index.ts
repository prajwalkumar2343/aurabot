import { basename, normalize as normalizePath } from "node:path";
import type {
  EntityType,
  Evidence,
  GraphNode,
  GraphQueryResponse,
  JsonObject,
  JsonValue,
  RelationRef,
  RelationType,
} from "../contracts/index.js";
import type { MemoryPgliteDatabase } from "../database/index.js";
import { contentHash, sha256Hex, stableJson } from "../recent/hash.js";
import { ENTITY_TYPES, RELATION_TYPES, TABLES } from "../schema/constants.js";

const MAX_TRAVERSAL_DEPTH = 4;
const DEFAULT_TRAVERSAL_DEPTH = 2;
const MAX_TRAVERSAL_NODES = 100;
const MAX_TRAVERSAL_RELATIONS = 300;

export type GraphDirection = "in" | "out" | "both";

export interface EntityUpsertInput {
  userId: string;
  type: EntityType;
  name: string;
  key?: string;
  slug?: string;
  aliases?: string[];
  metadata?: JsonObject;
  confidence?: number;
  firstSeenAt?: string;
  lastSeenAt?: string;
  evidence?: Evidence;
}

export interface EntityRecord {
  id: string;
  user_id: string;
  entity_type: EntityType;
  canonical_key: string;
  slug: string | null;
  name: string;
  summary: string;
  metadata: JsonObject;
  confidence: number;
  first_seen_at: string | null;
  last_seen_at: string | null;
  content_hash: string | null;
  created_at: string;
  updated_at: string;
}

export interface EntityLinkInput {
  userId: string;
  sourceEntityId: string;
  targetEntityId: string;
  relationType: RelationType;
  evidence: Evidence;
  confidence?: number;
  metadata?: JsonObject;
}

export interface GraphExtractionAdapter {
  extract(input: {
    source: "recent_context" | "brain_page";
    source_id: string;
    text: string;
    metadata: JsonObject;
  }): Promise<{
    entities?: EntityUpsertInput[];
    relations?: EntityLinkInput[];
  }>;
}

export interface GraphExtractionOptions {
  enableLlmExtraction?: boolean;
  llmExtractor?: GraphExtractionAdapter;
  now?: string;
}

export interface GraphQueryInput {
  userId: string;
  start: string;
  relationTypes?: RelationType[];
  depth?: number;
  direction?: GraphDirection;
  limit?: number;
  now?: string;
}

interface RecentContextGraphRow {
  id: string;
  user_id: string;
  source: string;
  app_name: string | null;
  url: string | null;
  domain: string | null;
  repo_path: string | null;
  file_path: string | null;
  screen_summary: string | null;
  activities: unknown;
  user_intent: string | null;
  metadata: unknown;
  content_hash: string | null;
  created_at: string | Date;
}

interface BrainPageGraphRow {
  id: string;
  user_id: string;
  slug: string;
  page_type: string;
  title: string;
  frontmatter: unknown;
  compiled_truth: string;
  timeline_text: string;
  content_hash: string;
  source_hash: string;
  updated_at: string | Date;
  created_at: string | Date;
}

interface EntityRow {
  id: string;
  user_id: string;
  entity_type: string;
  canonical_key: string;
  slug: string | null;
  name: string;
  summary: string | null;
  metadata: unknown;
  confidence: number;
  first_seen_at: string | Date | null;
  last_seen_at: string | Date | null;
  content_hash: string | null;
  created_at: string | Date;
  updated_at: string | Date;
}

interface LinkRow {
  id: string;
  user_id: string;
  source_entity_id: string;
  target_entity_id: string;
  relation_type: string;
  confidence: number;
  evidence: unknown;
  evidence_source_type: string | null;
  evidence_source_id: string | null;
  metadata: unknown;
  source_hash: string | null;
  created_at: string | Date;
  updated_at: string | Date;
}

interface BrainLinkedEntitySpec extends EntityUpsertInput {
  sourceField: string;
}

export function normalizeAlias(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) {
    return "";
  }

  const domain = domainFromUrl(trimmed);
  if (domain) {
    return domain;
  }

  if (looksLikePath(trimmed)) {
    return normalizeFilePath(trimmed).toLowerCase();
  }

  return trimmed
    .toLowerCase()
    .replace(/^www\./, "")
    .replace(/[_\s]+/g, "-")
    .replace(/[^a-z0-9./:-]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/(^-|-$)/g, "");
}

export function canonicalEntityKey(type: EntityType, rawValue: string): string {
  const value = rawValue.trim();
  if (!value) {
    throw new Error("canonical entity value is required");
  }

  switch (type) {
    case "website":
      return domainFromUrl(value) ?? normalizeAlias(value);
    case "file":
      return normalizeFilePath(value).toLowerCase();
    case "repo":
      return normalizeRepoKey(value);
    case "user":
      return normalizeAlias(value) || value.toLowerCase();
    default:
      return normalizeSlug(value);
  }
}

export function entityId(userId: string, type: EntityType, canonicalKey: string): string {
  return `ent_${sha256Hex(`${userId}:${type}:${canonicalKey}`).slice(0, 24)}`;
}

export function entityLinkId(input: {
  userId: string;
  sourceEntityId: string;
  targetEntityId: string;
  relationType: RelationType;
  evidenceSource: string;
  evidenceSourceId: string;
}): string {
  return `link_${sha256Hex(
    [
      input.userId,
      input.sourceEntityId,
      input.targetEntityId,
      input.relationType,
      input.evidenceSource,
      input.evidenceSourceId,
    ].join(":"),
  ).slice(0, 24)}`;
}

export async function upsertEntity(
  database: MemoryPgliteDatabase,
  input: EntityUpsertInput,
): Promise<EntityRecord> {
  assertEntityType(input.type);
  const canonicalKey = canonicalEntityKey(input.type, input.key ?? input.slug ?? input.name);
  const id = entityId(input.userId, input.type, canonicalKey);
  const now = input.lastSeenAt ?? input.evidence?.created_at ?? new Date().toISOString();
  const firstSeenAt = input.firstSeenAt ?? now;
  const metadata = {
    ...(input.metadata ?? {}),
    generated_by: "graph_deterministic_extractor",
  } satisfies JsonObject;
  const rowHash = contentHash(
    stableJson({
      user_id: input.userId,
      type: input.type,
      canonical_key: canonicalKey,
      slug: input.slug ?? null,
      name: input.name,
      metadata,
    }),
  );

  const result = await database.query<EntityRow>(
    `
      INSERT INTO ${TABLES.entities} (
        id,
        user_id,
        entity_type,
        canonical_key,
        slug,
        name,
        metadata,
        confidence,
        first_seen_at,
        last_seen_at,
        content_hash
      ) VALUES (
        $1,
        $2,
        $3,
        $4,
        $5,
        $6,
        $7::jsonb,
        $8,
        $9::timestamptz,
        $10::timestamptz,
        $11
      )
      ON CONFLICT (user_id, entity_type, canonical_key) DO UPDATE SET
        slug = COALESCE(EXCLUDED.slug, ${TABLES.entities}.slug),
        name = CASE
          WHEN ${TABLES.entities}.name = ${TABLES.entities}.canonical_key THEN EXCLUDED.name
          ELSE ${TABLES.entities}.name
        END,
        metadata = ${TABLES.entities}.metadata || EXCLUDED.metadata,
        confidence = GREATEST(${TABLES.entities}.confidence, EXCLUDED.confidence),
        first_seen_at = LEAST(
          COALESCE(${TABLES.entities}.first_seen_at, EXCLUDED.first_seen_at),
          EXCLUDED.first_seen_at
        ),
        last_seen_at = GREATEST(
          COALESCE(${TABLES.entities}.last_seen_at, EXCLUDED.last_seen_at),
          EXCLUDED.last_seen_at
        ),
        content_hash = EXCLUDED.content_hash,
        updated_at = NOW()
      RETURNING *
    `,
    [
      id,
      input.userId,
      input.type,
      canonicalKey,
      input.slug ?? null,
      input.name.trim(),
      stableJson(metadata),
      input.confidence ?? confidenceForEvidence(input.evidence),
      firstSeenAt,
      now,
      rowHash,
    ],
  );

  const row = result.rows[0];
  if (!row) {
    throw new Error(`Failed to upsert entity ${input.type}:${canonicalKey}`);
  }

  const aliases = uniqueStrings([
    input.name,
    input.slug,
    canonicalKey,
    ...(input.aliases ?? []),
  ]);
  for (const alias of aliases) {
    const aliasInput: {
      userId: string;
      entityId: string;
      alias: string;
      sourceType: string;
      sourceId?: string;
      metadata?: JsonObject;
    } = {
      userId: input.userId,
      entityId: row.id,
      alias,
      sourceType: input.evidence?.source ?? "graph",
      metadata: input.evidence ? { evidence_source: input.evidence.source } : {},
    };
    if (input.evidence?.source_id) {
      aliasInput.sourceId = input.evidence.source_id;
    }
    await upsertAlias(database, aliasInput);
  }

  return rowToEntityRecord(row);
}

export async function upsertAlias(
  database: MemoryPgliteDatabase,
  input: {
    userId: string;
    entityId: string;
    alias: string;
    sourceType: string;
    sourceId?: string;
    metadata?: JsonObject;
  },
): Promise<void> {
  const alias = input.alias.trim();
  const normalized = normalizeAlias(alias);
  if (!alias || !normalized) {
    return;
  }

  const id = `alias_${sha256Hex(`${input.userId}:${input.entityId}:${normalized}`).slice(0, 24)}`;
  await database.query(
    `
      INSERT INTO ${TABLES.entityAliases} (
        id,
        user_id,
        entity_id,
        alias,
        normalized_alias,
        source_type,
        source_id,
        metadata
      ) VALUES (
        $1,
        $2,
        $3,
        $4,
        $5,
        $6,
        $7,
        $8::jsonb
      )
      ON CONFLICT (user_id, normalized_alias, entity_id) DO UPDATE SET
        alias = EXCLUDED.alias,
        source_type = EXCLUDED.source_type,
        source_id = COALESCE(EXCLUDED.source_id, ${TABLES.entityAliases}.source_id),
        metadata = ${TABLES.entityAliases}.metadata || EXCLUDED.metadata,
        updated_at = NOW()
    `,
    [
      id,
      input.userId,
      input.entityId,
      alias,
      normalized,
      input.sourceType,
      input.sourceId ?? null,
      stableJson(input.metadata ?? {}),
    ],
  );
}

export async function upsertEntityLink(
  database: MemoryPgliteDatabase,
  input: EntityLinkInput,
): Promise<RelationRef> {
  assertRelationType(input.relationType);
  if (!input.evidence.source_id) {
    throw new Error("entity link evidence.source_id is required");
  }

  const sourceHash = contentHash(
    stableJson({
      user_id: input.userId,
      source_entity_id: input.sourceEntityId,
      target_entity_id: input.targetEntityId,
      relation_type: input.relationType,
      evidence: input.evidence,
    }),
  );
  const id = entityLinkId({
    userId: input.userId,
    sourceEntityId: input.sourceEntityId,
    targetEntityId: input.targetEntityId,
    relationType: input.relationType,
    evidenceSource: input.evidence.source,
    evidenceSourceId: input.evidence.source_id,
  });
  const confidence = input.confidence ?? confidenceForEvidence(input.evidence);

  const result = await database.query<LinkRow>(
    `
      INSERT INTO ${TABLES.entityLinks} (
        id,
        user_id,
        source_entity_id,
        target_entity_id,
        relation_type,
        confidence,
        evidence,
        evidence_source_type,
        evidence_source_id,
        metadata,
        source_hash
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
        $10::jsonb,
        $11
      )
      ON CONFLICT (
        user_id,
        source_entity_id,
        target_entity_id,
        relation_type,
        evidence_source_type,
        evidence_source_id
      ) DO UPDATE SET
        confidence = GREATEST(${TABLES.entityLinks}.confidence, EXCLUDED.confidence),
        evidence = EXCLUDED.evidence,
        metadata = ${TABLES.entityLinks}.metadata || EXCLUDED.metadata,
        source_hash = EXCLUDED.source_hash,
        updated_at = NOW()
      RETURNING *
    `,
    [
      id,
      input.userId,
      input.sourceEntityId,
      input.targetEntityId,
      input.relationType,
      confidence,
      stableJson([input.evidence]),
      input.evidence.source,
      input.evidence.source_id,
      stableJson(input.metadata ?? {}),
      sourceHash,
    ],
  );

  const row = result.rows[0];
  if (!row) {
    throw new Error(`Failed to upsert relation ${input.relationType}`);
  }
  return linkRowToRelationRef(row);
}

export async function extractGraphForRecentContextEvent(
  database: MemoryPgliteDatabase,
  eventId: string,
  options: GraphExtractionOptions = {},
): Promise<{ entities: EntityRecord[]; relations: RelationRef[] }> {
  const result = await database.query<RecentContextGraphRow>(
    `SELECT * FROM ${TABLES.recentContextEvents} WHERE id = $1 LIMIT 1`,
    [eventId],
  );
  const event = result.rows[0];
  if (!event) {
    throw new Error(`Recent context event not found: ${eventId}`);
  }

  const evidence = evidenceForRecentEvent(event, options.now);
  const metadata = jsonObject(event.metadata);
  const user = await upsertEntity(database, {
    userId: event.user_id,
    type: "user",
    key: event.user_id,
    name: event.user_id,
    aliases: [event.user_id],
    metadata: { source: "recent_context_actor" },
    evidence,
  });

  const entities = new Map<string, EntityRecord>([[user.id, user]]);
  const relations: RelationRef[] = [];

  const projects = stringList(metadata.projects);
  const app = event.app_name
    ? await addEntity(database, entities, {
        userId: event.user_id,
        type: "app",
        name: event.app_name,
        aliases: [event.app_name],
        metadata: { app_name: event.app_name },
        evidence,
      })
    : null;
  const websiteDomain = event.domain ?? domainFromUrl(typeof metadata.url === "string" ? metadata.url : event.url ?? "");
  const website = websiteDomain
    ? await addEntity(database, entities, {
        userId: event.user_id,
        type: "website",
        key: websiteDomain,
        slug: `websites/${slugSegment(websiteDomain)}`,
        name: websiteDomain,
        aliases: uniqueStrings([websiteDomain, event.url ?? undefined, stringValue(metadata.url)]),
        metadata: { domain: websiteDomain, url: event.url ?? stringValue(metadata.url) ?? "" },
        evidence,
      })
    : null;
  const repo = event.repo_path
    ? await addEntity(database, entities, {
        userId: event.user_id,
        type: "repo",
        key: event.repo_path,
        slug: `repos/${slugSegment(repoNameFromPath(event.repo_path))}`,
        name: repoNameFromPath(event.repo_path),
        aliases: [event.repo_path, repoNameFromPath(event.repo_path)],
        metadata: { path: event.repo_path },
        evidence,
      })
    : null;
  const file = event.file_path
    ? await addEntity(database, entities, {
        userId: event.user_id,
        type: "file",
        key: event.file_path,
        slug: `files/${slugSegment(fileNameFromPath(event.file_path))}`,
        name: fileNameFromPath(event.file_path),
        aliases: [event.file_path, fileNameFromPath(event.file_path)],
        metadata: { path: event.file_path },
        evidence,
      })
    : null;

  for (const projectName of projects) {
    await addEntity(database, entities, {
      userId: event.user_id,
      type: "project",
      name: projectName,
      slug: `projects/${slugSegment(projectName)}`,
      aliases: [projectName],
      metadata: { source_field: "metadata.projects" },
      evidence,
    });
  }

  if (app) {
    relations.push(
      await upsertEntityLink(database, {
        userId: event.user_id,
        sourceEntityId: user.id,
        targetEntityId: app.id,
        relationType: "uses",
        evidence,
        confidence: 0.86,
      }),
    );
  }
  if (website) {
    relations.push(
      await upsertEntityLink(database, {
        userId: event.user_id,
        sourceEntityId: user.id,
        targetEntityId: website.id,
        relationType: "visited",
        evidence,
        confidence: 0.9,
      }),
    );
  }
  if (repo) {
    relations.push(
      await upsertEntityLink(database, {
        userId: event.user_id,
        sourceEntityId: user.id,
        targetEntityId: repo.id,
        relationType: "works_on",
        evidence,
        confidence: 0.82,
      }),
    );
  }
  if (file) {
    relations.push(
      await upsertEntityLink(database, {
        userId: event.user_id,
        sourceEntityId: user.id,
        targetEntityId: file.id,
        relationType: isEditEvent(event, metadata) ? "edited" : "opened",
        evidence,
        confidence: isEditEvent(event, metadata) ? 0.9 : 0.84,
      }),
    );
  }

  const projectEntities = [...entities.values()].filter((entity) => entity.entity_type === "project");
  for (const project of projectEntities) {
    for (const target of [app, website, repo, file].filter(isEntityRecord)) {
      relations.push(
        await upsertEntityLink(database, {
          userId: event.user_id,
          sourceEntityId: project.id,
          targetEntityId: target.id,
          relationType: target.entity_type === "file" ? "related_to" : "uses",
          evidence,
          confidence: 0.74,
        }),
      );
    }
  }

  if (options.enableLlmExtraction && options.llmExtractor) {
    await applyLlmExtraction(database, options.llmExtractor, {
      source: "recent_context",
      source_id: event.id,
      text: event.screen_summary ?? "",
      metadata,
    });
  }

  return {
    entities: [...entities.values()],
    relations: uniqueRelations(relations),
  };
}

export async function extractGraphForBrainPage(
  database: MemoryPgliteDatabase,
  pageId: string,
  options: GraphExtractionOptions = {},
): Promise<{ entities: EntityRecord[]; relations: RelationRef[] }> {
  const result = await database.query<BrainPageGraphRow>(
    `SELECT * FROM ${TABLES.brainPages} WHERE id = $1 LIMIT 1`,
    [pageId],
  );
  const page = result.rows[0];
  if (!page) {
    throw new Error(`Brain page not found: ${pageId}`);
  }

  const pageType = assertEntityType(page.page_type);
  const evidence = evidenceForBrainPage(page, options.now);
  const frontmatter = jsonObject(page.frontmatter);
  const pageEntity = await upsertEntity(database, {
    userId: page.user_id,
    type: pageType,
    key: page.slug,
    slug: page.slug,
    name: page.title,
    aliases: uniqueStrings([
      page.title,
      page.slug,
      page.slug.split("/").at(-1),
      ...stringList(frontmatter.aliases),
      ...stringList(frontmatter.tags),
    ]),
    metadata: {
      slug: page.slug,
      page_id: page.id,
      frontmatter,
    },
    evidence,
    confidence: 0.96,
  });

  const entities = new Map<string, EntityRecord>([[pageEntity.id, pageEntity]]);
  const relations: RelationRef[] = [];
  const linkedSpecs = linkedEntitiesFromBrainPage(page);

  for (const spec of linkedSpecs) {
    const targetInput: EntityUpsertInput = {
      userId: page.user_id,
      type: spec.type,
      key: spec.key ?? spec.slug ?? spec.name,
      name: spec.name,
      evidence,
    };
    if (spec.slug) {
      targetInput.slug = spec.slug;
    }
    if (spec.aliases) {
      targetInput.aliases = spec.aliases;
    }
    if (spec.metadata) {
      targetInput.metadata = spec.metadata;
    }
    if (spec.confidence !== undefined) {
      targetInput.confidence = spec.confidence;
    }
    const target = await addEntity(database, entities, targetInput);

    const relationType = relationTypeForBrainLink(pageType, spec.type, spec.sourceField);
    relations.push(
      await upsertEntityLink(database, {
        userId: page.user_id,
        sourceEntityId: relationType === "mentioned_in" ? target.id : pageEntity.id,
        targetEntityId: relationType === "mentioned_in" ? pageEntity.id : target.id,
        relationType,
        evidence,
        confidence: confidenceForBrainRelation(pageType, spec.type, spec.sourceField),
        metadata: {
          source_field: spec.sourceField,
          page_slug: page.slug,
        },
      }),
    );
  }

  if (pageType === "decision" || pageType === "preference") {
    for (const target of [...entities.values()].filter((entity) => entity.id !== pageEntity.id)) {
      relations.push(
        await upsertEntityLink(database, {
          userId: page.user_id,
          sourceEntityId: pageEntity.id,
          targetEntityId: target.id,
          relationType: "evidence_for",
          evidence,
          confidence: 0.72,
          metadata: { page_slug: page.slug },
        }),
      );
    }
  }

  if (options.enableLlmExtraction && options.llmExtractor) {
    await applyLlmExtraction(database, options.llmExtractor, {
      source: "brain_page",
      source_id: page.id,
      text: `${page.title}\n${page.compiled_truth}\n${page.timeline_text}`,
      metadata: {
        slug: page.slug,
        type: pageType,
        frontmatter,
      },
    });
  }

  return {
    entities: [...entities.values()],
    relations: uniqueRelations(relations),
  };
}

export async function backfillGraph(
  database: MemoryPgliteDatabase,
  options: { userId: string; limit?: number } & GraphExtractionOptions,
): Promise<{ recent_context: number; brain_pages: number; relations: number }> {
  const limit = positiveLimit(options.limit, 500);
  const events = await database.query<{ id: string }>(
    `
      SELECT id
      FROM ${TABLES.recentContextEvents}
      WHERE user_id = $1
      ORDER BY created_at DESC
      LIMIT $2
    `,
    [options.userId, limit],
  );
  const pages = await database.query<{ id: string }>(
    `
      SELECT id
      FROM ${TABLES.brainPages}
      WHERE user_id = $1
      ORDER BY updated_at DESC
      LIMIT $2
    `,
    [options.userId, limit],
  );

  let relationCount = 0;
  for (const row of events.rows) {
    const result = await extractGraphForRecentContextEvent(database, row.id, options);
    relationCount += result.relations.length;
  }
  for (const row of pages.rows) {
    const result = await extractGraphForBrainPage(database, row.id, options);
    relationCount += result.relations.length;
  }

  return {
    recent_context: events.rows.length,
    brain_pages: pages.rows.length,
    relations: relationCount,
  };
}

export async function lookupEntitiesFromQuery(
  database: MemoryPgliteDatabase,
  input: { userId: string; query: string; limit?: number },
): Promise<EntityRecord[]> {
  const normalizedQuery = normalizeFreeText(input.query);
  const candidates = queryAliasCandidates(input.query);
  const limit = positiveLimit(input.limit, 10);

  const result = await database.query<EntityRow>(
    `
      WITH alias_matches AS (
        SELECT DISTINCT e.*
        FROM ${TABLES.entities} e
        JOIN ${TABLES.entityAliases} a ON a.entity_id = e.id
        WHERE e.user_id = $1
          AND (
            a.normalized_alias = ANY($2::text[])
            OR (
              length(a.normalized_alias) >= 3
              AND $3 LIKE '%' || a.normalized_alias || '%'
            )
            OR EXISTS (
              SELECT 1
              FROM unnest($2::text[]) AS candidate
              WHERE length(candidate) >= 4
                AND a.normalized_alias LIKE '%' || candidate || '%'
            )
          )
      ),
      entity_matches AS (
        SELECT *
        FROM ${TABLES.entities}
        WHERE user_id = $1
          AND (
            canonical_key = ANY($2::text[])
            OR slug = ANY($2::text[])
            OR (
              length(canonical_key) >= 3
              AND $3 LIKE '%' || canonical_key || '%'
            )
            OR EXISTS (
              SELECT 1
              FROM unnest($2::text[]) AS candidate
              WHERE length(candidate) >= 4
                AND (
                  canonical_key LIKE '%' || candidate || '%'
                  OR COALESCE(slug, '') LIKE '%' || candidate || '%'
                  OR replace(lower(name), ' ', '-') LIKE '%' || candidate || '%'
                )
            )
            OR (
              length(lower(name)) >= 3
              AND $3 LIKE '%' || lower(name) || '%'
            )
          )
      )
      SELECT *
      FROM (
        SELECT * FROM alias_matches
        UNION
        SELECT * FROM entity_matches
      ) matches
      ORDER BY confidence DESC, updated_at DESC
      LIMIT $4
    `,
    [input.userId, candidates, normalizedQuery, limit],
  );

  return result.rows.map(rowToEntityRecord);
}

export async function graphQuery(
  database: MemoryPgliteDatabase,
  input: GraphQueryInput,
): Promise<GraphQueryResponse> {
  const depth = boundedDepth(input.depth);
  const direction = input.direction ?? "both";
  const startEntity = await resolveStartEntity(database, input.userId, input.start);
  if (!startEntity) {
    return {
      schema_version: "memory-v2",
      start: input.start,
      nodes: [],
      relations: [],
      depth,
      direction,
      generated_at: input.now ?? new Date().toISOString(),
    };
  }

  const relationTypes = input.relationTypes?.map(assertRelationType);
  const nodeLimit = positiveLimit(input.limit, MAX_TRAVERSAL_NODES);
  const visited = new Set<string>([startEntity.id]);
  const nodeIds = new Set<string>([startEntity.id]);
  const relationMap = new Map<string, RelationRef>();
  let frontier = [startEntity.id];

  for (let currentDepth = 0; currentDepth < depth && frontier.length > 0; currentDepth += 1) {
    const rows = await loadAdjacentLinks(database, {
      userId: input.userId,
      frontier,
      direction,
      relationTypes,
      limit: MAX_TRAVERSAL_RELATIONS,
    });
    const nextFrontier: string[] = [];

    for (const row of rows) {
      const relation = linkRowToRelationRef(row);
      relationMap.set(relation.id, relation);
      for (const candidate of [relation.source_entity_id, relation.target_entity_id]) {
        nodeIds.add(candidate);
        if (!visited.has(candidate) && nextFrontier.length + visited.size < nodeLimit) {
          visited.add(candidate);
          nextFrontier.push(candidate);
        }
      }
      if (relationMap.size >= MAX_TRAVERSAL_RELATIONS || nodeIds.size >= nodeLimit) {
        break;
      }
    }

    frontier = nextFrontier;
  }

  const nodes = await loadGraphNodes(database, input.userId, [...nodeIds]);
  return {
    schema_version: "memory-v2",
    start: startEntity.id,
    nodes,
    relations: [...relationMap.values()],
    depth,
    direction,
    generated_at: input.now ?? new Date().toISOString(),
  };
}

export async function loadRelationsForEntities(
  database: MemoryPgliteDatabase,
  userId: string,
  entityIds: string[],
  limit = 50,
): Promise<RelationRef[]> {
  const ids = uniqueStrings(entityIds);
  if (ids.length === 0) {
    return [];
  }

  const result = await database.query<LinkRow>(
    `
      SELECT *
      FROM ${TABLES.entityLinks}
      WHERE user_id = $1
        AND (
          source_entity_id = ANY($2::text[])
          OR target_entity_id = ANY($2::text[])
        )
      ORDER BY confidence DESC, updated_at DESC
      LIMIT $3
    `,
    [userId, ids, positiveLimit(limit, 50)],
  );

  return result.rows.map(linkRowToRelationRef);
}

async function addEntity(
  database: MemoryPgliteDatabase,
  entities: Map<string, EntityRecord>,
  input: EntityUpsertInput,
): Promise<EntityRecord> {
  const entity = await upsertEntity(database, input);
  entities.set(entity.id, entity);
  return entity;
}

async function applyLlmExtraction(
  database: MemoryPgliteDatabase,
  extractor: GraphExtractionAdapter,
  input: Parameters<GraphExtractionAdapter["extract"]>[0],
): Promise<void> {
  const extracted = await extractor.extract(input);
  for (const entity of extracted.entities ?? []) {
    await upsertEntity(database, entity);
  }
  for (const relation of extracted.relations ?? []) {
    await upsertEntityLink(database, relation);
  }
}

function evidenceForRecentEvent(row: RecentContextGraphRow, now: string | undefined): Evidence {
  const createdAt = toIso(row.created_at);
  return {
    source: "recent_context",
    source_id: row.id,
    excerpt: excerpt(row.screen_summary ?? row.user_intent ?? ""),
    content_hash: row.content_hash ?? contentHash(row.screen_summary ?? ""),
    created_at: now ?? createdAt,
    metadata: {
      source: row.source,
      created_at: createdAt,
    },
  };
}

function evidenceForBrainPage(row: BrainPageGraphRow, now: string | undefined): Evidence {
  return {
    source: "brain_page",
    source_id: row.id,
    excerpt: excerpt(row.compiled_truth || row.timeline_text || row.title),
    content_hash: row.source_hash || row.content_hash,
    created_at: now ?? toIso(row.updated_at),
    metadata: {
      slug: row.slug,
      page_type: row.page_type,
    },
  };
}

function linkedEntitiesFromBrainPage(row: BrainPageGraphRow): BrainLinkedEntitySpec[] {
  const pageType = assertEntityType(row.page_type);
  const frontmatter = jsonObject(row.frontmatter);
  const specs: BrainLinkedEntitySpec[] = [];

  for (const [field, type] of [
    ["projects", "project"],
    ["apps", "app"],
    ["websites", "website"],
    ["repos", "repo"],
    ["files", "file"],
    ["people", "person"],
    ["companies", "company"],
    ["workflows", "workflow"],
    ["decisions", "decision"],
    ["preferences", "preference"],
    ["concepts", "concept"],
  ] as const) {
    for (const value of stringList(frontmatter[field])) {
      specs.push(entitySpecFromValue(row.user_id, type, value, `frontmatter.${field}`));
    }
  }

  for (const value of stringList(frontmatter.uses)) {
    specs.push(entitySpecFromValue(row.user_id, inferTypeFromValue(value), value, "frontmatter.uses"));
  }

  for (const slug of extractSlugLinks(`${row.compiled_truth}\n${row.timeline_text}`)) {
    specs.push(entitySpecFromSlug(row.user_id, slug, "markdown_link"));
  }

  if (pageType === "repo") {
    for (const project of stringList(frontmatter.projects)) {
      specs.push(entitySpecFromValue(row.user_id, "project", project, "frontmatter.projects"));
    }
  }

  return dedupeEntitySpecs(specs);
}

function entitySpecFromSlug(userId: string, slug: string, sourceField: string): BrainLinkedEntitySpec {
  const type = typeFromSlug(slug);
  return {
    userId,
    type,
    key: slug,
    slug,
    name: titleFromSlug(slug),
    aliases: [slug, titleFromSlug(slug), slug.split("/").at(-1) ?? slug],
    metadata: {
      slug,
      source_field: sourceField,
    },
    confidence: 0.82,
    sourceField,
  };
}

function entitySpecFromValue(
  userId: string,
  type: EntityType,
  value: string,
  sourceField: string,
): BrainLinkedEntitySpec {
  const name = type === "repo" ? repoNameFromPath(value) : type === "file" ? fileNameFromPath(value) : value;
  const slug =
    type === "website"
      ? `websites/${slugSegment(domainFromUrl(value) ?? value)}`
      : type === "repo"
        ? `repos/${slugSegment(repoNameFromPath(value))}`
        : type === "file"
          ? `files/${slugSegment(fileNameFromPath(value))}`
          : `${collectionForType(type)}/${slugSegment(value)}`;
  return {
    userId,
    type,
    key: value,
    slug,
    name,
    aliases: uniqueStrings([value, name, domainFromUrl(value)]),
    metadata: {
      source_field: sourceField,
      ...(type === "website" ? { domain: domainFromUrl(value) ?? normalizeAlias(value) } : {}),
      ...(type === "repo" || type === "file" ? { path: value } : {}),
    },
    confidence: 0.84,
    sourceField,
  };
}

function relationTypeForBrainLink(
  pageType: EntityType,
  targetType: EntityType,
  sourceField: JsonValue | undefined,
): RelationType {
  const field = typeof sourceField === "string" ? sourceField : "";
  if (pageType === "project" && ["repo", "app", "website"].includes(targetType)) {
    return "uses";
  }
  if (pageType === "repo" && targetType === "project") {
    return "belongs_to";
  }
  if (pageType === "workflow" && ["app", "website", "repo", "file"].includes(targetType)) {
    return "uses";
  }
  if (pageType === "decision" && targetType === "project") {
    return "decided_in";
  }
  if (pageType === "preference") {
    return "prefers";
  }
  if (field === "markdown_link") {
    return "mentioned_in";
  }
  return "related_to";
}

function confidenceForBrainRelation(
  pageType: EntityType,
  targetType: EntityType,
  sourceField: JsonValue | undefined,
): number {
  if (typeof sourceField === "string" && sourceField.startsWith("frontmatter.")) {
    return 0.9;
  }
  if (pageType === "project" && ["repo", "app", "website"].includes(targetType)) {
    return 0.88;
  }
  return 0.72;
}

async function resolveStartEntity(
  database: MemoryPgliteDatabase,
  userId: string,
  start: string,
): Promise<EntityRecord | null> {
  const byId = await database.query<EntityRow>(
    `SELECT * FROM ${TABLES.entities} WHERE user_id = $1 AND id = $2 LIMIT 1`,
    [userId, start],
  );
  if (byId.rows[0]) {
    return rowToEntityRecord(byId.rows[0]);
  }

  const matches = await lookupEntitiesFromQuery(database, { userId, query: start, limit: 1 });
  return matches[0] ?? null;
}

async function loadAdjacentLinks(
  database: MemoryPgliteDatabase,
  input: {
    userId: string;
    frontier: string[];
    direction: GraphDirection;
    relationTypes: RelationType[] | undefined;
    limit: number;
  },
): Promise<LinkRow[]> {
  const conditions = ["user_id = $1"];
  const params: unknown[] = [input.userId, input.frontier];
  if (input.direction === "out") {
    conditions.push("source_entity_id = ANY($2::text[])");
  } else if (input.direction === "in") {
    conditions.push("target_entity_id = ANY($2::text[])");
  } else {
    conditions.push("(source_entity_id = ANY($2::text[]) OR target_entity_id = ANY($2::text[]))");
  }

  if (input.relationTypes && input.relationTypes.length > 0) {
    params.push(input.relationTypes);
    conditions.push(`relation_type = ANY($${params.length}::text[])`);
  }

  params.push(input.limit);
  const result = await database.query<LinkRow>(
    `
      SELECT *
      FROM ${TABLES.entityLinks}
      WHERE ${conditions.join(" AND ")}
      ORDER BY confidence DESC, updated_at DESC
      LIMIT $${params.length}
    `,
    params,
  );
  return result.rows;
}

async function loadGraphNodes(
  database: MemoryPgliteDatabase,
  userId: string,
  entityIds: string[],
): Promise<GraphNode[]> {
  if (entityIds.length === 0) {
    return [];
  }

  const rows = await database.query<EntityRow>(
    `
      SELECT *
      FROM ${TABLES.entities}
      WHERE user_id = $1
        AND id = ANY($2::text[])
    `,
    [userId, entityIds],
  );
  const aliases = await database.query<{ entity_id: string; alias: string }>(
    `
      SELECT entity_id, alias
      FROM ${TABLES.entityAliases}
      WHERE user_id = $1
        AND entity_id = ANY($2::text[])
      ORDER BY alias ASC
    `,
    [userId, entityIds],
  );
  const aliasMap = new Map<string, string[]>();
  for (const alias of aliases.rows) {
    aliasMap.set(alias.entity_id, [...(aliasMap.get(alias.entity_id) ?? []), alias.alias]);
  }

  return rows.rows
    .map((row) => rowToEntityRecord(row))
    .map((entity) => ({
      id: entity.id,
      type: entity.entity_type,
      name: entity.name,
      aliases: uniqueStrings(aliasMap.get(entity.id) ?? []),
      metadata: {
        ...entity.metadata,
        canonical_key: entity.canonical_key,
        slug: entity.slug ?? "",
      },
    }));
}

function rowToEntityRecord(row: EntityRow): EntityRecord {
  return {
    id: row.id,
    user_id: row.user_id,
    entity_type: assertEntityType(row.entity_type),
    canonical_key: row.canonical_key,
    slug: row.slug,
    name: row.name,
    summary: row.summary ?? "",
    metadata: jsonObject(row.metadata),
    confidence: row.confidence,
    first_seen_at: row.first_seen_at ? toIso(row.first_seen_at) : null,
    last_seen_at: row.last_seen_at ? toIso(row.last_seen_at) : null,
    content_hash: row.content_hash,
    created_at: toIso(row.created_at),
    updated_at: toIso(row.updated_at),
  };
}

function linkRowToRelationRef(row: LinkRow): RelationRef {
  return {
    id: row.id,
    relation_type: assertRelationType(row.relation_type),
    source_entity_id: row.source_entity_id,
    target_entity_id: row.target_entity_id,
    confidence: Number(row.confidence),
    evidence: evidenceArray(row.evidence),
  };
}

function evidenceArray(value: unknown): Evidence[] {
  const parsed = parseJson(value);
  if (!Array.isArray(parsed)) {
    return [];
  }
  return parsed
    .filter((entry): entry is Record<string, unknown> => Boolean(entry) && typeof entry === "object")
    .map((entry) => {
      const source = typeof entry.source === "string" ? entry.source : "graph";
      const sourceId = typeof entry.source_id === "string" ? entry.source_id : "";
      const evidence: Evidence = {
        source: source as Evidence["source"],
        source_id: sourceId,
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

function confidenceForEvidence(evidence: Evidence | undefined): number {
  if (!evidence) {
    return 0.5;
  }
  if (evidence.source === "brain_page" || evidence.source === "brain_chunk") {
    return 0.88;
  }
  if (evidence.source === "recent_context" || evidence.source === "recent_summary") {
    return 0.82;
  }
  return 0.55;
}

function queryAliasCandidates(query: string): string[] {
  const values = new Set<string>();
  const normalized = normalizeFreeText(query);
  values.add(normalizeAlias(query));
  values.add(normalized);
  values.add(normalized.replace(/\s+/g, "-"));

  const tokens = normalized.split(/[\s,?]+/).filter(Boolean);
  for (const token of tokens) {
    if (token.length >= 3) {
      values.add(token);
    }
  }
  for (let index = 0; index < tokens.length - 1; index += 1) {
    const bigram = tokens.slice(index, index + 2).join("-");
    if (bigram.length >= 4) {
      values.add(bigram);
    }
  }
  for (let index = 0; index < tokens.length - 2; index += 1) {
    const trigram = tokens.slice(index, index + 3).join("-");
    if (trigram.length >= 4) {
      values.add(trigram);
    }
  }

  for (const match of query.matchAll(/[a-zA-Z0-9_.-]+\/[a-zA-Z0-9_.-]+/g)) {
    values.add(normalizeAlias(match[0] ?? ""));
  }

  const domain = domainFromUrl(query) ?? domainFromLooseText(query);
  if (domain) {
    values.add(domain);
  }

  return [...values].filter(Boolean);
}

function extractSlugLinks(markdown: string): string[] {
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

function jsonObject(value: unknown): JsonObject {
  const parsed = parseJson(value);
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    return {};
  }
  return parsed as JsonObject;
}

function stringList(value: unknown): string[] {
  const parsed = parseJson(value);
  if (Array.isArray(parsed)) {
    return parsed
      .map((entry) => (typeof entry === "string" ? entry.trim() : ""))
      .filter((entry) => entry.length > 0);
  }
  if (typeof parsed === "string" && parsed.trim()) {
    return [parsed.trim()];
  }
  return [];
}

function stringValue(value: unknown): string | undefined {
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

function assertEntityType(value: string): EntityType {
  if (!(ENTITY_TYPES as readonly string[]).includes(value)) {
    throw new Error(`Unsupported entity type: ${value}`);
  }
  return value as EntityType;
}

function assertRelationType(value: string): RelationType {
  if (!(RELATION_TYPES as readonly string[]).includes(value)) {
    throw new Error(`Unsupported relation type: ${value}`);
  }
  return value as RelationType;
}

function typeFromSlug(slug: string): EntityType {
  if (slug === "user") {
    return "user";
  }
  if (slug === "preferences") {
    return "preference";
  }
  switch (slug.split("/")[0]) {
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
    case "preferences":
      return "preference";
    default:
      return "concept";
  }
}

function inferTypeFromValue(value: string): EntityType {
  const domain = domainFromUrl(value) ?? domainFromLooseText(value);
  if (domain) {
    return "website";
  }
  if (looksLikePath(value)) {
    return value.includes(".") ? "file" : "repo";
  }
  return "concept";
}

function collectionForType(type: EntityType): string {
  switch (type) {
    case "person":
      return "people";
    case "company":
      return "companies";
    case "preference":
      return "preferences";
    default:
      return `${type}s`;
  }
}

function normalizeSlug(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/\\/g, "/")
    .replace(/[_\s]+/g, "-")
    .replace(/[^a-z0-9./-]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/\/+/g, "/")
    .replace(/(^[/-]+|[/-]+$)/g, "");
}

function normalizeFreeText(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9./:-]+/g, " ").replace(/\s+/g, " ").trim();
}

function slugSegment(value: string): string {
  return normalizeSlug(value).split("/").filter(Boolean).join("-");
}

function titleFromSlug(slug: string): string {
  const leaf = slug.split("/").at(-1) ?? slug;
  return leaf
    .split(/[-_]/)
    .filter(Boolean)
    .map((part) => `${part.charAt(0).toUpperCase()}${part.slice(1)}`)
    .join(" ");
}

function repoNameFromPath(value: string): string {
  const trimmed = value.replace(/\/+$/g, "");
  return basename(trimmed) || trimmed;
}

function fileNameFromPath(value: string): string {
  return basename(value) || value;
}

function normalizeRepoKey(value: string): string {
  if (looksLikePath(value)) {
    return normalizeFilePath(value).toLowerCase();
  }
  return normalizeAlias(value);
}

function normalizeFilePath(value: string): string {
  const trimmed = value.trim().replace(/^file:\/\//, "");
  return normalizePath(trimmed).replace(/\\/g, "/");
}

function looksLikePath(value: string): boolean {
  return value.startsWith("/") || value.startsWith("~/") || value.includes("\\") || value.includes("/");
}

function domainFromUrl(value: string | undefined): string | undefined {
  if (!value) {
    return undefined;
  }
  try {
    return new URL(value).hostname.toLowerCase().replace(/^www\./, "");
  } catch {
    return undefined;
  }
}

function domainFromLooseText(value: string): string | undefined {
  const match = value.match(/\b(?:[a-z0-9-]+\.)+[a-z]{2,}\b/i);
  return match?.[0]?.toLowerCase().replace(/^www\./, "");
}

function isEditEvent(row: RecentContextGraphRow, metadata: JsonObject): boolean {
  const activities = stringList(row.activities).concat(stringList(metadata.activities));
  const action = `${stringValue(metadata.action) ?? ""} ${stringValue(metadata.event_type) ?? ""}`.toLowerCase();
  return /\b(edit|editing|write|writing|save|saving|modified|modify|change|changing)\b/.test(
    `${activities.join(" ")} ${action}`.toLowerCase(),
  );
}

function dedupeEntitySpecs(specs: BrainLinkedEntitySpec[]): BrainLinkedEntitySpec[] {
  const seen = new Set<string>();
  const result: BrainLinkedEntitySpec[] = [];
  for (const spec of specs) {
    const key = `${spec.type}:${canonicalEntityKey(spec.type, spec.key ?? spec.slug ?? spec.name)}`;
    if (!seen.has(key)) {
      seen.add(key);
      result.push(spec);
    }
  }
  return result;
}

function uniqueStrings(values: Array<string | undefined | null>): string[] {
  return [...new Set(values.map((value) => value?.trim() ?? "").filter(Boolean))];
}

function uniqueRelations(relations: RelationRef[]): RelationRef[] {
  const seen = new Set<string>();
  return relations.filter((relation) => {
    if (seen.has(relation.id)) {
      return false;
    }
    seen.add(relation.id);
    return true;
  });
}

function isEntityRecord(value: EntityRecord | null): value is EntityRecord {
  return value !== null;
}

function boundedDepth(value: number | undefined): number {
  if (value === undefined) {
    return DEFAULT_TRAVERSAL_DEPTH;
  }
  if (!Number.isInteger(value) || value < 0) {
    throw new Error("depth must be a non-negative integer");
  }
  return Math.min(value, MAX_TRAVERSAL_DEPTH);
}

function positiveLimit(value: number | undefined, fallback: number): number {
  if (value === undefined) {
    return fallback;
  }
  if (!Number.isInteger(value) || value <= 0) {
    throw new Error("limit must be a positive integer");
  }
  return Math.min(value, fallback);
}

function excerpt(value: string): string {
  return value.replace(/\s+/g, " ").trim().slice(0, 280);
}

function toIso(value: string | Date): string {
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}
