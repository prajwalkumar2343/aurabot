# AuraBot Plugin-Modular Architecture

This document defines the technical plan for turning AuraBot into a plugin-host app: a stable context, memory, and agent runtime where installable plugins can reshape the frontend, context capture behavior, screen capture strategy, memory model, retrieval policy, app behavior, window presentation, tools, prompts, and workflows.

## Current Starting Point

The current repository already has the right primitives, but they are not yet pluginized.

- The macOS app lives in `apps/macos` and owns the user-facing app shell, capture controls, settings, context routing, and the managed local memory backend.
- Context capture is currently represented in `apps/macos/Sources/AuraBot/ContextRouting`, including `ContextRouter`, app/browser/git/terminal collectors, and `ContextEvent`/`ContextCapturePlan` models.
- Memory client DTOs live in `apps/macos/Sources/AuraBot/Models/Memory.swift`, including Memory v2 recent-context request and response shapes.
- The local-first Memory v2 backend lives in `services/memory-pglite`, with contracts, recent context events, summaries, graph extraction, indexing, jobs, and server routes.
- Memory v2 behavior is documented in `docs/memory-v2-api.md`, `docs/memory-v2-contracts.md`, `docs/memory-v2-operations.md`, and `docs/memory-v2-schema.md`.
- There is no first-class `Plugin`, `PluginRegistry`, `PluginRuntime`, or plugin package format yet.

The plugin system should build on these primitives instead of replacing them. The core app remains the trusted host; plugins register behavior through versioned extension points. Some plugins can be normal additive extensions; others can be takeover plugins that replace the active app experience.

## Product Goal

AuraBot should be a base app with context capture and durable memory, but the installed plugin should be able to decide what AuraBot becomes.

Example: installing an "AI Tutor" plugin should be able to:

- Replace the default workspace UI with a learning dashboard.
- Capture browser, document, video, and code context differently from the default app.
- Store tutor-specific memories such as concepts, misconceptions, lesson progress, quiz attempts, and practice outcomes.
- Change retrieval so tutoring sessions prioritize learning history over generic activity history.
- Register a tutor agent profile with lesson, quiz, review, and project-building modes.
- Add tools such as "generate practice set", "explain from my history", and "review weak concepts".
- Replace default screen capture with a plugin-owned capture policy, such as browser DOM and transcript first, app metadata second, screenshot/vision fallback last.
- Change app visibility and overlay behavior, such as lesson overlays, always-on-top quiz windows, and capture exclusion for plugin UI.

## Honest Assessment

This plan is good if AuraBot is meant to become a platform. It is too much if AuraBot should remain one simple memory app.

Strengths:

- It makes plugins genuinely useful. An AI Tutor, research assistant, meeting coach, or coding companion can feel like a different product instead of a panel bolted onto the same UI.
- It keeps the base app small. AuraBot core becomes the runtime: install, permissions, capture, memory, IPC, OS integration, and policy enforcement.
- It makes behavior inspectable. A plugin declares which parts of the app it wants to replace, which capture methods it wants, and which memory capabilities it needs.
- It lets you build multiple products on the same memory/context foundation.

Main issues:

- The complexity is high. A takeover plugin system needs registry state, permissions, migration handling, UI hosting, IPC, diagnostics, test fixtures, and rollback before it is trustworthy.
- The security risk is real. A plugin that controls screen capture, memory, overlay visibility, and tools can collect sensitive data or manipulate the user experience if the host does not enforce strict boundaries.
- Debugging gets harder. When behavior changes by active plugin, every bug report needs plugin state, granted permissions, active policies, migration version, and runtime diagnostics.
- Plugin compatibility becomes a product commitment. Once external plugins exist, changing context, memory, UI, and agent contracts becomes expensive.
- UX can become chaotic. If multiple plugins try to control app behavior, capture, hotkeys, overlays, and retrieval at once, the app will feel unpredictable.
- Full native takeover is dangerous. Letting plugins load arbitrary Swift/native code would make them effectively part of the app and hard to sandbox.

Recommendation:

- Build takeover plugins, but start with one active `workspace` plugin at a time.
- Make plugin control declarative and policy-based.
- Keep OS power in the host: screen capture, window levels, accessibility, filesystem, network, global hotkeys, model access, and memory writes.
- Let plugins control decisions through approved policies, not private API calls.
- Add additive plugins only after the single-workspace takeover model is stable.

Core rule:

```text
Plugin controls app policy.
Host controls privileged execution.
```

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
- Treat takeover activation as a separate security event from install. A plugin can be installed but not allowed to replace app behavior until the user activates it.

## Non-Goals For The First Version

- No arbitrary native Swift bundle loading from third-party plugins.
- No plugin access to raw database handles.
- No runtime download and execution of remote JavaScript.
- No hidden background capture outside declared permissions.
- No plugin ability to bypass app-level model, network, privacy, OS, capture, windowing, or retention settings.
- No marketplace requirement for v1. Local developer installs are enough for the first vertical slice.

## Plugin Control Model

AuraBot supports three plugin classes:

| Class | Purpose | Control Level |
| --- | --- | --- |
| `extension` | Adds tools, panels, providers, memory extractors, or small routes | Additive |
| `workspace` | Replaces the active app experience for a user workflow | Takeover |
| `system` | Replaces one exclusive core slot such as context engine or memory engine | Exclusive infrastructure |

### Extension Plugin

An extension plugin adds one or more capabilities without taking over the product.

Examples:

- Add a `summarize-current-page` tool.
- Add a small memory visualization panel.
- Add a model provider.
- Add a browser-context enrichment filter.

### Workspace Plugin

A workspace plugin is the primary model for "the plugin controls the app." It can replace:

- Main workspace UI
- Navigation surface
- Agent profile
- Context policy
- Capture policy
- Retrieval policy
- Memory extraction policy
- Window and overlay policy
- Commands and settings for that workspace

Only one workspace plugin should be active in v1. The active workspace plugin owns the current app experience, but it still calls host APIs through typed contracts.

### System Plugin

A system plugin replaces a single exclusive infrastructure slot.

Examples:

- `context_engine`
- `memory_engine`
- `capture_engine`
- `model_router`

System plugins have the highest risk. They should require explicit activation, compatibility checks, diagnostics, and an easy fallback to the built-in implementation.

## Takeover Contract

Takeover is explicit manifest state. A plugin does not get full-app control merely by registering many extensions.

```json
{
  "kind": "workspace",
  "takeover": {
    "ui": "replace",
    "agent": "replace",
    "context": "replace",
    "capture": "replace",
    "memory": "augment",
    "retrieval": "replace",
    "window": "replace",
    "commands": "replace",
    "settings": "augment"
  }
}
```

Allowed values:

- `none`: plugin does not affect this surface.
- `augment`: plugin adds behavior while host defaults remain active.
- `replace`: plugin policy becomes the active behavior for the surface.

Rules:

- `replace` requires an explicit permission group for that surface.
- `replace` must have a rollback path to host defaults.
- `replace` must expose diagnostics showing which plugin owns the surface.
- Conflicting `replace` requests fail closed unless one active workspace plugin already owns the app.
- A disabled plugin immediately loses takeover rights.

## Target Architecture

```text
AuraBot Host
  macOS shell
  plugin registry
  permission broker
  context bus
  behavior policy broker
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
    takeover.ts
    context.ts
    capture.ts
    behavior.ts
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
  "kind": "workspace",
  "takeover": {
    "ui": "replace",
    "agent": "replace",
    "context": "replace",
    "capture": "replace",
    "memory": "augment",
    "retrieval": "replace",
    "window": "replace",
    "commands": "replace",
    "settings": "augment"
  },
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
    "context_sources": ["browser", "app", "file", "screen"],
    "capture_methods": ["browser_dom", "browser_transcript", "app_metadata", "screen_ocr", "screen_vision"],
    "memory": ["read_core", "write_plugin_namespace", "search_core"],
    "app_behavior": ["workspace_takeover", "replace_navigation", "replace_commands"],
    "window": ["floating_overlay", "always_on_top", "exclude_plugin_ui_from_capture"],
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
    "app_behavior_policies": ["tutor-app-behavior"],
    "window_policies": ["tutor-overlay-window"],
    "capture_policies": ["learning-capture"],
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
    "default_enabled": true
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
- Every takeover surface must have a matching permission group.
- Every extension id must be unique within the plugin and stored as `<plugin_id>/<extension_id>` internally.
- Entry points must resolve inside the plugin directory after path normalization.
- Symlinks, parent directory traversal, hidden executable payloads, and remote entry points must be rejected.
- Workspace takeover must be activated explicitly and be reversible.

## Extension Points

### AppBehaviorPolicy

Controls high-level app behavior for a workspace plugin.

```ts
export interface AppBehaviorPolicy {
  id: string;
  navigation: "host_default" | "plugin_workspace";
  commands: "host_default" | "plugin_workspace" | "merged";
  activationRules: Array<"manual" | "on_learning_session" | "on_project_context">;
  fallback: "host_default";
}
```

Guardrails:

- The host owns final activation and fallback.
- The policy cannot hide the plugin's active status from the user.
- The policy cannot disable host safety, settings, privacy, or plugin management surfaces.
- A user must always have a host-owned way to leave or disable the active workspace plugin.

### WindowPolicy

Controls app visibility, overlays, and capture exclusion.

```ts
export interface WindowPolicy {
  id: string;
  presentation: "normal" | "side_panel" | "floating_overlay" | "menu_bar";
  level: "normal" | "above_normal" | "always_on_top";
  hideWhen: Array<"screen_sharing" | "fullscreen_video" | "sensitive_app" | "focus_mode">;
  captureExclusion: {
    excludePluginUIFromScreenshots: boolean;
  };
}
```

Guardrails:

- The host applies macOS window APIs; plugin code only returns policy.
- `always_on_top` requires explicit user approval.
- Plugin UI must be excluded from AuraBot screen capture when requested and supported.
- The host can override or suppress overlays during screen sharing, secure input, fullscreen apps, and sensitive app contexts.

### CapturePolicy

Replaces or augments the default screen capture method.

```ts
export interface CapturePolicy {
  id: string;
  priority: Array<"browser_dom" | "browser_transcript" | "app_metadata" | "selected_text" | "screen_ocr" | "screen_vision" | "screenshot">;
  fallback: "host_default" | "screenshot" | "none";
  ttlSeconds: number;
  redaction: "host_default" | "strict";
}
```

Guardrails:

- Capture methods must be declared in permissions.
- Host privacy settings and OS permissions remain authoritative.
- The plugin cannot force screenshot capture when global capture is disabled.
- The plugin cannot lower redaction, throttling, or retention below host policy.
- The plugin must declare how plugin UI should be treated during capture.

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
| `capture_methods` | `browser_dom`, `browser_transcript`, `app_metadata`, `selected_text`, `screen_ocr`, `screen_vision`, `screenshot` | denied |
| `memory` | `read_core`, `search_core`, `write_plugin_namespace`, `delete_plugin_namespace` | denied |
| `app_behavior` | `workspace_takeover`, `replace_navigation`, `replace_commands`, `replace_agent` | denied |
| `window` | `floating_overlay`, `always_on_top`, `side_panel`, `exclude_plugin_ui_from_capture` | denied |
| `models` | `chat`, `vision`, `embeddings` | host default |
| `network` | host-brokered domain allowlist | denied |
| `filesystem` | scoped bookmarks | denied |
| `tools` | tool-specific capabilities | denied |
| `background_jobs` | scheduled or event-triggered work | denied |

The host should store granted permissions separately from requested permissions. A plugin update cannot silently gain new permissions.

Takeover permissions should be reviewed as a group. The install UI should tell the user when a plugin wants to replace app UI, app commands, capture strategy, memory retrieval, or window behavior.

## IPC Contract

Plugin UI and worker code should call host services through typed IPC.

Example channels:

```text
plugin.manifest.get
plugin.permissions.get
plugin.settings.get
plugin.settings.set
app.behavior.get
app.behavior.requestActivation
window.policy.get
window.policy.preview
context.current.get
context.recent.list
context.capture.request
context.capture.policy.get
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
- `kind`: `workspace`
- Takeover: replace UI, agent, context, capture, retrieval, window, and commands; augment memory and settings.
- UI route: `/learn`
- Context sources: `browser`, `app`, optional `file`, fallback `screen`
- Capture methods: `browser_dom`, `browser_transcript`, `app_metadata`, `screen_ocr`, `screen_vision`
- Memory permissions: `write_plugin_namespace`, `search_core`
- Window permissions: `floating_overlay`, `always_on_top`, `exclude_plugin_ui_from_capture`
- Agent profile: `ai-tutor`
- Tools: `generate-practice-set`, `review-weak-concepts`, `explain-from-history`

Context behavior:

- Prefer browser page metadata, selected text, page headings, transcript snippets, and code/document titles over screenshots.
- Use screenshots only as a fallback when structured sources are unavailable or insufficient.
- Classify events as `reading`, `watching`, `coding`, `practicing`, `reviewing`, or `stuck`.
- Store low-TTL recent context for passive activity.
- Promote only evidence-backed learning events to durable plugin memory.

App and window behavior:

- Replace the main workspace with a learning dashboard.
- Show a floating lesson or quiz overlay only during an active learning session.
- Exclude plugin UI from AuraBot capture when possible.
- Hide overlays during screen sharing, sensitive apps, fullscreen video, or explicit focus mode.
- Keep host-owned plugin management and emergency disable controls visible.

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
- Track plugin class: `extension`, `workspace`, or `system`.
- Track active workspace plugin separately from installed/enabled plugins.
- Store registry under `~/.aurabot/plugins/registry.json` or the host settings store.
- Add developer-mode local install only.

Exit criteria:

- A local plugin can be installed and enabled.
- One workspace plugin can be activated and deactivated.
- Registry state survives app restart.
- Disable stops extension registration.

### Phase 2: Permission Broker

- Implement requested vs granted permissions.
- Add permission diffing on upgrade.
- Add UI for install-time permission review.
- Add takeover activation review for replace-level surfaces.
- Add audit logs for plugin capability use.

Exit criteria:

- Plugin code cannot call IPC channels without granted permissions.
- Permission expansion requires approval.
- Workspace takeover cannot activate without explicit approval.

### Phase 3: Behavior And Window Runtime

- Add `AppBehaviorPolicy` registration.
- Add `WindowPolicy` registration.
- Add host-owned fallback controls to exit the active workspace plugin.
- Add screen-sharing, fullscreen, sensitive-app, and focus-mode suppression hooks.

Exit criteria:

- A sample workspace plugin can replace app navigation and commands.
- A sample plugin can request a floating overlay through host policy.
- The host can disable or suppress overlays without plugin cooperation.
- The user can always return to host defaults.

### Phase 4: UI Runtime

- Add plugin UI host in the macOS app.
- Load bundled static UI assets from installed plugin directory.
- Add typed IPC bridge.
- Add route registration for workspace-root plugin UI.

Exit criteria:

- A sample plugin replaces the main workspace screen.
- Plugin UI can read settings and invoke a harmless host command through IPC.
- Remote scripts are blocked.

### Phase 5: Capture And Context Extensions

- Add `CapturePolicy` registration.
- Add context provider and filter registration.
- Bridge plugin context output into Memory v2 recent context.
- Enforce source permissions, throttles, redaction, and size limits.

Exit criteria:

- A workspace plugin can replace default capture order.
- A plugin can enrich browser/app context.
- Screenshot capture remains a host-controlled fallback.
- Denied sources are not visible to the plugin.
- Recent-context fixtures include plugin metadata.

### Phase 6: Memory Extensions

- Add plugin schema registry.
- Add plugin memory write/search APIs.
- Add migration dry-run and application.
- Add idempotency and evidence checks for extraction outputs.

Exit criteria:

- A plugin can write namespaced memory records.
- Schema-invalid records are rejected.
- Plugin uninstall can preserve or remove plugin namespace data.

### Phase 7: Agent Extensions

- Add agent profile registration.
- Add retrieval policy registration.
- Add tool provider registration.
- Route plugin UI chat/actions through plugin agent profile.

Exit criteria:

- AI Tutor agent uses plugin prompt, retrieval policy, and declared tools.
- Undeclared tools and model capabilities are rejected.

### Phase 8: Background Jobs

- Add plugin job scheduler.
- Enforce quotas, timeouts, cancellation, and disable behavior.
- Add audit logs and job status UI.

Exit criteria:

- A plugin job can summarize a learning session.
- Disabling the plugin cancels future jobs.

### Phase 9: Packaging And Distribution

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
- Takeover activation and rollback tests.
- Registry install, enable, disable, activate, uninstall tests.
- App behavior and window policy suppression tests.
- UI IPC authorization tests.
- Capture policy fallback tests.
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
- Takeover surfaces are shown to the user before activation.
- Granted permissions are stored separately from requested permissions.
- Migrations dry-run successfully.
- Entry points resolve to local bundled files.
- UI remote script loading is blocked.
- IPC channels enforce capability checks.
- App behavior and window policy requests are host-applied and host-reversible.
- Capture policies cannot bypass global capture, privacy, redaction, or retention settings.
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
3. Add one active workspace plugin slot with explicit activation and rollback.
4. Add one plugin UI route loaded from static assets.
5. Add one `AppBehaviorPolicy` that replaces workspace navigation and commands.
6. Add one `WindowPolicy` that can request a floating lesson overlay through the host.
7. Add read-only IPC for current context and plugin settings.
8. Add one `CapturePolicy` that prefers browser DOM/transcript and app metadata before screenshot fallback.
9. Add one context filter that tags learning browser events.
10. Add plugin memory schema registry and a single `concept_seen` memory type.
11. Add one retrieval policy that searches plugin memory first.
12. Add one agent profile with a tutor system prompt.
13. Add tests for install, takeover activation, capture policy, context event, plugin memory, and agent retrieval.

This gives the product shape without taking on marketplace, signing, arbitrary native plugins, or broad tool execution too early.

## Current Implementation Status

Implemented foundation pieces:

- Memory service plugin manifest contracts live in `services/memory-pglite/src/plugins`.
- Manifest validation now covers plugin kind, takeover surfaces, permission groups, unsafe paths, duplicate extension ids, and permission diffs.
- Plugin manifest tests live in `services/memory-pglite/tests/plugins`.
- The macOS app now has host-side plugin policy models in `apps/macos/Sources/AuraBot/Plugins`.
- `PluginHost` can activate one workspace plugin, expose app presentation, expose window policy, expose capture policy, and roll back to host defaults.
- `AppService` owns the plugin host and applies active plugin policies to app presentation, window behavior, and context capture.
- `ContentView` routes to a plugin workspace surface when a workspace plugin replaces the app UI.
- `ContextRouter` accepts an active `CapturePolicy`, so workspace plugins can change structured capture priority and disable screenshot fallback.

Known gaps:

- No persisted plugin registry yet.
- No installer, package unpacker, or manifest loading from disk yet.
- No Swift-side manifest decoder tied to the TypeScript manifest contract yet.
- No plugin UI web runtime or IPC bridge yet.
- No memory namespace write/search APIs for plugin-owned memories yet.
- No real AI Tutor plugin package yet.

## Next Implementation Slice

The next part should turn the in-memory host boundary into installable local plugins.

### 1. Shared Manifest Fixtures

- Add valid and invalid plugin fixture packages under `services/memory-pglite/src/test-fixtures/plugins`.
- Include an AI Tutor workspace manifest with takeover, capture, window, context, memory, retrieval, and agent declarations.
- Include invalid fixtures for path traversal, missing takeover permissions, duplicate extension ids, and permission expansion.
- Use the same fixture JSON from TypeScript and Swift tests to keep contracts aligned.

Exit criteria:

- TypeScript and Swift tests decode the same AI Tutor manifest fixture.
- Invalid fixture errors are stable enough to debug install failures.

### 2. Swift Manifest Decoder

- Add Swift DTOs mirroring `aurabot-plugin-v1`.
- Decode manifest JSON into a trusted intermediate model.
- Validate plugin id, kind, takeover surfaces, entrypoint paths, compatibility, and permissions before activation.
- Map validated workspace manifests into `WorkspacePluginDescriptor`.

Exit criteria:

- The Swift app can decode the AI Tutor fixture.
- A valid fixture becomes a `WorkspacePluginDescriptor`.
- Invalid fixtures fail before touching `PluginHost`.

### 3. Local Plugin Registry

- Add `PluginRegistry` under `apps/macos/Sources/AuraBot/Plugins`.
- Track installed, enabled, active, and granted permissions separately.
- Persist registry state under the AuraBot app data directory.
- Keep install separate from activation.

Exit criteria:

- Registry state survives process restart.
- Only one workspace plugin can be active.
- Disable clears active workspace policy.

### 4. Developer Install Flow

- Add a local developer install API that accepts a plugin directory.
- Validate package paths and manifest before copying or registering.
- Reject symlinks and entrypoints outside the package.
- Dry-run takeover and permissions before install.

Exit criteria:

- A local AI Tutor fixture can be installed in developer mode.
- Unsafe packages are rejected with actionable errors.

### 5. Plugin Workspace UI Runtime

- Replace the placeholder `PluginWorkspaceView` body with a host-owned plugin UI container.
- Start with bundled static HTML loaded from the installed plugin package.
- Add a typed read-only IPC surface for manifest, granted permissions, current context, and plugin settings.
- Keep the host-owned "Return to Aura" path visible.

Exit criteria:

- The installed AI Tutor fixture can replace the main workspace with its own bundled UI.
- Undeclared IPC channels are rejected.
- Remote scripts remain blocked.

### 6. Capture And Memory Integration

- Route active `CapturePolicy` into the context loop with diagnostics.
- Add plugin id and capture policy metadata to recent context events.
- Add plugin memory schema registration and a namespaced write path.
- Add a first `concept_seen` memory type for the AI Tutor plugin.

Exit criteria:

- AI Tutor capture prefers structured browser/app context and uses screenshot only when allowed.
- Stored events include the active plugin id and capture policy reason.
- Plugin memory writes are namespaced and schema-validated.

### 7. Tests To Add Next

- Swift manifest fixture decode tests.
- Swift registry persistence and rollback tests.
- Developer install path-safety tests.
- Plugin workspace activation tests from fixture.
- Plugin UI IPC authorization tests.
- Context capture policy diagnostics tests.
- Plugin memory schema validation tests.
