import path from "node:path";

export const PLUGIN_SCHEMA_VERSION = "aurabot-plugin-v1" as const;

export const PLUGIN_KINDS = ["extension", "workspace", "system"] as const;
export const TAKEOVER_SURFACES = [
  "ui",
  "agent",
  "context",
  "capture",
  "memory",
  "retrieval",
  "window",
  "commands",
  "settings",
] as const;
export const TAKEOVER_MODES = ["none", "augment", "replace"] as const;

export const CONTEXT_SOURCE_PERMISSIONS = [
  "screen",
  "app",
  "browser",
  "repo",
  "file",
  "terminal",
  "system",
] as const;
export const CAPTURE_METHOD_PERMISSIONS = [
  "browser_dom",
  "browser_transcript",
  "app_metadata",
  "selected_text",
  "screen_ocr",
  "screen_vision",
  "screenshot",
] as const;
export const MEMORY_PERMISSIONS = [
  "read_core",
  "search_core",
  "write_plugin_namespace",
  "delete_plugin_namespace",
] as const;
export const APP_BEHAVIOR_PERMISSIONS = [
  "workspace_takeover",
  "replace_navigation",
  "replace_commands",
  "replace_agent",
] as const;
export const WINDOW_PERMISSIONS = [
  "floating_overlay",
  "always_on_top",
  "side_panel",
  "exclude_plugin_ui_from_capture",
] as const;
export const TOOL_PERMISSIONS = ["invoke", "mutate_data", "external_side_effect"] as const;
export const BACKGROUND_JOB_PERMISSIONS = ["scheduled", "event_triggered"] as const;
export const HOST_PERMISSION_VALUES = ["screenRecording", "accessibility", "microphone"] as const;

const PERMISSION_VALUES = {
  context_sources: CONTEXT_SOURCE_PERMISSIONS,
  capture_methods: CAPTURE_METHOD_PERMISSIONS,
  memory: MEMORY_PERMISSIONS,
  app_behavior: APP_BEHAVIOR_PERMISSIONS,
  window: WINDOW_PERMISSIONS,
  tools: TOOL_PERMISSIONS,
  background_jobs: BACKGROUND_JOB_PERMISSIONS,
} as const;

const TAKEOVER_PERMISSION_REQUIREMENTS: Partial<Record<PluginTakeoverSurface, Array<keyof PluginPermissions>>> = {
  ui: ["app_behavior"],
  agent: ["app_behavior"],
  context: ["context_sources"],
  capture: ["capture_methods"],
  memory: ["memory"],
  retrieval: ["memory"],
  window: ["window"],
  commands: ["app_behavior"],
};

export type PluginKind = (typeof PLUGIN_KINDS)[number];
export type PluginTakeoverSurface = (typeof TAKEOVER_SURFACES)[number];
export type PluginTakeoverMode = (typeof TAKEOVER_MODES)[number];
export type ContextSourcePermission = (typeof CONTEXT_SOURCE_PERMISSIONS)[number];
export type CaptureMethodPermission = (typeof CAPTURE_METHOD_PERMISSIONS)[number];
export type MemoryPermission = (typeof MEMORY_PERMISSIONS)[number];
export type AppBehaviorPermission = (typeof APP_BEHAVIOR_PERMISSIONS)[number];
export type WindowPermission = (typeof WINDOW_PERMISSIONS)[number];
export type ToolPermission = (typeof TOOL_PERMISSIONS)[number];
export type BackgroundJobPermission = (typeof BACKGROUND_JOB_PERMISSIONS)[number];
export type HostPermission = (typeof HOST_PERMISSION_VALUES)[number];

export interface PluginAuthor {
  name: string;
  url?: string;
}

export interface PluginCompatibility {
  host_api: string;
  memory_api: "memory-v2";
}

export interface PluginNetworkPermissions {
  mode: "denied" | "host_brokered";
  domains?: string[];
}

export interface PluginFilesystemPermissions {
  mode: "denied" | "scoped_bookmarks";
  paths?: string[];
}

export interface PluginModelPermissions {
  chat?: boolean;
  vision?: boolean;
  embeddings?: boolean;
}

export interface PluginPermissions {
  host_permissions?: HostPermission[];
  context_sources?: ContextSourcePermission[];
  capture_methods?: CaptureMethodPermission[];
  memory?: MemoryPermission[];
  app_behavior?: AppBehaviorPermission[];
  window?: WindowPermission[];
  tools?: ToolPermission[];
  background_jobs?: BackgroundJobPermission[];
  network?: PluginNetworkPermissions;
  filesystem?: PluginFilesystemPermissions;
  models?: PluginModelPermissions;
}

export type PluginTakeover = Partial<Record<PluginTakeoverSurface, PluginTakeoverMode>>;

export interface PluginUiRoute {
  id: string;
  path: string;
  title: string;
  activation?: "workspace_root" | "panel" | "settings";
}

export interface PluginExtensions {
  ui_routes?: PluginUiRoute[];
  app_behavior_policies?: string[];
  window_policies?: string[];
  capture_policies?: string[];
  context_providers?: string[];
  context_filters?: string[];
  memory_schemas?: string[];
  memory_extractors?: string[];
  retrieval_policies?: string[];
  agent_profiles?: string[];
  tools?: string[];
  settings_panels?: string[];
  background_jobs?: string[];
}

export interface PluginInstall {
  migrations?: string[];
  default_enabled?: boolean;
  requires_host_relaunch?: boolean;
}

export interface PluginOnboarding {
  required: boolean;
  title: string;
  detail: string;
  required_host_permissions?: HostPermission[];
  steps?: string[];
}

export interface PluginPresentation {
  workspace_title: string;
  workspace_icon: string;
  workspace_sections: string[];
}

export interface PluginIntegrity {
  signature?: string;
  sha256?: string;
}

export interface PluginManifest {
  schema_version: typeof PLUGIN_SCHEMA_VERSION;
  plugin_id: string;
  name: string;
  version: string;
  description: string;
  kind: PluginKind;
  takeover?: PluginTakeover;
  author?: PluginAuthor;
  compatibility: PluginCompatibility;
  entrypoints: Record<string, string>;
  permissions: PluginPermissions;
  extensions: PluginExtensions;
  onboarding?: PluginOnboarding;
  install?: PluginInstall;
  presentation?: PluginPresentation;
  integrity?: PluginIntegrity;
}

export interface PermissionDiff {
  added: Partial<Record<keyof PluginPermissions, string[]>>;
  removed: Partial<Record<keyof PluginPermissions, string[]>>;
}

export class PluginManifestValidationError extends Error {
  constructor(readonly issues: string[]) {
    super(`Invalid plugin manifest: ${issues.join("; ")}`);
    this.name = "PluginManifestValidationError";
  }
}

export function parsePluginManifest(input: unknown): PluginManifest {
  const issues: string[] = [];
  if (!isObject(input)) {
    throw new PluginManifestValidationError(["manifest must be an object"]);
  }

  const manifest = input as Record<string, unknown>;
  const schemaVersion = requireString(manifest, "schema_version", issues);
  if (schemaVersion !== PLUGIN_SCHEMA_VERSION) {
    issues.push(`schema_version must be ${PLUGIN_SCHEMA_VERSION}`);
  }

  const pluginId = requireString(manifest, "plugin_id", issues);
  if (pluginId && !isValidPluginId(pluginId)) {
    issues.push("plugin_id must be lowercase reverse-DNS style");
  }

  requireString(manifest, "name", issues);
  const version = requireString(manifest, "version", issues);
  if (version && !isValidSemver(version)) {
    issues.push("version must be semver");
  }
  requireString(manifest, "description", issues);

  const kind = requireString(manifest, "kind", issues);
  if (kind && !includes(PLUGIN_KINDS, kind)) {
    issues.push(`kind must be one of ${PLUGIN_KINDS.join(", ")}`);
  }

  validateAuthor(manifest.author, issues);
  validateCompatibility(manifest.compatibility, issues);
  validateEntrypoints(manifest.entrypoints, issues);
  validatePermissions(manifest.permissions, issues);
  validateExtensions(manifest.extensions, issues);
  validateOnboarding(manifest.onboarding, issues);
  validateInstall(manifest.install, issues);
  validatePresentation(manifest.presentation, issues);
  validateIntegrity(manifest.integrity, issues);
  validateTakeover(manifest.takeover, kind as PluginKind, manifest.permissions, issues);

  if (issues.length > 0) {
    throw new PluginManifestValidationError(issues);
  }

  return input as unknown as PluginManifest;
}

export function validatePluginManifest(input: unknown): { ok: true; manifest: PluginManifest } | { ok: false; issues: string[] } {
  try {
    return { ok: true, manifest: parsePluginManifest(input) };
  } catch (error) {
    if (error instanceof PluginManifestValidationError) {
      return { ok: false, issues: error.issues };
    }
    throw error;
  }
}

export function resolvePluginPackagePath(packageRoot: string, relativePath: string): string {
  const issue = unsafePluginRelativePathIssue(relativePath);
  if (issue) {
    throw new PluginManifestValidationError([issue]);
  }

  const root = path.resolve(packageRoot);
  const resolved = path.resolve(root, relativePath);
  const relative = path.relative(root, resolved);
  if (relative.startsWith("..") || path.isAbsolute(relative)) {
    throw new PluginManifestValidationError(["plugin path must stay inside the plugin package"]);
  }
  return resolved;
}

export function diffPluginPermissions(previous: PluginPermissions, next: PluginPermissions): PermissionDiff {
  const added: PermissionDiff["added"] = {};
  const removed: PermissionDiff["removed"] = {};
  for (const group of Object.keys(PERMISSION_VALUES) as Array<keyof typeof PERMISSION_VALUES>) {
    const previousValues = new Set((previous[group] as string[] | undefined) ?? []);
    const nextValues = new Set((next[group] as string[] | undefined) ?? []);
    const addedValues = [...nextValues].filter((value) => !previousValues.has(value));
    const removedValues = [...previousValues].filter((value) => !nextValues.has(value));
    if (addedValues.length > 0) {
      added[group] = addedValues;
    }
    if (removedValues.length > 0) {
      removed[group] = removedValues;
    }
  }
  return { added, removed };
}

export function takeoverRequiresActivation(manifest: PluginManifest): boolean {
  if (manifest.kind !== "workspace" && manifest.kind !== "system") {
    return false;
  }
  return Object.values(manifest.takeover ?? {}).some((mode) => mode === "replace");
}

function validateAuthor(input: unknown, issues: string[]): void {
  if (input === undefined) {
    return;
  }
  if (!isObject(input)) {
    issues.push("author must be an object");
    return;
  }
  requireString(input, "name", issues, "author.name");
  optionalString(input, "url", issues, "author.url");
}

function validateCompatibility(input: unknown, issues: string[]): void {
  if (!isObject(input)) {
    issues.push("compatibility must be an object");
    return;
  }
  requireString(input, "host_api", issues, "compatibility.host_api");
  const memoryApi = requireString(input, "memory_api", issues, "compatibility.memory_api");
  if (memoryApi && memoryApi !== "memory-v2") {
    issues.push("compatibility.memory_api must be memory-v2");
  }
}

function validateEntrypoints(input: unknown, issues: string[]): void {
  if (!isObject(input)) {
    issues.push("entrypoints must be an object");
    return;
  }
  for (const [name, value] of Object.entries(input)) {
    if (!isNonEmptyString(value)) {
      issues.push(`entrypoints.${name} must be a non-empty string`);
      continue;
    }
    const pathIssue = unsafePluginRelativePathIssue(value);
    if (pathIssue) {
      issues.push(`entrypoints.${name}: ${pathIssue}`);
    }
  }
}

function validatePermissions(input: unknown, issues: string[]): void {
  if (!isObject(input)) {
    issues.push("permissions must be an object");
    return;
  }

  for (const [group, allowedValues] of Object.entries(PERMISSION_VALUES)) {
    validateStringArray(input[group], `permissions.${group}`, allowedValues, issues);
  }
  validateStringArray(input.host_permissions, "permissions.host_permissions", HOST_PERMISSION_VALUES, issues);
  validateNetworkPermissions(input.network, issues);
  validateFilesystemPermissions(input.filesystem, issues);
  validateModelPermissions(input.models, issues);
}

function validateNetworkPermissions(input: unknown, issues: string[]): void {
  if (input === undefined) {
    return;
  }
  if (!isObject(input)) {
    issues.push("permissions.network must be an object");
    return;
  }
  const mode = requireString(input, "mode", issues, "permissions.network.mode");
  if (mode && !["denied", "host_brokered"].includes(mode)) {
    issues.push("permissions.network.mode must be denied or host_brokered");
  }
  validateStringArray(input.domains, "permissions.network.domains", undefined, issues);
}

function validateFilesystemPermissions(input: unknown, issues: string[]): void {
  if (input === undefined) {
    return;
  }
  if (!isObject(input)) {
    issues.push("permissions.filesystem must be an object");
    return;
  }
  const mode = requireString(input, "mode", issues, "permissions.filesystem.mode");
  if (mode && !["denied", "scoped_bookmarks"].includes(mode)) {
    issues.push("permissions.filesystem.mode must be denied or scoped_bookmarks");
  }
  validateStringArray(input.paths, "permissions.filesystem.paths", undefined, issues);
}

function validateModelPermissions(input: unknown, issues: string[]): void {
  if (input === undefined) {
    return;
  }
  if (!isObject(input)) {
    issues.push("permissions.models must be an object");
    return;
  }
  for (const key of ["chat", "vision", "embeddings"]) {
    const value = input[key];
    if (value !== undefined && typeof value !== "boolean") {
      issues.push(`permissions.models.${key} must be boolean`);
    }
  }
}

function validateExtensions(input: unknown, issues: string[]): void {
  if (!isObject(input)) {
    issues.push("extensions must be an object");
    return;
  }

  const ids = new Set<string>();
  const extensionArrays = [
    "app_behavior_policies",
    "window_policies",
    "capture_policies",
    "context_providers",
    "context_filters",
    "memory_schemas",
    "memory_extractors",
    "retrieval_policies",
    "agent_profiles",
    "tools",
    "settings_panels",
    "background_jobs",
  ];
  for (const key of extensionArrays) {
    validateExtensionIds(input[key], `extensions.${key}`, ids, issues);
  }
  validateUiRoutes(input.ui_routes, ids, issues);
}

function validateUiRoutes(input: unknown, ids: Set<string>, issues: string[]): void {
  if (input === undefined) {
    return;
  }
  if (!Array.isArray(input)) {
    issues.push("extensions.ui_routes must be an array");
    return;
  }
  for (const [index, route] of input.entries()) {
    if (!isObject(route)) {
      issues.push(`extensions.ui_routes[${index}] must be an object`);
      continue;
    }
    const id = requireString(route, "id", issues, `extensions.ui_routes[${index}].id`);
    if (id) {
      validateExtensionId(id, `extensions.ui_routes[${index}].id`, ids, issues);
    }
    const routePath = requireString(route, "path", issues, `extensions.ui_routes[${index}].path`);
    if (routePath && !routePath.startsWith("/")) {
      issues.push(`extensions.ui_routes[${index}].path must start with /`);
    }
    requireString(route, "title", issues, `extensions.ui_routes[${index}].title`);
    const activation = route.activation;
    if (activation !== undefined && !["workspace_root", "panel", "settings"].includes(String(activation))) {
      issues.push(`extensions.ui_routes[${index}].activation is invalid`);
    }
  }
}

function validateInstall(input: unknown, issues: string[]): void {
  if (input === undefined) {
    return;
  }
  if (!isObject(input)) {
    issues.push("install must be an object");
    return;
  }
  validateStringArray(input.migrations, "install.migrations", undefined, issues);
  for (const migration of (input.migrations as unknown[] | undefined) ?? []) {
    if (typeof migration === "string") {
      const pathIssue = unsafePluginRelativePathIssue(migration);
      if (pathIssue) {
        issues.push(`install.migrations: ${pathIssue}`);
      }
    }
  }
  if (input.default_enabled !== undefined && typeof input.default_enabled !== "boolean") {
    issues.push("install.default_enabled must be boolean");
  }
  if (input.requires_host_relaunch !== undefined && typeof input.requires_host_relaunch !== "boolean") {
    issues.push("install.requires_host_relaunch must be boolean");
  }
}

function validateOnboarding(input: unknown, issues: string[]): void {
  if (input === undefined) {
    return;
  }
  if (!isObject(input)) {
    issues.push("onboarding must be an object");
    return;
  }
  if (typeof input.required !== "boolean") {
    issues.push("onboarding.required must be boolean");
  }
  requireString(input, "title", issues, "onboarding.title");
  requireString(input, "detail", issues, "onboarding.detail");
  validateStringArray(input.required_host_permissions, "onboarding.required_host_permissions", HOST_PERMISSION_VALUES, issues);
  validateStringArray(input.steps, "onboarding.steps", undefined, issues);
}

function validatePresentation(input: unknown, issues: string[]): void {
  if (input === undefined) {
    return;
  }
  if (!isObject(input)) {
    issues.push("presentation must be an object");
    return;
  }
  requireString(input, "workspace_title", issues, "presentation.workspace_title");
  requireString(input, "workspace_icon", issues, "presentation.workspace_icon");
  validateStringArray(input.workspace_sections, "presentation.workspace_sections", undefined, issues);
}

function validateIntegrity(input: unknown, issues: string[]): void {
  if (input === undefined) {
    return;
  }
  if (!isObject(input)) {
    issues.push("integrity must be an object");
    return;
  }
  optionalString(input, "signature", issues, "integrity.signature");
  optionalString(input, "sha256", issues, "integrity.sha256");
}

function validateTakeover(input: unknown, kind: PluginKind, permissionsInput: unknown, issues: string[]): void {
  if (input === undefined) {
    if (kind === "workspace" || kind === "system") {
      issues.push(`${kind} plugins must declare takeover`);
    }
    return;
  }
  if (!isObject(input)) {
    issues.push("takeover must be an object");
    return;
  }
  if (kind === "extension") {
    issues.push("extension plugins cannot declare takeover");
  }

  const permissions = isObject(permissionsInput) ? (permissionsInput as Partial<PluginPermissions>) : {};
  for (const [surface, value] of Object.entries(input)) {
    if (!includes(TAKEOVER_SURFACES, surface)) {
      issues.push(`takeover.${surface} is not a known surface`);
      continue;
    }
    if (!includes(TAKEOVER_MODES, String(value))) {
      issues.push(`takeover.${surface} must be none, augment, or replace`);
      continue;
    }
    if (value === "replace") {
      for (const group of TAKEOVER_PERMISSION_REQUIREMENTS[surface] ?? []) {
        const granted = permissions[group];
        if (!Array.isArray(granted) || granted.length === 0) {
          issues.push(`takeover.${surface} replace requires permissions.${group}`);
        }
      }
    }
  }
}

function validateStringArray(
  input: unknown,
  label: string,
  allowedValues: readonly string[] | undefined,
  issues: string[],
): void {
  if (input === undefined) {
    return;
  }
  if (!Array.isArray(input)) {
    issues.push(`${label} must be an array`);
    return;
  }
  const seen = new Set<string>();
  for (const [index, value] of input.entries()) {
    if (!isNonEmptyString(value)) {
      issues.push(`${label}[${index}] must be a non-empty string`);
      continue;
    }
    if (allowedValues && !allowedValues.includes(value)) {
      issues.push(`${label}[${index}] is not allowed`);
    }
    if (seen.has(value)) {
      issues.push(`${label}[${index}] duplicates ${value}`);
    }
    seen.add(value);
  }
}

function validateExtensionIds(input: unknown, label: string, ids: Set<string>, issues: string[]): void {
  if (input === undefined) {
    return;
  }
  if (!Array.isArray(input)) {
    issues.push(`${label} must be an array`);
    return;
  }
  for (const [index, value] of input.entries()) {
    if (!isNonEmptyString(value)) {
      issues.push(`${label}[${index}] must be a non-empty string`);
      continue;
    }
    validateExtensionId(value, `${label}[${index}]`, ids, issues);
  }
}

function validateExtensionId(value: string, label: string, ids: Set<string>, issues: string[]): void {
  if (!/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/.test(value)) {
    issues.push(`${label} must be lowercase hyphen-case`);
  }
  if (ids.has(value)) {
    issues.push(`${label} duplicates extension id ${value}`);
  }
  ids.add(value);
}

function unsafePluginRelativePathIssue(value: string): string | undefined {
  if (!isNonEmptyString(value)) {
    return "plugin path must be a non-empty string";
  }
  if (/^[a-z][a-z0-9+.-]*:/i.test(value)) {
    return "plugin path must be local, not a URL";
  }
  if (path.isAbsolute(value) || value.startsWith("/") || value.startsWith("\\")) {
    return "plugin path must be relative";
  }
  if (value.includes("\0")) {
    return "plugin path must not contain null bytes";
  }
  const normalized = path.posix.normalize(value.replaceAll("\\", "/"));
  if (normalized === "." || normalized.startsWith("../") || normalized === "..") {
    return "plugin path must not escape the plugin package";
  }
  return undefined;
}

function requireString(input: Record<string, unknown>, key: string, issues: string[], label = key): string | undefined {
  const value = input[key];
  if (!isNonEmptyString(value)) {
    issues.push(`${label} is required`);
    return undefined;
  }
  return value;
}

function optionalString(input: Record<string, unknown>, key: string, issues: string[], label = key): void {
  const value = input[key];
  if (value !== undefined && !isNonEmptyString(value)) {
    issues.push(`${label} must be a non-empty string`);
  }
}

function isObject(input: unknown): input is Record<string, unknown> {
  return typeof input === "object" && input !== null && !Array.isArray(input);
}

function isNonEmptyString(input: unknown): input is string {
  return typeof input === "string" && input.trim().length > 0;
}

function isValidPluginId(value: string): boolean {
  return /^[a-z][a-z0-9]*(?:-[a-z0-9]+)*(?:\.[a-z][a-z0-9]*(?:-[a-z0-9]+)*){2,}$/.test(value);
}

function isValidSemver(value: string): boolean {
  return /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:[-+][0-9A-Za-z.-]+)?$/.test(value);
}

function includes<const T extends readonly string[]>(values: T, value: string): value is T[number] {
  return (values as readonly string[]).includes(value);
}
