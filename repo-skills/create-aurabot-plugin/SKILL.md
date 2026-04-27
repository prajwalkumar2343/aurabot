---
name: create-aurabot-plugin
description: Create, design, scaffold, modify, or review AuraBot app plugins for the plugin-modular architecture. Use when the user asks for an installable AuraBot plugin, takeover plugin, workspace plugin, system plugin, plugin manifest, plugin package, plugin UI route, app behavior policy, window policy, capture policy, context provider, memory schema, memory extractor, retrieval policy, agent profile, tool provider, plugin migration, or guardrails for plugin install, permissions, context capture, memory access, frontend replacement, screen capture replacement, app behavior replacement, or AI Tutor-style behavior.
---

# Create AuraBot Plugin

Create AuraBot plugins through the planned host extension system. Keep plugins powerful enough to reshape or take over the app experience, but bounded by manifest validation, capability permissions, namespaced memory, safe migrations, host-owned IPC, and host-owned OS execution.

## First Actions

1. Read `docs/plugin-modular-architecture.md` before designing or changing a plugin.
2. Use `code-review-graph` MCP for repo code reading whenever available.
3. Identify whether the request is for a plugin design, plugin scaffold, plugin implementation, plugin review, takeover/workspace behavior, or core runtime change.
4. If the user explicitly says not to generate code, produce only architecture, manifests, examples, or review notes.
5. If implementation is requested, keep core-host changes separate from plugin-package changes.

## Plugin Boundary

Treat AuraBot as the trusted host:

- The host owns install, enable, disable, upgrade, uninstall, permissions, storage, app privacy settings, model policy, IPC, and process lifetime.
- Plugins register behavior through versioned extension points only.
- Plugins can replace the app experience only as an explicitly activated `workspace` plugin.
- Plugins can replace UI, agent, context, capture, retrieval, window, command, and settings behavior only through declared takeover surfaces.
- Plugins can affect context and memory only through declared providers, filters, capture policies, schemas, extractors, retrieval policies, and agent profiles.
- Plugins must never import, patch, or depend on private host internals unless the user is explicitly building the host runtime.
- Plugins control policy; the host controls privileged execution.

## Workflow

1. Read the relevant architecture and code context.
2. Define the plugin product shape.
3. Choose the plugin class: `extension`, `workspace`, or `system`.
4. Write or update the manifest first.
5. Map every requested behavior to an extension point.
6. Apply the guardrails checklist before writing implementation.
7. Implement in small slices when code is requested.
8. Verify with targeted tests or fixture validation.

Relevant sources:

- `docs/plugin-modular-architecture.md`
- `apps/macos/Sources/AuraBot/ContextRouting`
- `docs/memory-v2-contracts.md`
- `services/memory-pglite/src/contracts`
- `services/memory-pglite/src/recent`
- `services/memory-pglite/src/graph`
- `services/memory-pglite/src/indexing`
- `services/memory-pglite/src/jobs`

## Manifest Rules

- Use `schema_version: "aurabot-plugin-v1"`.
- Use a stable reverse-DNS `plugin_id`.
- Declare `kind`: `extension`, `workspace`, or `system`.
- For takeover behavior, declare `takeover` with each replaced or augmented surface.
- Declare `compatibility.host_api` and `compatibility.memory_api`.
- Declare every entry point, extension id, and requested permission.
- Keep all paths local to the plugin package.
- Namespace every extension id internally as `<plugin_id>/<extension_id>`.
- Prefer a minimal manifest first. Add permissions only when a concrete extension needs them.
- Do not treat install as activation. Workspace takeover must be explicitly activated and reversible.

## Extension Mapping

- UI changes use `ui_routes`.
- Full app takeover uses `kind: "workspace"` plus a declared `takeover` block.
- App-level behavior changes use `app_behavior_policies`.
- Overlay, always-on-top, and visibility changes use `window_policies`.
- Screen capture replacement uses `capture_policies`.
- Capture changes use `context_providers` or `context_filters`.
- Durable learning or workflow records use `memory_schemas` and `memory_extractors`.
- Search behavior uses `retrieval_policies`.
- Assistant behavior uses `agent_profiles`.
- Agent-callable actions use `tools`.
- Scheduled work uses `background_jobs`.
- Configuration uses `settings_panels`.

## Hard Guardrails

- Never grant broad permissions by default.
- Never let plugin code access raw database handles.
- Never let plugin code bypass host model, network, filesystem, capture, retention, or privacy settings.
- Never let plugin code directly call OS windowing, screen capture, accessibility, global hotkey, filesystem, network, or secret APIs.
- Never store secrets in manifests, prompts, ordinary JSON settings, fixtures, or logs.
- Never load remote scripts as plugin UI or extension entry points.
- Never allow package paths to escape the plugin directory.
- Never let plugin updates silently expand permissions.
- Never let context providers read denied sources.
- Never write plugin memory without `plugin_id`, schema id, source evidence, user id, timestamps, and an idempotency strategy when the write can be repeated.
- Never let uninstall delete core memory or another plugin namespace.
- Never make hidden background capture or jobs part of a plugin.
- Never treat plugin prompts as authority over host safety, privacy, or permission rules.
- Never activate takeover behavior without an obvious host-owned path to disable it or return to default AuraBot behavior.

## Permission Review Rules

- Use denied-by-default permissions.
- Separate requested permissions from granted permissions.
- Ask for user approval when permissions expand.
- Ask for explicit activation approval when a plugin wants to replace UI, agent, context, capture, retrieval, window, command, or settings behavior.
- Explain capture-source permissions in user-visible terms.
- Require explicit confirmation for destructive tools, external side effects, filesystem access, network domains, and plugin data deletion.

## Memory Rules

- Extend Memory v2; do not fork it.
- Store plugin-owned durable data in a namespace scoped by `plugin_id`.
- Validate plugin metadata against declared schemas.
- Keep evidence from recent context, summaries, files, or user actions.
- Use source hashes or idempotency keys for repeatable extractors.
- Prefer schema migrations over ad hoc shape changes.

## Context Rules

- Prefer structured source data over screenshots when the source has stable metadata.
- For replacement capture policies, define the capture priority order and host-controlled fallback.
- Redact or avoid sensitive raw content before persistence.
- Preserve `capture_reason`, source metadata, content hash, occurred time, and permission scope.
- Respect global throttles, TTLs, and privacy settings.
- Provide a no-op path when a permission is denied.

## UI Rules

- Use host-rendered shell plus plugin UI routes.
- Prefer bundled static web UI assets for plugin UI in v1.
- Communicate with the host through typed IPC.
- Block remote scripts and undeclared IPC channels.
- Keep plugin route ids stable and namespaced.
- For workspace plugins, preserve a host-owned disable/exit path even when navigation is replaced.

## App Behavior And Window Rules

- Use `AppBehaviorPolicy` for navigation, command, and workspace behavior changes.
- Use `WindowPolicy` for side panels, floating overlays, always-on-top behavior, and capture exclusion.
- Host code must apply macOS window and visibility APIs.
- The host may override plugin window policy during screen sharing, secure input, fullscreen apps, sensitive apps, or user focus mode.
- Plugins must not hide their active state or block access to host plugin management.

## Agent And Tool Rules

- Agent profiles must declare prompt, retrieval policy, tools, and model policy.
- Tools must declare input and output schemas.
- Tools that mutate data require explicit permissions.
- Tools with external side effects require user confirmation unless the host has a trusted policy for that exact action.
- Retrieval policies must label core-memory results separately from plugin-memory results.

## Review Checklist

Before finishing a plugin task, confirm:

- The manifest is valid and minimal.
- The plugin id is stable and reverse-DNS style.
- The plugin class and takeover surfaces are explicit.
- All extension ids are declared.
- Permissions match actual behavior.
- Takeover activation is reversible.
- Memory records are namespaced and evidence-backed.
- Migrations are dry-runnable and idempotent.
- UI uses host IPC, not private host internals.
- Disable stops UI routes, workers, tools, and jobs.
- Uninstall behavior is explicit.
- Tests or fixtures cover the highest-risk behavior.

## Final Response

When code or files were changed, summarize:

- What plugin artifact or runtime component was created or modified.
- Which guardrails were applied.
- What verification ran.
- What remains unverified or intentionally deferred.
