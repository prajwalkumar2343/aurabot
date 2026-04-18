"""
Postgres-backed structured memory store for AuraBot.

The runtime API intentionally mirrors the subset of the old mem0 API that the
HTTP handlers already use: add/get_all/search/delete.
"""

from __future__ import annotations

import json
import math
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Callable, Iterable, Optional

from sqlalchemy import create_engine, text
from sqlalchemy.exc import NoSuchModuleError, SQLAlchemyError


RRF_K = 60
DEFAULT_CANDIDATE_MULTIPLIER = 4
MIN_CANDIDATES = 20


@dataclass
class MemoryStoreInfo:
    backend: str
    vector_store: str
    database_url: str
    embedding_dimensions: int


class PostgresMemoryStore:
    """Structured memory storage backed by Postgres and pgvector."""

    def __init__(
        self,
        database_url: str,
        embedding_dimensions: int,
        embedder: Optional[Callable[[list[str]], list[list[float]]]] = None,
    ):
        self.database_url = self._normalize_database_url(database_url)
        self.embedding_dimensions = embedding_dimensions
        self.embedder = embedder

        try:
            self.engine = create_engine(
                self.database_url,
                pool_pre_ping=True,
                future=True,
            )
        except NoSuchModuleError as exc:
            raise RuntimeError(
                "Postgres driver not installed. Install `psycopg[binary]` to use the "
                "AuraBot memory store."
            ) from exc

        self._ensure_schema()

    @staticmethod
    def _normalize_database_url(database_url: str) -> str:
        normalized = (database_url or "").strip()
        if not normalized:
            raise RuntimeError(
                "DATABASE_URL is required for the Postgres memory store. "
                "Point it at a local Postgres instance or a Supabase Postgres URL."
            )

        if normalized.startswith("postgres://"):
            normalized = "postgresql://" + normalized[len("postgres://") :]

        if normalized.startswith("postgresql://") and "+psycopg" not in normalized:
            normalized = normalized.replace("postgresql://", "postgresql+psycopg://", 1)

        return normalized

    def info(self) -> MemoryStoreInfo:
        return MemoryStoreInfo(
            backend="postgresql",
            vector_store="pgvector",
            database_url=self._redact_database_url(self.database_url),
            embedding_dimensions=self.embedding_dimensions,
        )

    def get_all(self, user_id: str, agent_id: str = None, limit: int = 10):
        query = text(
            """
            SELECT
                id,
                content,
                metadata,
                created_at
            FROM observations
            WHERE user_id = :user_id
              AND (:agent_id IS NULL OR agent_id = :agent_id)
            ORDER BY created_at DESC
            LIMIT :limit
            """
        )

        with self.engine.begin() as conn:
            rows = conn.execute(
                query,
                {
                    "user_id": user_id,
                    "agent_id": agent_id,
                    "limit": max(1, int(limit)),
                },
            ).mappings()
            return [self._serialize_observation(row) for row in rows]

    def add(
        self,
        messages: list[dict[str, Any]],
        user_id: str,
        agent_id: str = None,
        metadata: dict[str, Any] = None,
        infer: bool = False,
    ):
        del infer

        content = " ".join(
            str(message.get("content", "")).strip()
            for message in (messages or [])
            if message.get("content")
        ).strip()

        if not content:
            raise ValueError("Cannot store an empty memory")

        observation_id = str(uuid.uuid4())
        chunk_id = str(uuid.uuid4())
        metadata_payload = metadata or {}
        embedding = self._embed(content)
        embedding_literal = self._vector_literal(embedding) if embedding else None

        with self.engine.begin() as conn:
            conn.execute(
                text(
                    """
                    INSERT INTO observations (
                        id,
                        user_id,
                        agent_id,
                        content,
                        metadata
                    ) VALUES (
                        CAST(:id AS uuid),
                        :user_id,
                        :agent_id,
                        :content,
                        CAST(:metadata AS jsonb)
                    )
                    """
                ),
                {
                    "id": observation_id,
                    "user_id": user_id,
                    "agent_id": agent_id,
                    "content": content,
                    "metadata": json.dumps(metadata_payload),
                },
            )

            conn.execute(
                text(
                    """
                    INSERT INTO memory_chunks (
                        id,
                        observation_id,
                        user_id,
                        agent_id,
                        chunk_type,
                        content,
                        metadata,
                        embedding
                    ) VALUES (
                        CAST(:id AS uuid),
                        CAST(:observation_id AS uuid),
                        :user_id,
                        :agent_id,
                        'summary',
                        :content,
                        CAST(:metadata AS jsonb),
                        CASE
                            WHEN :embedding IS NULL THEN NULL
                            ELSE CAST(:embedding AS vector)
                        END
                    )
                    """
                ),
                {
                    "id": chunk_id,
                    "observation_id": observation_id,
                    "user_id": user_id,
                    "agent_id": agent_id,
                    "content": content,
                    "metadata": json.dumps(metadata_payload),
                    "embedding": embedding_literal,
                },
            )

        return {
            "id": observation_id,
            "memory": content,
            "metadata": metadata_payload,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }

    def search(self, query: str, user_id: str, agent_id: str = None, limit: int = 10):
        normalized_query = (query or "").strip()
        if not normalized_query:
            return []

        candidate_limit = max(MIN_CANDIDATES, int(limit) * DEFAULT_CANDIDATE_MULTIPLIER)

        keyword_rows = self._keyword_candidates(
            normalized_query, user_id, agent_id, candidate_limit
        )
        vector_rows = self._vector_candidates(
            normalized_query, user_id, agent_id, candidate_limit
        )

        merged = self._merge_candidates(keyword_rows, vector_rows)
        return merged[: max(1, int(limit))]

    def delete(self, memory_id: str = None, id: str = None):
        target_id = memory_id or id
        if not target_id:
            raise ValueError("memory_id is required")

        with self.engine.begin() as conn:
            row = conn.execute(
                text(
                    """
                    DELETE FROM observations
                    WHERE id = CAST(:id AS uuid)
                    RETURNING id
                    """
                ),
                {"id": target_id},
            ).first()
        return {"deleted": row is not None}

    def _keyword_candidates(
        self,
        query: str,
        user_id: str,
        agent_id: Optional[str],
        candidate_limit: int,
    ) -> list[dict[str, Any]]:
        sql = text(
            """
            SELECT
                o.id AS observation_id,
                o.content,
                o.metadata,
                o.created_at,
                c.id AS chunk_id,
                ts_rank_cd(c.search_text, websearch_to_tsquery('english', :query)) AS keyword_score
            FROM memory_chunks c
            JOIN observations o ON o.id = c.observation_id
            WHERE o.user_id = :user_id
              AND (:agent_id IS NULL OR o.agent_id = :agent_id)
              AND c.search_text @@ websearch_to_tsquery('english', :query)
            ORDER BY keyword_score DESC, o.created_at DESC
            LIMIT :candidate_limit
            """
        )
        with self.engine.begin() as conn:
            rows = conn.execute(
                sql,
                {
                    "query": query,
                    "user_id": user_id,
                    "agent_id": agent_id,
                    "candidate_limit": candidate_limit,
                },
            ).mappings()
            return [dict(row) for row in rows]

    def _vector_candidates(
        self,
        query: str,
        user_id: str,
        agent_id: Optional[str],
        candidate_limit: int,
    ) -> list[dict[str, Any]]:
        embedding = self._embed(query)
        if not embedding:
            return []

        sql = text(
            """
            SELECT
                o.id AS observation_id,
                o.content,
                o.metadata,
                o.created_at,
                c.id AS chunk_id,
                (c.embedding <=> CAST(:embedding AS vector)) AS distance
            FROM memory_chunks c
            JOIN observations o ON o.id = c.observation_id
            WHERE o.user_id = :user_id
              AND (:agent_id IS NULL OR o.agent_id = :agent_id)
              AND c.embedding IS NOT NULL
            ORDER BY c.embedding <=> CAST(:embedding AS vector), o.created_at DESC
            LIMIT :candidate_limit
            """
        )
        with self.engine.begin() as conn:
            rows = conn.execute(
                sql,
                {
                    "embedding": self._vector_literal(embedding),
                    "user_id": user_id,
                    "agent_id": agent_id,
                    "candidate_limit": candidate_limit,
                },
            ).mappings()
            return [dict(row) for row in rows]

    def _merge_candidates(
        self,
        keyword_rows: Iterable[dict[str, Any]],
        vector_rows: Iterable[dict[str, Any]],
    ) -> list[dict[str, Any]]:
        merged: dict[str, dict[str, Any]] = {}

        for rank, row in enumerate(keyword_rows, start=1):
            item = merged.setdefault(row["observation_id"], self._result_payload(row))
            item["_rrf"] += 1.0 / (RRF_K + rank)
            item["_keyword_score"] = max(
                item.get("_keyword_score", 0.0),
                float(row.get("keyword_score") or 0.0),
            )

        for rank, row in enumerate(vector_rows, start=1):
            item = merged.setdefault(row["observation_id"], self._result_payload(row))
            distance = float(row.get("distance") or 1.0)
            similarity = max(0.0, 1.0 - distance)
            item["_rrf"] += 1.0 / (RRF_K + rank)
            item["_distance"] = min(item.get("_distance", math.inf), distance)
            item["_vector_similarity"] = max(
                item.get("_vector_similarity", 0.0),
                similarity,
            )

        results = []
        for item in merged.values():
            created_at = item.get("created_at")
            if isinstance(created_at, str):
                created_dt = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
            else:
                created_dt = created_at

            recency_boost = self._recency_boost(created_dt)
            final_score = (
                item.get("_rrf", 0.0)
                + 0.15 * item.get("_keyword_score", 0.0)
                + 0.35 * item.get("_vector_similarity", 0.0)
                + recency_boost
            )

            results.append(
                {
                    "id": item["id"],
                    "memory": item["memory"],
                    "metadata": item["metadata"],
                    "created_at": created_dt.isoformat(),
                    "score": round(final_score, 6),
                    "distance": (
                        round(item["_distance"], 6)
                        if "_distance" in item and item["_distance"] != math.inf
                        else 1.0
                    ),
                }
            )

        results.sort(key=lambda value: (value["score"], value["created_at"]), reverse=True)
        return results

    def _result_payload(self, row: dict[str, Any]) -> dict[str, Any]:
        created_at = row.get("created_at")
        if isinstance(created_at, str):
            created_at = datetime.fromisoformat(created_at.replace("Z", "+00:00"))

        return {
            "id": str(row["observation_id"]),
            "memory": row.get("content", ""),
            "metadata": self._normalize_metadata(row.get("metadata")),
            "created_at": created_at or datetime.now(timezone.utc),
            "_rrf": 0.0,
        }

    def _serialize_observation(self, row: Any) -> dict[str, Any]:
        created_at = row["created_at"]
        if isinstance(created_at, str):
            created_at = datetime.fromisoformat(created_at.replace("Z", "+00:00"))

        return {
            "id": str(row["id"]),
            "memory": row["content"],
            "metadata": self._normalize_metadata(row["metadata"]),
            "created_at": created_at.isoformat(),
        }

    @staticmethod
    def _normalize_metadata(value: Any) -> dict[str, Any]:
        if isinstance(value, dict):
            return value
        if isinstance(value, str):
            try:
                parsed = json.loads(value)
                return parsed if isinstance(parsed, dict) else {}
            except json.JSONDecodeError:
                return {}
        return {}

    def _embed(self, text_value: str) -> Optional[list[float]]:
        if not self.embedder:
            return None

        try:
            embeddings = self.embedder([text_value])
        except Exception as exc:
            print(f"[WARN] Memory embedding failed: {exc}")
            return None

        if not embeddings:
            return None

        vector = embeddings[0]
        if not isinstance(vector, list) or not vector:
            return None

        return [float(value) for value in vector]

    @staticmethod
    def _vector_literal(embedding: list[float]) -> str:
        return "[" + ",".join(f"{float(value):.12f}" for value in embedding) + "]"

    @staticmethod
    def _recency_boost(created_at: datetime) -> float:
        if not created_at:
            return 0.0

        age_seconds = max(
            0.0, (datetime.now(timezone.utc) - created_at.astimezone(timezone.utc)).total_seconds()
        )
        day_seconds = 86400.0
        return max(0.0, 0.05 - min(age_seconds / (30 * day_seconds), 0.05))

    @staticmethod
    def _redact_database_url(database_url: str) -> str:
        if "@" not in database_url:
            return database_url

        scheme, rest = database_url.split("://", 1)
        if "@" not in rest:
            return database_url

        credentials, host = rest.split("@", 1)
        if ":" in credentials:
            username = credentials.split(":", 1)[0]
            credentials = f"{username}:***"
        else:
            credentials = "***"
        return f"{scheme}://{credentials}@{host}"

    def _ensure_schema(self):
        statements = [
            "CREATE EXTENSION IF NOT EXISTS vector",
            "CREATE EXTENSION IF NOT EXISTS pg_trgm",
            """
            CREATE TABLE IF NOT EXISTS observations (
                id UUID PRIMARY KEY,
                user_id TEXT NOT NULL,
                agent_id TEXT,
                kind TEXT NOT NULL DEFAULT 'observation',
                content TEXT NOT NULL,
                metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                search_text TSVECTOR GENERATED ALWAYS AS (
                    setweight(to_tsvector('english', coalesce(content, '')), 'A') ||
                    setweight(to_tsvector('english', coalesce(metadata ->> 'context', '')), 'B') ||
                    setweight(to_tsvector('english', coalesce(metadata ->> 'user_intent', '')), 'C')
                ) STORED
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS memory_chunks (
                id UUID PRIMARY KEY,
                observation_id UUID NOT NULL REFERENCES observations(id) ON DELETE CASCADE,
                user_id TEXT NOT NULL,
                agent_id TEXT,
                chunk_type TEXT NOT NULL DEFAULT 'summary',
                content TEXT NOT NULL,
                metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
                embedding VECTOR(%d),
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                search_text TSVECTOR GENERATED ALWAYS AS (
                    setweight(to_tsvector('english', coalesce(content, '')), 'A')
                ) STORED
            )
            """
            % self.embedding_dimensions,
            """
            CREATE TABLE IF NOT EXISTS entities (
                id UUID PRIMARY KEY,
                user_id TEXT NOT NULL,
                entity_type TEXT NOT NULL,
                slug TEXT NOT NULL,
                name TEXT NOT NULL,
                summary TEXT NOT NULL DEFAULT '',
                metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
                confidence DOUBLE PRECISION NOT NULL DEFAULT 0.0,
                last_seen TIMESTAMPTZ,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                UNIQUE (user_id, slug)
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS entity_links (
                id UUID PRIMARY KEY,
                user_id TEXT NOT NULL,
                source_entity_id UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
                target_entity_id UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
                relation_type TEXT NOT NULL,
                weight DOUBLE PRECISION NOT NULL DEFAULT 1.0,
                metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                UNIQUE (user_id, source_entity_id, target_entity_id, relation_type)
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS workflows (
                id UUID PRIMARY KEY,
                user_id TEXT NOT NULL,
                slug TEXT NOT NULL,
                name TEXT NOT NULL,
                summary TEXT NOT NULL DEFAULT '',
                state TEXT NOT NULL DEFAULT 'active',
                frequency DOUBLE PRECISION NOT NULL DEFAULT 0.0,
                confidence DOUBLE PRECISION NOT NULL DEFAULT 0.0,
                last_seen TIMESTAMPTZ,
                metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                UNIQUE (user_id, slug)
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS workflow_evidence (
                id UUID PRIMARY KEY,
                user_id TEXT NOT NULL,
                workflow_id UUID NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
                observation_id UUID REFERENCES observations(id) ON DELETE SET NULL,
                summary TEXT NOT NULL,
                metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS profiles (
                id UUID PRIMARY KEY,
                user_id TEXT NOT NULL,
                profile_type TEXT NOT NULL,
                slug TEXT NOT NULL,
                title TEXT NOT NULL,
                compiled_truth TEXT NOT NULL DEFAULT '',
                metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
                confidence DOUBLE PRECISION NOT NULL DEFAULT 0.0,
                last_compiled_at TIMESTAMPTZ,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                UNIQUE (user_id, slug)
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS profile_evidence (
                id UUID PRIMARY KEY,
                user_id TEXT NOT NULL,
                profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
                observation_id UUID REFERENCES observations(id) ON DELETE SET NULL,
                summary TEXT NOT NULL,
                metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS memory_store_config (
                key TEXT PRIMARY KEY,
                value JSONB NOT NULL
            )
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_observations_user_agent_created
            ON observations (user_id, agent_id, created_at DESC)
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_observations_search
            ON observations USING GIN (search_text)
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_observations_metadata
            ON observations USING GIN (metadata)
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_memory_chunks_user_agent_created
            ON memory_chunks (user_id, agent_id, created_at DESC)
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_memory_chunks_search
            ON memory_chunks USING GIN (search_text)
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_memory_chunks_embedding
            ON memory_chunks USING HNSW (embedding vector_cosine_ops)
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_entities_user_type
            ON entities (user_id, entity_type, updated_at DESC)
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_workflows_user_state
            ON workflows (user_id, state, updated_at DESC)
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_profiles_user_type
            ON profiles (user_id, profile_type, updated_at DESC)
            """,
        ]

        try:
            with self.engine.begin() as conn:
                for statement in statements:
                    conn.execute(text(statement))
                self._ensure_store_config(conn)
        except SQLAlchemyError as exc:
            raise RuntimeError(f"Failed to initialize Postgres memory schema: {exc}") from exc

    def _ensure_store_config(self, conn):
        row = conn.execute(
            text(
                """
                SELECT value
                FROM memory_store_config
                WHERE key = 'embedding'
                """
            )
        ).scalar_one_or_none()

        expected = {"dimensions": self.embedding_dimensions}

        if row is None:
            conn.execute(
                text(
                    """
                    INSERT INTO memory_store_config (key, value)
                    VALUES ('embedding', CAST(:value AS jsonb))
                    """
                ),
                {"value": json.dumps(expected)},
            )
            return

        current = row if isinstance(row, dict) else json.loads(row)
        current_dimensions = int(current.get("dimensions", 0))
        if current_dimensions != self.embedding_dimensions:
            raise RuntimeError(
                "Memory store embedding dimension mismatch. "
                f"Database expects {current_dimensions}, but the active model uses "
                f"{self.embedding_dimensions}. Point this server at a matching "
                "database or change MEMORY_EMBEDDING_DIMENSIONS."
            )
