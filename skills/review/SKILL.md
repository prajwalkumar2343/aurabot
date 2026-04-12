---
name: review
description: Perform deep code review to find bugs, security vulnerabilities, inefficiencies, and better implementation options. Use when the user asks for code review, diff check, wants to validate code quality, or needs security/performance auditing before merging.
---

# Review

Deep code review workflow. Focus on correctness, security, performance, and identifying better alternatives. Be direct and actionable.

## Review Scope

Analyze for:
1. **Correctness** — Logic errors, edge cases, race conditions
2. **Security** — Vulnerabilities, injection risks, auth flaws, secrets exposure
3. **Performance** — Inefficient algorithms, N+1 queries, unnecessary work
4. **Maintainability** — Complexity, duplication, naming, test coverage
5. **Better Alternatives** — Cleaner patterns, built-in functions, library replacements

## Review Process

### Step 1: Gather Context

```bash
git diff <base>...HEAD
```

Or read files if specific paths provided. Identify:
- Languages and frameworks
- Changed files and scope
- Test coverage of changes

### Step 2: Static Analysis

Check for common issues by pattern:

**Security (CRITICAL):**
- SQL/NoSQL injection points
- XSS vulnerabilities (unescaped output)
- Path traversal (`../` in file paths)
- Command injection (`exec`, `system` with user input)
- Hardcoded secrets, API keys, passwords
- Insecure deserialization
- Missing auth/authz checks
- CORS misconfigurations
- Weak crypto (MD5, SHA1, ECB mode)
- Sensitive data logging

**Performance:**
- Nested loops with O(n²) or worse
- N+1 database queries
- Memory leaks (unclosed resources, event listeners)
- Blocking operations in async contexts
- Large object allocations in loops
- Unnecessary re-renders (React/Vue)
- Missing caching opportunities
- Synchronous file I/O in servers

**Correctness:**
- Null/undefined dereferences
- Off-by-one errors
- Missing error handling
- Race conditions
- TOCTOU issues
- Resource leaks (files, connections)
- Integer overflow
- Timezone/DST bugs

**Maintainability:**
- Functions >50 lines
- Cyclomatic complexity >10
- Deep nesting (>3 levels)
- Magic numbers/strings
- Code duplication
- Inconsistent naming
- Missing type annotations
- Dead code

### Step 3: Alternative Analysis

For each significant implementation:

Ask: "Is there a better way?"

Check:
- Built-in language features vs custom code
- Standard library vs external dependencies
- Established patterns (strategy, factory, etc.)
- Framework idioms (React hooks, Rails conventions, etc.)
- More efficient data structures
- Streaming vs buffering
- Vectorized operations (Python/Rust)

### Step 4: Severity Assessment

Classify each finding:

| Severity | Action Required |
|----------|-----------------|
| **CRITICAL** | Block merge — security vuln, data loss, crash |
| **MAJOR** | Strongly recommend fix — bug, perf issue |
| **MINOR** | Suggest fix — style, minor improvement |
| **NIT** | Optional — preference, not blocking |

### Step 5: Output Format

Structure findings by severity:

```markdown
## Review Summary
**Files:** N changed
**Issues:** X critical, Y major, Z minor
**Verdict:** [APPROVE / APPROVE WITH COMMENTS / REQUEST CHANGES]

---

## 🔴 Critical

### 1. [File:Line] — [Title]
**Issue:** [Description]
**Risk:** [What could go wrong]
**Fix:** [Specific code suggestion]
```

---

## 🟠 Major

### 2. [File:Line] — [Title]
**Issue:** [Description]
**Better Alternative:** [Suggested approach]
**Rationale:** [Why it's better]
```

---

## 🟡 Minor

[List]

---

## 💡 Better Alternatives Found

[Patterns that could improve the code significantly]
```

## Review Heuristics

**Efficiency Priority:**
- Prefer early returns over nested conditionals
- Prefer immutability over mutation
- Prefer composition over inheritance
- Prefer explicit over implicit (except well-known patterns)
- Prefer streaming for large datasets
- Prefer batch operations over individual calls

**Security Priority:**
- Never trust user input
- Always validate at boundaries
- Use parameterized queries
- Escape output appropriately for context
- Apply principle of least privilege
- Fail securely (deny by default)

**When in Doubt:**
- Check OWASP Top 10 for security concerns
- Check language/framework best practices
- Consider the maintainer reading this in 6 months

## Special Cases

**Database Queries:**
- Check for N+1 patterns
- Verify index usage on filtered columns
- Watch for unbounded queries (missing LIMIT)
- Check transaction boundaries

**API Endpoints:**
- Validate input schemas
- Check rate limiting
- Verify auth middleware applied
- Check response serialization efficiency

**Frontend:**
- Verify key props in lists
- Check for memory leaks in effects
- Validate accessibility (alt text, labels)
- Check bundle size impact of new deps

**Async/Concurrency:**
- Check for proper error handling in promises
- Verify timeout handling
- Watch for deadlock potential
- Check cancellation token usage
