---
name: document-release
description: Update documentation after shipping code to ensure docs stay synchronized with releases. Use when the user asks to update docs after shipping, mentions documentation debt, or needs to sync README/API docs with new features.
---

# Document Release

Keep documentation synchronized with shipped code. Review what changed, identify doc impact, and update systematically.

## Pre-Flight Check

1. Identify what was shipped:
   ```bash
   git log --oneline <last-release>..HEAD
   git diff <last-release>..HEAD --name-only
   ```

2. Check current docs state:
   - README.md
   - CHANGELOG.md
   - API documentation
   - Configuration guides
   - Example files
   - Migration guides

## Documentation Audit

### Step 1: README Review

Check if README reflects current state:
- [ ] Feature list matches reality
- [ ] Installation instructions still work
- [ ] Quick start example runs
- [ ] Badges and version references current
- [ ] Dependencies/ requirements accurate

### Step 2: API Documentation

For each public API change:
- [ ] New endpoints/methods documented
- [ ] Parameter changes reflected
- [ ] Response examples updated
- [ ] Error codes current
- [ ] Deprecation notices added

### Step 3: Configuration Docs

If config changed:
- [ ] New options documented
- [ ] Default values accurate
- [ ] Environment variables listed
- [ ] Breaking changes flagged

### Step 4: Examples & Tutorials

Verify examples still work:
- [ ] Code samples run without errors
- [ ] Output matches actual behavior
- [ ] Screenshots current (if UI)
- [ ] Links functional

### Step 5: Migration Guide

If breaking changes exist:
- [ ] Migration path documented
- [ ] Before/after code samples
- [ ] Common pitfalls noted
- [ ] Automation scripts provided (if applicable)

## Update Priority

| Priority | Doc Type | Trigger |
|----------|----------|---------|
| **P0** | API reference | Any public API change |
| **P0** | Breaking changes | Major/breaking release |
| **P1** | README quickstart | New features, UX changes |
| **P1** | Configuration | New options, defaults changed |
| **P2** | Examples | Usage patterns changed |
| **P2** | Tutorials | New workflows introduced |
| **P3** | Architecture diagrams | Structural changes |

## Update Process

### For New Features

1. Add to feature list/overview
2. Document API/usage
3. Add code example
4. Update CHANGELOG

### For Changes

1. Find existing documentation
2. Update descriptions
3. Update code samples
4. Add migration note if breaking

### For Removals

1. Remove from feature lists
2. Mark API as deprecated/removed
3. Add migration path
4. Update examples that used it

## Output Format

```markdown
## Documentation Update Report

**Release:** vX.Y.Z
**Files Changed:** N commits affecting docs

---

### ✅ Updated

- [README.md] — Updated feature list, quickstart
- [API.md] — Added new endpoints
- [CONFIG.md] — Documented new options

---

### ⚠️ Needs Manual Review

- [TUTORIAL.md] — Check if examples still work
- [ARCHITECTURE.md] — Verify diagrams current

---

### 📝 CHANGELOG Entry

```
## [X.Y.Z] - YYYY-MM-DD

### Added
- Feature documentation

### Changed
- Updated configuration options

### Deprecated
- Old method (use new method)
```
```

## Common Patterns

**Feature Flag Docs:**
- Document when feature exits flag
- Remove flag mentions after GA

**Beta/Experimental:**
- Clearly mark as experimental
- Add stability warnings
- Document known limitations

**Versioned Docs:**
- Maintain version switcher if multi-version
- Archive old versions appropriately
- Cross-link related versions

## Verification

Before committing:
- [ ] All links work
- [ ] Code samples syntax-highlight correctly
- [ ] No placeholder text remains
- [ ] Version numbers consistent
- [ ] Spell check passed
