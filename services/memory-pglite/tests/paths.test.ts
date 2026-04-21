import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { resolve } from "node:path";
import {
  resolveAuraBotHome,
  resolveEmbeddingDimensions,
  resolvePgliteDir,
} from "../src/config/paths.js";

describe("path configuration", () => {
  it("uses AURABOT_HOME for the default PGlite directory", () => {
    const env = { AURABOT_HOME: "/tmp/custom-aurabot" };
    assert.equal(resolveAuraBotHome(env), "/tmp/custom-aurabot");
    assert.equal(resolvePgliteDir(env), "/tmp/custom-aurabot/pglite/aurabot");
  });

  it("lets AURABOT_PGLITE_DIR override AURABOT_HOME", () => {
    const env = {
      AURABOT_HOME: "/tmp/custom-aurabot",
      AURABOT_PGLITE_DIR: "/tmp/custom-pglite",
    };
    assert.equal(resolvePgliteDir(env), "/tmp/custom-pglite");
  });

  it("lets test directory override all persistent locations", () => {
    const env = {
      AURABOT_HOME: "/tmp/custom-aurabot",
      AURABOT_PGLITE_DIR: "/tmp/custom-pglite",
      AURABOT_PGLITE_TEST_DIR: "/tmp/test-pglite",
    };
    assert.equal(resolvePgliteDir(env), "/tmp/test-pglite");
  });

  it("expands home-relative paths", () => {
    const homeRelative = resolvePgliteDir({ AURABOT_PGLITE_DIR: "~/memory-test" });
    assert.equal(homeRelative.endsWith("/memory-test"), true);
    assert.notEqual(homeRelative, "~/memory-test");
  });

  it("defaults embedding dimensions to text-embedding-3-small dimensions", () => {
    assert.equal(resolveEmbeddingDimensions({}), 1536);
  });

  it("validates configured embedding dimensions", () => {
    assert.equal(resolveEmbeddingDimensions({ AURABOT_MEMORY_EMBEDDING_DIMENSIONS: "768" }), 768);
    assert.throws(
      () => resolveEmbeddingDimensions({ AURABOT_MEMORY_EMBEDDING_DIMENSIONS: "0" }),
      /positive integer/,
    );
    assert.throws(
      () => resolveEmbeddingDimensions({ AURABOT_MEMORY_EMBEDDING_DIMENSIONS: "abc" }),
      /positive integer/,
    );
  });

  it("returns absolute default paths", () => {
    assert.equal(resolveAuraBotHome({}).startsWith(resolve("/")), true);
    assert.equal(resolvePgliteDir({}).startsWith(resolve("/")), true);
  });
});
