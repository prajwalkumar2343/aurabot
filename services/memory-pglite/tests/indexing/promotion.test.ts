import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { RecentContextEvent } from "../../src/contracts/index.js";
import { detectPromotionCandidates, promotionDraftToResponse } from "../../src/indexing/index.js";

function event(id: string, content: string, metadata: RecentContextEvent["metadata"]): RecentContextEvent {
  return {
    id,
    user_id: "default_user",
    source: "browser",
    content,
    content_hash: `sha256:${id}`,
    occurred_at: "2026-04-21T09:00:00.000Z",
    created_at: "2026-04-21T09:00:01.000Z",
    metadata,
  };
}

describe("promotion candidate detector", () => {
  it("drafts repeated project references and explicit preferences", () => {
    const drafts = detectPromotionCandidates({
      now: "2026-04-21T10:00:00.000Z",
      events: [
        event("ctx1", "Working on AuraBot indexing.", {
          context: "Code",
          activities: ["editing"],
          key_elements: ["AuraBot"],
          user_intent: "implementation",
          display_num: 1,
          projects: ["AuraBot"],
        }),
        event("ctx2", "Reviewing AuraBot memory contracts.", {
          context: "Browse",
          activities: ["reading"],
          key_elements: ["AuraBot"],
          user_intent: "implementation",
          display_num: 1,
          projects: ["AuraBot"],
        }),
        event("ctx3", "I prefer conservative promotion drafts.", {
          context: "Chat",
          activities: ["conversation"],
          key_elements: ["preference"],
          user_intent: "preference capture",
          display_num: 1,
        }),
      ],
    });

    assert.equal(drafts.some((draft) => draft.target_slug === "projects/aurabot"), true);
    assert.equal(drafts.some((draft) => draft.target_slug === "preferences"), true);

    const response = promotionDraftToResponse(drafts[0]!);
    assert.equal(response.schema_version, "memory-v2");
    assert.equal(response.mode, "draft");
    assert.equal(response.status, "drafted");
  });
});
