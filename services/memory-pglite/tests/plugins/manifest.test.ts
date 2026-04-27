import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  PluginManifestValidationError,
  diffPluginPermissions,
  parsePluginManifest,
  resolvePluginPackagePath,
  takeoverRequiresActivation,
  validatePluginManifest,
  type PluginManifest,
} from "../../src/plugins/index.js";

const baseManifest: PluginManifest = {
  schema_version: "aurabot-plugin-v1",
  plugin_id: "com.aurabot.ai-tutor",
  name: "AI Tutor",
  version: "0.1.0",
  description: "Turns AuraBot into an adaptive AI learning coach.",
  kind: "workspace",
  takeover: {
    ui: "replace",
    agent: "replace",
    context: "replace",
    capture: "replace",
    memory: "augment",
    retrieval: "replace",
    window: "replace",
    commands: "replace",
    settings: "augment",
  },
  author: {
    name: "AuraBot",
  },
  compatibility: {
    host_api: "^1.0.0",
    memory_api: "memory-v2",
  },
  entrypoints: {
    ui: "ui/dist/index.html",
    context: "extensions/context.js",
    memory: "extensions/memory.js",
    agent: "extensions/agent.js",
    tools: "extensions/tools.js",
  },
  permissions: {
    context_sources: ["browser", "app", "screen"],
    capture_methods: ["browser_dom", "browser_transcript", "app_metadata", "screen_vision"],
    memory: ["read_core", "search_core", "write_plugin_namespace"],
    app_behavior: ["workspace_takeover", "replace_navigation", "replace_commands", "replace_agent"],
    window: ["floating_overlay", "always_on_top", "exclude_plugin_ui_from_capture"],
    models: {
      chat: true,
      vision: false,
      embeddings: true,
    },
    network: {
      mode: "host_brokered",
      domains: [],
    },
    filesystem: {
      mode: "denied",
      paths: [],
    },
  },
  extensions: {
    ui_routes: [
      {
        id: "dashboard",
        path: "/learn",
        title: "Learn",
        activation: "workspace_root",
      },
    ],
    app_behavior_policies: ["tutor-app-behavior"],
    window_policies: ["tutor-overlay-window"],
    capture_policies: ["learning-capture"],
    context_providers: ["learning-browser-context"],
    memory_schemas: ["learning-memory"],
    memory_extractors: ["learning-extractor"],
    retrieval_policies: ["tutor-session"],
    agent_profiles: ["ai-tutor"],
    tools: ["generate-practice-set", "review-weak-concepts"],
    settings_panels: ["ai-tutor-settings"],
    background_jobs: ["nightly-learning-summary"],
  },
  install: {
    migrations: ["migrations/001-init.json"],
    default_enabled: false,
  },
};

describe("plugin manifest validation", () => {
  it("accepts a workspace takeover manifest with explicit permissions", () => {
    const manifest = parsePluginManifest(baseManifest);

    assert.equal(manifest.plugin_id, "com.aurabot.ai-tutor");
    assert.equal(manifest.kind, "workspace");
    assert.equal(takeoverRequiresActivation(manifest), true);
  });

  it("returns structured validation failures without throwing", () => {
    const result = validatePluginManifest({
      ...baseManifest,
      plugin_id: "Bad Plugin",
      version: "v1",
    });

    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.match(result.issues.join("\n"), /plugin_id must be lowercase reverse-DNS style/);
      assert.match(result.issues.join("\n"), /version must be semver/);
    }
  });

  it("requires workspace plugins to declare takeover surfaces", () => {
    assert.throws(
      () =>
        parsePluginManifest({
          ...baseManifest,
          takeover: undefined,
        }),
      /workspace plugins must declare takeover/,
    );
  });

  it("rejects takeover replace surfaces without matching permission groups", () => {
    assert.throws(
      () =>
        parsePluginManifest({
          ...baseManifest,
          permissions: {
            ...baseManifest.permissions,
            capture_methods: [],
            window: [],
          },
        }),
      (error: unknown) => {
        assert.ok(error instanceof PluginManifestValidationError);
        assert.match(error.message, /takeover.capture replace requires permissions.capture_methods/);
        assert.match(error.message, /takeover.window replace requires permissions.window/);
        return true;
      },
    );
  });

  it("rejects extension plugins that try to declare takeover", () => {
    assert.throws(
      () =>
        parsePluginManifest({
          ...baseManifest,
          kind: "extension",
        }),
      /extension plugins cannot declare takeover/,
    );
  });

  it("rejects unsafe entrypoint and migration paths", () => {
    assert.throws(
      () =>
        parsePluginManifest({
          ...baseManifest,
          entrypoints: {
            ui: "../outside.html",
            agent: "https://example.test/agent.js",
          },
          install: {
            migrations: ["/tmp/migration.json"],
          },
        }),
      (error: unknown) => {
        assert.ok(error instanceof PluginManifestValidationError);
        assert.match(error.message, /entrypoints.ui: plugin path must not escape the plugin package/);
        assert.match(error.message, /entrypoints.agent: plugin path must be local, not a URL/);
        assert.match(error.message, /install.migrations: plugin path must be relative/);
        return true;
      },
    );
  });

  it("rejects unknown permission values and duplicate permissions", () => {
    assert.throws(
      () =>
        parsePluginManifest({
          ...baseManifest,
          permissions: {
            ...baseManifest.permissions,
            context_sources: ["browser", "browser", "email"],
          },
        }),
      (error: unknown) => {
        assert.ok(error instanceof PluginManifestValidationError);
        assert.match(error.message, /permissions.context_sources\[1\] duplicates browser/);
        assert.match(error.message, /permissions.context_sources\[2\] is not allowed/);
        return true;
      },
    );
  });

  it("rejects duplicate extension ids across extension groups", () => {
    assert.throws(
      () =>
        parsePluginManifest({
          ...baseManifest,
          extensions: {
            ...baseManifest.extensions,
            capture_policies: ["dashboard"],
          },
        }),
      /duplicates extension id dashboard/,
    );
  });

  it("resolves local package paths and blocks package escapes", () => {
    const root = "/tmp/aurabot-plugin";
    assert.equal(resolvePluginPackagePath(root, "ui/dist/index.html"), "/tmp/aurabot-plugin/ui/dist/index.html");
    assert.throws(() => resolvePluginPackagePath(root, "../secret.txt"), /must not escape the plugin package/);
    assert.throws(() => resolvePluginPackagePath(root, "file:///tmp/plugin.js"), /must be local, not a URL/);
  });

  it("diffs newly requested permissions for upgrade approval", () => {
    const diff = diffPluginPermissions(
      {
        context_sources: ["browser"],
        memory: ["write_plugin_namespace"],
      },
      {
        context_sources: ["browser", "screen"],
        memory: ["write_plugin_namespace", "search_core"],
        window: ["floating_overlay"],
      },
    );

    assert.deepEqual(diff.added, {
      context_sources: ["screen"],
      memory: ["search_core"],
      window: ["floating_overlay"],
    });
    assert.deepEqual(diff.removed, {});
  });
});
