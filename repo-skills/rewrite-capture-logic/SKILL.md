---
name: rewrite-capture-logic
description: Rewrite or extend AuraBot context-capture logic when the user wants a better app-specific capture method than generic screen capture. Use for repo-local changes to browser, app, or routing capture flows in this codebase, and respect the optional OpenRouter context-collector rewrite policy before proposing or enabling LLM-driven rewrites.
---

# Rewrite Capture Logic

Use this skill when changing how AuraBot captures context for a specific app or workflow.

## Scope

Focus on:

- Adding a better capture path for a specific app than plain screen capture
- Simplifying routing between browser, code, and screen context
- Tightening privacy, dedupe, or transport behavior for browser context
- Gating any LLM-driven collector rewrites behind config policy

Do not use this skill for generic UI edits, memory schema redesign, or unrelated computer-use planning changes.

## Primary Files

Read only the files needed for the request:

- `apps/macos/Sources/AuraBot/ContextRouting/ContextRouter.swift`
- `apps/macos/Sources/AuraBot/Services/BrowserContextService.swift`
- `apps/macos/Sources/AuraBot/Services/BrowserExtensionServer.swift`
- `apps/macos/Sources/AuraBot/Services/ScreenCaptureService.swift`
- `apps/macos/Sources/AuraBot/Models/Config.swift`
- `apps/macos/Sources/AuraBot/Screens/SettingsView.swift`
- `apps/macos/BrowserExtension/chromium/*`

## Workflow

1. Identify the current fallback path.
2. Decide whether the target app should stay on screen capture or get a dedicated collector.
3. Keep the routing rule simple:
   Browser context when a browser-specific collector exists.
   Lightweight structured context only when there is stable app/project context worth storing.
   Otherwise use screen capture.
4. If changing browser capture:
   Prefer extension transport over automation for Chromium.
   Keep payloads small, deduped, and privacy-aware.
5. If adding or enabling LLM-driven collector rewrites:
   Check `LLMConfig.contextCollectorRewrite.enabled`.
   Check the selected OpenRouter chat model against `allowedModels`.
   Do not bypass the policy in code or docs.
6. Validate with the cheapest relevant check:
   `node --check` for extension JS
   `swift build` for macOS app changes

## Guardrails

- Prefer the simplest reliable collector over a clever one.
- Avoid adding broad app heuristics when screen capture is good enough.
- Do not silently capture extra raw text from sensitive or private contexts.
- Keep model thresholds configurable as a list, not hardcoded one-off checks.
- Preserve user intent: app-specific collectors are optional improvements, not mandatory complexity.

## Output Expectations

When you implement changes with this skill:

- Update config and settings if the behavior is user-configurable.
- Keep branch-safe, incremental edits.
- Mention whether the change affects routing, transport, privacy, or policy.
