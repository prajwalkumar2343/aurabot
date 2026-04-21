# Agent 3 Handoff

Owner: Agent 3

Scope:

- Part 5: Markdown Brain Repository
- Part 6: Markdown Indexing and Promotion Pipeline

Completed subtasks:

- P5.2 Brain directory resolver with `AURABOT_BRAIN_DIR` and `~/.aurabot/brain` fallback.
- P5.3 Brain scaffold command and starter `USER.md` / `PREFERENCES.md` files.
- P5.4 Strict frontmatter parser with recoverable parse errors.
- P5.5 Compiled truth and timeline body splitter using a single body `---` divider.
- P5.6 Wikilink and `slug:` markdown link extraction.
- P5.7 Safe writer with expected-hash conflict result.
- P5.8 Page templates for user, preference, project, person, company, workflow, app, website, repo, file, concept, decision, and timeline.
- P5.9 Parser/scaffold/writer fixtures through unit tests.
- P6.1 Brain page scanner using Part 5 parser output.
- P6.2 Source hash skip for unchanged files.
- P6.3 `brain_pages` upsert and removed-page deletion.
- P6.4 Stable `frontmatter`, `compiled_truth`, and `timeline` chunks.
- P6.5 Optional embedding hook with dimension validation against store config.
- P6.6 Graph extraction job enqueue for changed pages.
- P6.7 Promotion candidate detector for repeated metadata, preferences, and decisions.
- P6.8 Promotion draft format with target slug, suggested edit, timeline entry, confidence, and evidence.
- P6.10 Re-index command plus changed, malformed, deleted, unchanged, and embedding mismatch tests.

Commands added:

```bash
npm run brain:init
npm run brain:sync
```

Tests run:

```bash
npm run build
npm test
```

Both commands passed.

Integration notes:

- `brain:sync` uses `AURABOT_MEMORY_USER_ID` when set and otherwise indexes for `default_user`.
- `brain:sync` returns parser errors and exits non-zero when malformed markdown is found.
- Promotion remains draft-only; no markdown is edited without the safe writer expected-hash path.
- Graph extraction is queued through `memory_jobs` as `extract_brain_page_graph`; Agent 4 can consume that payload by `source`, `source_id`, `slug`, and `source_hash`.
