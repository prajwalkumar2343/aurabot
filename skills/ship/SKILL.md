---
name: ship
description: Run a fully automated shipping workflow to create PRs and land code. Use when the user says /ship, wants to ship a feature branch, deploy, push, or create a PR. This is non-interactive — do NOT ask for confirmation unless explicitly required by the workflow.
---

# Ship

Fully automated workflow to ship code from a feature branch. Non-interactive — run straight through without confirmation unless explicitly required.

## Stop Conditions (HARD STOPS)

- On base branch (abort immediately)
- Merge conflicts that cannot auto-resolve
- In-branch test failures
- Pre-landing review ASK items needing user judgment
- MINOR or MAJOR version bump needed (ask user)
- Greptile review comments needing user decision
- AI-assessed coverage below minimum threshold (hard gate)
- Plan items NOT DONE with no user override
- Plan verification failures
- TODOS.md missing and user wants to create one (ask)
- TODOS.md disorganized and user wants to reorganize (ask)

## Never Stop For

- Uncommitted changes (always include them)
- Version bump choice (auto-pick MICRO or PATCH)
- CHANGELOG content (auto-generate from diff)
- Commit message approval (auto-commit)
- Multi-file changesets (auto-split into bisectable commits)
- TODOS.md completed-item detection (auto-mark)
- Auto-fixable review findings (fix automatically)
- Test coverage gaps within target threshold

## Step 1: Pre-flight

1. Check current branch. If on base/default branch: **ABORT** — "You're on the base branch. Ship from a feature branch."
2. Run `git status` (never use `-uall`). Include all uncommitted changes automatically.
3. Run `git diff <base>...HEAD --stat` and `git log <base>..HEAD --oneline` to understand what's being shipped.
4. Check review readiness via dashboard.

### Review Readiness Dashboard

Parse review log and display:

```
+====================================================================+
|                    REVIEW READINESS DASHBOARD                       |
+====================================================================+
| Review          | Runs | Last Run            | Status    | Required |
|-----------------|------|---------------------|-----------|----------|
| Eng Review      |  1   | 2026-03-16 15:00    | CLEAR     | YES      |
| CEO Review      |  0   | —                   | —         | no       |
| Design Review   |  0   | —                   | —         | no       |
| Adversarial     |  0   | —                   | —         | no       |
| Outside Voice   |  0   | —                   | —         | no       |
+--------------------------------------------------------------------+
| VERDICT: CLEARED — Eng Review passed                                |
+====================================================================+
```

**Review Tiers:**
- **Eng Review** (required by default): Gates shipping. Can be disabled with `skip_eng_review: true`
- **CEO Review** (optional): Recommend for product/business changes
- **Design Review** (optional): Recommend for UI/UX changes
- **Adversarial** (automatic): Always runs, no config needed
- **Outside Voice** (optional): Never gates shipping

**Verdict Logic:**
- CLEARED: Eng Review has >=1 entry within 7 days with status "clean" OR `skip_eng_review` is true
- NOT CLEARED: Missing, stale (>7 days), or has open issues

**Staleness Detection:**
- Compare review commit against current HEAD
- Display warning if commits exist since review

If Eng Review NOT CLEAR: Print "No prior eng review found — ship will run its own pre-landing review in Step 3.5."
If diff >200 lines: Add "Note: This is a large diff. Consider running /plan-eng-review or /autoplan before shipping."
If CEO Review missing: Mention as informational, do NOT block.
If SCOPE_FRONTEND=true and no design review: Mention lite check runs in Step 3.5, suggest /design-review for full audit.

## Step 1.5: Distribution Pipeline Check

If diff introduces new standalone artifact (CLI binary, library, tool):
- Check for release workflow in `.github/workflows/` or `.gitlab-ci.yml`
- If no pipeline exists: **ASK** user with options: A) Add release workflow now, B) Defer to TODOS.md, C) Not needed

## Step 2: Merge Base Branch

```bash
git fetch origin <base> && git merge origin/<base> --no-edit
```

- Auto-resolve simple conflicts (VERSION, schema.rb, CHANGELOG ordering)
- Complex conflicts: **STOP** and show them

## Step 2.5: Test Framework Bootstrap

Detect runtime and test framework:
- Check for Gemfile, package.json, requirements.txt, go.mod, Cargo.toml, etc.
- Check for existing test configs and directories

If framework detected: Read 2-3 existing tests to learn conventions, skip bootstrap.
If `.gstack/no-test-bootstrap` exists: Skip bootstrap.
If no runtime detected: **ASK** user for runtime.
If runtime detected but no test framework:
1. Research best practices via WebSearch
2. **ASK** user to select framework with recommendation
3. Install, configure, create example tests
4. If installation fails: Debug once, revert if still failing
5. Generate 3-5 real tests for recently changed files
6. Run full suite, fix or revert if failing
7. Add CI/CD test workflow if `.github/` exists

## Step 3: Tests (If Present)

Skip if no test framework detected.

Run tests with coverage:
```bash
# Examples by runtime:
bundle exec rspec --format documentation
npm test -- --coverage
pytest --cov
make test
cargo test
```

- If tests pass: Continue
- If tests fail: Check if pre-existing (compare blame). Pre-existing → triage, not block. New → **STOP**.

## Step 3.4: Coverage Gate (AI-Assessed)

Assess coverage of changed files:
- Read changed files and their tests
- Identify uncovered logic paths
- If coverage <70%: Auto-generate tests OR flag in PR body with plan
- If coverage <50%: **HARD STOP** — ask user to override or add tests

## Step 3.45: Plan Verification

If plan file exists (PLAN.md, plan.json, etc.):
- Check each item's status
- NOT DONE items with no user override: **STOP** and list blockers
- ASK items: Check if resolved, **STOP** if not

## Step 3.5: Pre-landing Review

If Eng Review not CLEAR or stale, run pre-landing review:
- Architecture check: patterns, abstractions, coupling
- Code quality: naming, complexity, duplication
- Test coverage: new code paths covered
- Security: input validation, auth, secrets
- Performance: N+1 queries, lazy loading, async

**Auto-fixable findings** (fix silently):
- Dead code removal
- N+1 query fixes
- Stale comment cleanup
- Import organization

**ASK findings** (stop and ask):
- Architectural concerns
- Security issues
- Breaking changes without migration

## Step 3.6: Greptile Review

If Greptile integration configured:
- Submit diff for review
- Wait for results
- Complex fixes or false positives: **ASK** user
- Simple fixes: Apply automatically

## Step 4: Version Bump

Check if version bump needed:
- Read VERSION or version file
- Analyze diff: breaking changes → MAJOR, features → MINOR, fixes → PATCH/MICRO

**Auto-pick:** MICRO or PATCH for fixes
**Ask:** MINOR or MAJOR (user decides)

Update version file and commit.

## Step 5: CHANGELOG

Auto-generate CHANGELOG entry from diff:
- Categorize: Added, Changed, Deprecated, Removed, Fixed, Security
- Include commit messages as bullet points
- Add version header with date

Commit CHANGELOG update.

## Step 6: Commit Organization

Organize commits for bisectability:
- Logical groupings: features, fixes, refactors, tests, docs
- Each commit should pass tests independently
- Auto-split multi-file changesets

Commit message format:
```
[type]: [subject]

[body describing what and why]
```

## Step 7: TODOS.md Maintenance

If TODOS.md exists:
- Scan for completed items (file changed, TODO resolved)
- Auto-mark completed items with [x] and completion date
- If file becomes disorganized: Offer to reorganize

If TODOS.md missing and project has TODOs in code: **ASK** if user wants to create one.

## Step 8: Final Verification

1. Run tests one final time
2. Verify all commits are made
3. Check branch is clean (except untracked)
4. Verify version bumped if needed
5. Verify CHANGELOG updated

## Step 9: Push and PR

Push branch:
```bash
git push origin <branch>
```

Create PR via API or URL:
```bash
# GitHub
gh pr create --title "..." --body "..."

# Or open URL:
open "https://github.com/<owner>/<repo>/compare/<base>...<branch>"
```

**PR Body Template:**
```markdown
## Summary
[Auto-generated from commits]

## Changes
- [Change 1]
- [Change 2]

## Testing
[Test coverage info]

## Checklist
- [x] Tests pass
- [x] Version bumped (if needed)
- [x] CHANGELOG updated
- [x] Review completed
```

## Output

Print PR URL at the end:
```
✅ Ship complete!

PR URL: https://github.com/<owner>/<repo>/pull/<number>
```

## Configuration

User can set in `~/.gstack/config` or repo `.gstack/config`:
- `skip_eng_review`: true/false — Skip Eng Review gate
- `test_command`: Custom test command
- `coverage_threshold`: 50-100 — Coverage gate threshold (default: 70)
- `auto_fix`: true/false — Auto-apply safe fixes (default: true)
- `version_file`: Path to version file (default: VERSION)
