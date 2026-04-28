# AuraBot Plugin-Modular Architecture

This document defines the technical plan for turning AuraBot into a plugin-host app: a stable context, memory, and agent runtime where installable plugins can reshape the frontend, context capture behavior, memory model, retrieval policy, tools, prompts, and workflows.

## Current Starting Point

The current repository already has the right primitives, but they are not yet pluginized.

- The macOS app lives in `apps/macos` and owns the user-facing app shell, capture controls, settings, context routing, and the managed local memory backend.
- Context capture is currently represented in `apps/macos/Sources/AuraBot/ContextRouting`, including `ContextRouter`, app/browser/git/terminal collectors, and `ContextEvent`/`ContextCapturePlan` models.
- Memory client DTOs live in `apps/macos/Sources/AuraBot/Models/Memory.swift`, including Memory v2 recent-context request and response shapes.
- The local-first Memory v2 backend lives in `services/memory-pglite`, with contracts, recent context events, summaries, graph extraction, indexing, jobs, and server routes.
- Memory v2 behavior is documented in `docs/memory-v2-api.md`, `docs/memory-v2-contracts.md`, `docs/memory-v2-operations.md`, and `docs/memory-v2-schema.md`.
- There is no first-class `Plugin`, `PluginRegistry`, `PluginRuntime`, or plugin package format yet.

The plugin system should build on these primitives instead of replacing them. The core app remains the trusted host; plugins register behavior through versioned extension points.

## Product Goal

AuraBot should be a base app with context capture and durable memory, but the installed plugin should be able to decide what AuraBot becomes.

Example: installing an "AI Tutor" plugin should be able to:

- Replace the default workspace UI with a learning dashboard.
- Capture browser, document, video, and code context differently from the default app.
- Store tutor-specific memories such as concepts, misconceptions, lesson progress, quiz attempts, and practice outcomes.
- Change retrieval so tutoring sessions prioritize learning history over generic activity history.
- Register a tutor agent profile with lesson, quiz, review, and project-building modes.
- Add tools such as "generate practice set", "explain from my history", and "review weak concepts".

## Design Principles

- Keep the host boring and stable. The host owns process lifetime, permissions, storage, IPC, user consent, signing, and API compatibility.
- Let plugins be expressive but bounded. Plugins can change behavior only through explicit extension points.
- Use declarative manifests for install-time decisions. The host must know permissions, routes, memory schemas, jobs, and tools before enabling a plugin.
- Version every contract. A plugin must declare which AuraBot host API and Memory v2 API versions it supports.
- Namespace all plugin-owned data. IDs, memory types, routes, jobs, settings, and assets must be scoped by `plugin_id`.
- Prefer local-first execution. Remote code loading should be disallowed for ordinary plugins.
- Make capture consent visible. Plugins must not silently expand what AuraBot captures.
- Make migrations dry-runnable, idempotent, and reversible where practical.
- Treat plugin install as a security event, not a UI preference.

## Non-Goals For The First Version

- No arbitrary native Swift bundle loading from third-party plugins.
- No plugin access to raw database handles.
- No runtime download and execution of remote JavaScript.
- No hidden background capture outside declared permissions.
- No plugin ability to bypass app-level model, network, privacy, or retention settings.
- No marketplace requirement for v1. Local developer installs are enough for the first vertical slice.

## Target Architecture

```text
AuraBot Host
  macOS shell
  plugin registry
  permission broker
  context bus
  memory client
  agent runtime
  UI runtime
  install/update manager

Plugin Runtime
  manifest validator
  extension loader
  migration runner
  worker sandbox
  IPC bridge

Memory v2 Service
  recent context
  summaries
  graph
  search/indexing
  plugin metadata
  plugin memory namespaces

Installed Plugin Package
  manifest
  UI bundle
  extension modules
  prompts
  schemas
  migrations
  tests
  assets
```

The host should expose a narrow SDK. Plugins should never import host internals directly.

## Proposed Repository Layout

```text
apps/macos/Sources/AuraBot/Plugins/
  PluginManifest.swift
  PluginRegistry.swift
  PluginInstaller.swift
  PluginPermissionBroker.swift
  PluginRuntime.swift
  PluginUIHost.swift
  PluginIPC.swift

services/memory-pglite/src/plugins/
  manifest.ts
  registry.ts
  permissions.ts
  migrations.ts
  runtime.ts
  routes.ts

plugin-sdk/
  package.json
  src/
    manifest.ts
    context.ts
    memory.ts
    agent.ts
    ui.ts
    tools.ts
    validation.ts

plugins/
  ai-tutor/
    aurabot.plugin.json
    ui/
    extensions/
    prompts/
    schemas/
    migrations/
    tests/
```

The `plugin-sdk` package should hold the canonical TypeScript types and validators. The Swift app can mirror the manifest and IPC DTOs in Swift.

## Plugin Package Format

A plugin is a directory or archive with a required manifest:

```text
ai-tutor/
  aurabot.plugin.json
  ui/
    dist/
      index.html
      assets/
  extensions/
    context.js
    memory.js
    agent.js
    tools.js
  prompts/
    tutor.system.md
    quiz.system.md
  schemas/
    learning-memory.schema.json
  migrations/
    001_init.json
    002_concept_graph.json
  tests/
    manifest.test.ts
    context.test.ts
    memory.test.ts
```

### Manifest v1

```json
{
  "schema_version": "aurabot-plugin-v1",
  "plugin_id": "com.aurabot.ai-tutor",
  "name": "AI Tutor",
  "version": "0.1.0",
  "description": "Turns AuraBot into an adaptive AI learning coach.",
  "author": {
    "name": "AuraBot",
    "url": "https://example.invalid"
  },
  "compatibility": {
    "host_api": "^1.0.0",
    "memory_api": "memory-v2"
  },
  "entrypoints": {
    "ui": "ui/dist/index.html",
    "context": "extensions/context.js",
    "memory": "extensions/memory.js",
    "agent": "extensions/agent.js",
    "tools": "extensions/tools.js"
  },
  "permissions": {
    "host_permissions": ["screenRecording", "accessibility"],
    "context_sources": ["browser", "app", "file"],
    "memory": ["read_core", "write_plugin_namespace", "search_core"],
    "network": {
      "mode": "host_brokered",
      "domains": []
    },
    "filesystem": {
      "mode": "scoped_bookmarks",
      "paths": []
    },
    "models": {
      "chat": true,
      "vision": false,
      "embeddings": true
    }
  },
  "extensions": {
    "ui_routes": [
      {
        "id": "dashboard",
        "path": "/learn",
        "title": "Learn",
        "activation": "workspace_root"
      }
    ],
    "context_providers": ["learning-browser-context"],
    "memory_schemas": ["learning-memory"],
    "retrieval_policies": ["tutor-session"],
    "agent_profiles": ["ai-tutor"],
    "tools": ["generate-practice-set", "review-weak-concepts"],
    "settings_panels": ["ai-tutor-settings"],
    "background_jobs": ["nightly-learning-summary"]
  },
  "install": {
    "migrations": ["migrations/001_init.json"],
    "default_enabled": true,
    "requires_host_relaunch": false
  },
  "onboarding": {
    "required": true,
    "title": "AI Tutor setup",
    "detail": "AI Tutor needs learning context before its workspace is ready.",
    "required_host_permissions": ["screenRecording", "accessibility"],
    "steps": [
      "Confirm learning sources",
      "Enable context capture",
      "Open the tutor workspace"
    ]
  },
  "presentation": {
    "workspace_title": "Study Queue",
    "workspace_icon": "graduationcap",
    "workspace_sections": [
      "Current concept",
      "Practice prompts",
      "Session recap"
    ]
  },
  "integrity": {
    "signature": "optional-for-dev",
    "sha256": "optional-for-dev"
  }
}
```

Required manifest rules:

- `plugin_id` must be globally unique, reverse-DNS style, lowercase, and immutable after first release.
- `schema_version` must match a validator known to the host.
- `compatibility.host_api` must be checked before install and before every activation.
- Every permission must be declared before install.
- Plugin-owned onboarding must be declared in `onboarding`; base host onboarding must not hardcode plugin-specific setup.
- `install.requires_host_relaunch` must be present when the plugin needs Aura to relaunch after install.
- `presentation` must declare the first workspace shell the host can show immediately after install.
- Every extension id must be unique within the plugin and stored as `<plugin_id>/<extension_id>` internally.
- Entry points must resolve inside the plugin directory after path normalization.
- Symlinks, parent directory traversal, hidden executable payloads, and remote entry points must be rejected.

## Remote Catalog Format

The macOS host can load installable plugins from a hardcoded catalog URL in `PluginInstaller.catalogURLString`. The catalog is publisher-hosted JSON; each item points to the canonical plugin manifest and optionally to a downloadable package archive.

```json
{
  "schema_version": "aurabot-plugin-catalog-v1",
  "plugins": [
    {
      "plugin_id": "com.aurabot.ai-tutor",
      "name": "AI Tutor",
      "version": "0.1.0",
      "summary": "Turns AuraBot into an adaptive AI learning coach.",
      "icon": "graduationcap",
      "manifest_url": "https://plugins.example.com/ai-tutor/aurabot.plugin.json",
      "package_url": "https://plugins.example.com/ai-tutor/ai-tutor-0.1.0.zip",
      "sha256": "optional-dev-checksum"
    }
  ]
}
```

Catalog rules:

- `manifest_url` is required.
- `package_url` is optional in the current host slice, but will be required once plugin web UI assets are loaded from installed packages.
- Relative `manifest_url` and `package_url` values are resolved relative to the catalog URL.
- Catalog metadata is display-only; the manifest remains the source of truth for permissions, onboarding, install behavior, and presentation.
- The host stores installed plugin manifests under `~/.aurabot/plugins/<plugin_id>/<version>/aurabot.plugin.json`.

## Extension Points

### UIRoute

Registers plugin-owned screens inside the AuraBot shell.

Recommended v1 approach:

- Host the app shell in SwiftUI.
- Render plugin UI in a `WKWebView` or equivalent web runtime.
- Communicate over a typed IPC bridge.
- Do not load plugin SwiftUI as arbitrary native code in v1.

This keeps the host trusted and lets plugins fully reshape the frontend without requiring unsafe native dynamic loading.

### ContextProvider

Adds or modifies context capture behavior. Context providers should output normalized Memory v2 recent-context events, not ad hoc blobs.

```ts
export interface ContextProvider {
  id: string;
  sources: Array<"screen" | "app" | "browser" | "repo" | "file" | "terminal" | "system">;
  shouldCapture(input: ContextProbe): Promise<CaptureDecision>;
  capture(input: CaptureRequest): Promise<PluginContextEvent[]>;
}
```

Guardrails:

- A provider can only access sources granted by manifest permissions.
- Capture must include `capture_reason`, `plugin_id`, and source metadata.
- Sensitive raw content must be redacted before persistence when possible.
- Providers must support a no-op path when permission is missing.
- Plugins must not weaken global capture throttles, TTLs, or privacy settings.

### MemorySchema

Declares plugin memory types and metadata schemas.

```json
{
  "id": "learning-memory",
  "version": 1,
  "types": {
    "concept_understood": {
      "required": ["concept", "confidence", "evidence"],
      "properties": {
        "concept": { "type": "string" },
        "confidence": { "type": "number", "minimum": 0, "maximum": 1 },
        "evidence": { "type": "array" }
      }
    },
    "misconception": {
      "required": ["concept", "incorrect_belief", "correction"],
      "properties": {
        "concept": { "type": "string" },
        "incorrect_belief": { "type": "string" },
        "correction": { "type": "string" }
      }
    }
  }
}
```

Guardrails:

- Plugin schemas extend Memory v2; they do not fork it.
- Plugin records must include `plugin_id`, `schema_id`, `schema_version`, `user_id`, `source`, evidence, and timestamps.
- Core Memory v2 search must still be able to ignore plugin-specific metadata safely.
- Schema upgrades require migrations and fixture updates.

### MemoryExtractor

Converts recent context into durable plugin memories, graph entities, relations, and summaries.

Guardrails:

- Extractors must produce evidence-backed records.
- Extractors must be idempotent using source hashes or idempotency keys.
- Extractors must preserve the original recent-context source id.
- Extractors must not invent high-confidence user facts from weak evidence.

### RetrievalPolicy

Controls what memory is retrieved for a plugin agent or UI view.

```ts
export interface RetrievalPolicy {
  id: string;
  buildQuery(input: RetrievalInput): Promise<MemorySearchRequest>;
  rerank(input: RetrievalRerankInput): Promise<MemorySearchItem[]>;
}
```

Guardrails:

- Policies can request core memory only when `memory.search_core` is granted.
- Policies must label whether results came from core memory or plugin namespace.
- Rerankers must not hide safety-relevant evidence or source metadata from agent prompts.

### AgentProfile

Defines the plugin-specific assistant behavior.

```ts
export interface AgentProfile {
  id: string;
  displayName: string;
  systemPrompt: string;
  retrievalPolicyId: string;
  tools: string[];
  modelPolicy: {
    chat: "host_default" | "plugin_requested";
    vision: "disabled" | "host_default" | "plugin_requested";
  };
}
```

Guardrails:

- The host owns final model selection and policy enforcement.
- Plugin prompts must be treated as data, not authority over host security rules.
- Agent profiles cannot request undeclared tools or permissions.
- Prompt updates should be versioned and testable with fixtures.

### ToolProvider

Registers plugin commands callable by the agent or UI.

Guardrails:

- Tools must declare input and output schemas.
- Tools must be deterministic when possible.
- Tools that mutate data require explicit capability declarations.
- Tools with external side effects require user confirmation unless the host marks them trusted.

### BackgroundJob

Runs scheduled or event-triggered plugin work.

Guardrails:

- Jobs must have idempotency keys.
- Jobs must be cancellable.
- Jobs must have quotas and timeouts.
- Jobs must be disabled when the plugin is disabled.

## Runtime Boundaries

The Swift macOS host should own plugin install, enable, disable, upgrade, uninstall, local registry state, permission prompts, user consent records, window shell, navigation, plugin UI container, IPC, memory-service lifecycle, and app-level privacy settings.

Plugin UI should run as static bundled web assets in v1. It may render plugin-specific screens and call host APIs through typed IPC. It must not directly access local files, the database, remote script injection, native process spawning, or secrets.

Plugin extension code should run in a sandboxed worker process or memory-service-managed worker. It may transform context, produce extraction candidates, build retrieval queries, and execute pure tools. It must not run arbitrary shell commands, access raw DB handles, use network outside the host broker, or persist files outside plugin data storage.

## Plugin Registry State

Use three different states:

- `installed`: files are present and manifest is valid.
- `enabled`: extensions can register and background jobs can run.
- `active`: the plugin owns the current workspace UI/agent experience.

AuraBot can support one active workspace plugin in v1. Additive plugins can come later after conflict resolution exists.

```json
{
  "installed": {
    "com.aurabot.ai-tutor": {
      "version": "0.1.0",
      "path": "~/.aurabot/plugins/com.aurabot.ai-tutor/0.1.0",
      "enabled": true,
      "active": true,
      "installed_at": "2026-04-28T00:00:00Z",
      "updated_at": "2026-04-28T00:00:00Z",
      "granted_permissions": {
        "context_sources": ["browser", "app"],
        "memory": ["read_core", "write_plugin_namespace", "search_core"]
      }
    }
  },
  "active_workspace_plugin_id": "com.aurabot.ai-tutor"
}
```

## Install Lifecycle

1. Receive plugin package from local path or trusted source.
2. Unpack into a quarantine directory.
3. Reject path traversal, symlinks that escape the package, hidden executables, remote entry points, oversized files, and invalid encodings.
4. Validate `aurabot.plugin.json` against the manifest schema.
5. Verify compatibility with host API and Memory v2.
6. Verify integrity and signature when not in developer mode.
7. Build a permission review screen from the manifest.
8. Dry-run migrations and extension registration.
9. Ask user for install and permission approval.
10. Move package into the plugin store atomically.
11. Apply migrations.
12. Register extensions.
13. Enable plugin if `install.default_enabled` is true.
14. Activate plugin only after explicit selection or clear install intent.
15. If `install.requires_host_relaunch` is true, persist the active plugin id, relaunch Aura, and restore the plugin on startup.
16. If `onboarding.required` is true, show the plugin-owned onboarding surface inside the plugin workspace before rendering the normal plugin workspace.

## Upgrade Lifecycle

1. Validate the new package independently.
2. Compare manifest permissions against the installed version.
3. If permissions expand, require a new approval.
4. Dry-run migrations from current version to target version.
5. Snapshot plugin registry state and migration state.
6. Disable plugin jobs.
7. Apply package swap atomically.
8. Run migrations.
9. Re-register extensions.
10. Re-enable jobs.
11. Roll back package and registry state if validation or migration fails.

## Uninstall Lifecycle

Uninstall should have two modes:

- Disable only: stop plugin behavior but keep data.
- Remove plugin and data: delete plugin package and plugin namespace after explicit user confirmation.

Plugin data deletion must be scoped by `plugin_id`. The host should show what will be removed before deletion.

## Context Pipeline

```text
Raw source
  -> host capture permission check
  -> host collector
  -> plugin ContextProvider or ContextFilter
  -> redaction and size limits
  -> normalized ContextEvent
  -> Memory v2 recent_context
  -> plugin MemoryExtractor
  -> summaries, graph, plugin memory records
  -> RetrievalPolicy
  -> AgentProfile prompt/context packet
```

Context events should preserve:

- `schema_version`
- `user_id`
- `agent_id`
- `plugin_id`
- `source`
- `content`
- `content_hash`
- `occurred_at`
- `created_at`
- `ttl_seconds`
- `importance`
- `metadata.capture_reason`
- `metadata.permission_scope`
- `metadata.evidence`

## Memory Model

Memory v2 remains the storage foundation. Plugins add namespaced metadata, schemas, and extraction behavior.

Recommended database strategy for v1:

- Keep core recent context, summary, graph, and search tables under Memory v2.
- Add plugin registry and plugin schema tables.
- Store plugin-specific memory metadata as JSON with validated schema ids.
- Add indexes on `plugin_id`, `schema_id`, `user_id`, `source`, and time.
- Avoid plugin-created arbitrary tables until the migration DSL and rollback story are mature.

Example logical record:

```json
{
  "id": "com.aurabot.ai-tutor/mem_concept_transformers_001",
  "schema_version": "memory-v2",
  "plugin_id": "com.aurabot.ai-tutor",
  "schema_id": "learning-memory",
  "schema_revision": 1,
  "type": "concept_understood",
  "user_id": "default_user",
  "content": "User understands the difference between attention heads and transformer layers.",
  "metadata": {
    "concept": "transformer architecture",
    "confidence": 0.78,
    "course": "AI foundations"
  },
  "evidence": [
    {
      "source": "recent_context",
      "source_id": "ctx_20260428_0001",
      "excerpt": "The user correctly explained why multi-head attention captures different relationships."
    }
  ],
  "created_at": "2026-04-28T00:00:00Z",
  "updated_at": "2026-04-28T00:00:00Z"
}
```

## Permission Model

Permissions should be capability-based and denied by default.

| Group | Examples | Default |
| --- | --- | --- |
| `context_sources` | `screen`, `browser`, `app`, `repo`, `file`, `terminal`, `system` | denied |
| `memory` | `read_core`, `search_core`, `write_plugin_namespace`, `delete_plugin_namespace` | denied |
| `models` | `chat`, `vision`, `embeddings` | host default |
| `network` | host-brokered domain allowlist | denied |
| `filesystem` | scoped bookmarks | denied |
| `tools` | tool-specific capabilities | denied |
| `background_jobs` | scheduled or event-triggered work | denied |

The host should store granted permissions separately from requested permissions. A plugin update cannot silently gain new permissions.

## IPC Contract

Plugin UI and worker code should call host services through typed IPC.

Example channels:

```text
plugin.manifest.get
plugin.permissions.get
plugin.settings.get
plugin.settings.set
context.current.get
context.recent.list
context.capture.request
memory.search
memory.plugin.write
memory.plugin.delete
agent.invoke
tool.invoke
job.status
```

Every IPC request should include `request_id`, `plugin_id`, `extension_id`, `capability`, `payload`, and `created_at`. Every response should include `request_id`, `ok`, `payload` or `error`, and `audit_id`. The host must derive `plugin_id` from the loaded plugin session, not trust a caller-provided value.

## AI Tutor Plugin Example

The AI Tutor plugin can be the first full vertical slice.

Manifest:

- `plugin_id`: `com.aurabot.ai-tutor`
- UI route: `/learn`
- Context sources: `browser`, `app`, optional `file`
- Memory permissions: `write_plugin_namespace`, `search_core`
- Agent profile: `ai-tutor`
- Tools: `generate-practice-set`, `review-weak-concepts`, `explain-from-history`

Context behavior:

- Prefer browser page metadata, selected text, page headings, transcript snippets, and code/document titles over screenshots.
- Classify events as `reading`, `watching`, `coding`, `practicing`, `reviewing`, or `stuck`.
- Store low-TTL recent context for passive activity.
- Promote only evidence-backed learning events to durable plugin memory.

Memory types:

- `concept_seen`
- `concept_understood`
- `misconception`
- `practice_attempt`
- `lesson_progress`
- `project_goal`
- `preferred_explanation_style`

Retrieval policy:

- Search plugin learning memory first.
- Add recent context from the current learning session.
- Add core memory only when it improves personalization or continuity.
- Prefer evidence-backed misconception and practice memories for teaching decisions.

UI:

- Dashboard: current course, active concept, weak concepts, recent progress.
- Lesson view: explanation, examples, practice, quiz.
- Memory view: concepts, misconceptions, evidence, confidence.
- Settings: capture sources, learning goals, explanation style, retention.

## Implementation Roadmap

### Phase 0: Contracts And Tests

- Add manifest JSON schema in `plugin-sdk`.
- Add Swift manifest DTOs and parser.
- Add TypeScript validators.
- Add fixture plugin packages for valid and invalid manifests.
- Add tests for manifest validation, path normalization, compatibility, and permission diffing.

Exit criteria:

- Invalid manifests are rejected with precise errors.
- Valid fixture plugin loads into an in-memory registry.
- Path traversal and remote entry points are rejected.

### Phase 1: Plugin Registry

- Add host-side registry state.
- Add install, enable, disable, activate, and uninstall commands.
- Store registry under `~/.aurabot/plugins/registry.json` or the host settings store.
- Add developer-mode local install only.

Exit criteria:

- A local plugin can be installed and enabled.
- Registry state survives app restart.
- Disable stops extension registration.

### Phase 2: Permission Broker

- Implement requested vs granted permissions.
- Add permission diffing on upgrade.
- Add UI for install-time permission review.
- Add audit logs for plugin capability use.

Exit criteria:

- Plugin code cannot call IPC channels without granted permissions.
- Permission expansion requires approval.

### Phase 3: UI Runtime

- Add plugin UI host in the macOS app.
- Load bundled static UI assets from installed plugin directory.
- Add typed IPC bridge.
- Add route registration for workspace-root plugin UI.

Exit criteria:

- A sample plugin replaces the main workspace screen.
- Plugin UI can read settings and invoke a harmless host command through IPC.
- Remote scripts are blocked.

### Phase 4: Context Extensions

- Add context provider and filter registration.
- Bridge plugin context output into Memory v2 recent context.
- Enforce source permissions, throttles, redaction, and size limits.

Exit criteria:

- A plugin can enrich browser/app context.
- Denied sources are not visible to the plugin.
- Recent-context fixtures include plugin metadata.

### Phase 5: Memory Extensions

- Add plugin schema registry.
- Add plugin memory write/search APIs.
- Add migration dry-run and application.
- Add idempotency and evidence checks for extraction outputs.

Exit criteria:

- A plugin can write namespaced memory records.
- Schema-invalid records are rejected.
- Plugin uninstall can preserve or remove plugin namespace data.

### Phase 6: Agent Extensions

- Add agent profile registration.
- Add retrieval policy registration.
- Add tool provider registration.
- Route plugin UI chat/actions through plugin agent profile.

Exit criteria:

- AI Tutor agent uses plugin prompt, retrieval policy, and declared tools.
- Undeclared tools and model capabilities are rejected.

### Phase 7: Background Jobs

- Add plugin job scheduler.
- Enforce quotas, timeouts, cancellation, and disable behavior.
- Add audit logs and job status UI.

Exit criteria:

- A plugin job can summarize a learning session.
- Disabling the plugin cancels future jobs.

### Phase 8: Packaging And Distribution

- Add plugin archive format.
- Add signing for non-developer plugins.
- Add update checks through a trusted metadata file.
- Add marketplace only after local install is mature.

Exit criteria:

- Signed plugin packages can be installed.
- Tampered packages are rejected.
- Updates preserve data and require approval for new permissions.

## Testing Strategy

Required test categories:

- Manifest schema validation.
- Path traversal and package integrity checks.
- Permission request, grant, denial, and upgrade diff tests.
- Registry install, enable, disable, activate, uninstall tests.
- UI IPC authorization tests.
- Context source permission tests.
- Recent-context fixture compatibility tests.
- Plugin memory schema validation tests.
- Migration dry-run, apply, rollback, and idempotency tests.
- Retrieval policy tests with mixed core and plugin memory.
- Agent profile tests for undeclared tools and model permissions.
- End-to-end fixture install for `com.aurabot.ai-tutor`.

## Guardrails Checklist

Before a plugin can be enabled:

- Manifest validates against the known schema.
- Host API and Memory API versions are compatible.
- Package paths are normalized and stay inside the plugin directory.
- Requested permissions are shown to the user.
- Granted permissions are stored separately from requested permissions.
- Migrations dry-run successfully.
- Entry points resolve to local bundled files.
- UI remote script loading is blocked.
- IPC channels enforce capability checks.
- Context providers cannot read denied sources.
- Memory writes are namespaced by `plugin_id`.
- Memory writes include schema id, evidence, and idempotency fields where applicable.
- Background jobs have timeouts, quotas, and cancellation.
- Disable stops UI routes, workers, tools, and background jobs.
- Uninstall cannot delete core memory.

## First Vertical Slice

Build the smallest useful plugin system around the AI Tutor example:

1. Add manifest schema and fixture validation.
2. Add plugin registry with local developer install.
3. Add one plugin UI route loaded from static assets.
4. Add read-only IPC for current context and plugin settings.
5. Add one context filter that tags learning browser events.
6. Add plugin memory schema registry and a single `concept_seen` memory type.
7. Add one retrieval policy that searches plugin memory first.
8. Add one agent profile with a tutor system prompt.
9. Add tests for the full path from install to context event to plugin memory to agent retrieval.

This gives the product shape without taking on marketplace, signing, arbitrary native plugins, or broad tool execution too early.
