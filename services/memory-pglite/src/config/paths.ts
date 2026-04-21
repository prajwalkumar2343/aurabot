import { homedir } from "node:os";
import { resolve } from "node:path";

const DEFAULT_HOME_DIR = ".aurabot";
const DEFAULT_PGLITE_RELATIVE_DIR = "pglite/aurabot";

function expandHome(value: string): string {
  if (value === "~") {
    return homedir();
  }

  if (value.startsWith("~/")) {
    return resolve(homedir(), value.slice(2));
  }

  return value;
}

function requiredNonEmpty(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

export function resolveAuraBotHome(env: NodeJS.ProcessEnv = process.env): string {
  const configured = requiredNonEmpty(env.AURABOT_HOME);
  if (configured) {
    return resolve(expandHome(configured));
  }

  return resolve(homedir(), DEFAULT_HOME_DIR);
}

export function resolvePgliteDir(env: NodeJS.ProcessEnv = process.env): string {
  const testDir = requiredNonEmpty(env.AURABOT_PGLITE_TEST_DIR);
  if (testDir) {
    return resolve(expandHome(testDir));
  }

  const configured = requiredNonEmpty(env.AURABOT_PGLITE_DIR);
  if (configured) {
    return resolve(expandHome(configured));
  }

  return resolve(resolveAuraBotHome(env), DEFAULT_PGLITE_RELATIVE_DIR);
}

export function resolveEmbeddingDimensions(env: NodeJS.ProcessEnv = process.env): number {
  const rawValue = requiredNonEmpty(env.AURABOT_MEMORY_EMBEDDING_DIMENSIONS);
  if (!rawValue) {
    return 1536;
  }

  const parsed = Number.parseInt(rawValue, 10);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(
      `AURABOT_MEMORY_EMBEDDING_DIMENSIONS must be a positive integer; got ${rawValue}`,
    );
  }

  return parsed;
}
