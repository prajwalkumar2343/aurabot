---
name: investigate
description: Systematically debug bugs, errors, crashes, and "why is this broken" issues. Use when the user reports bugs, 500 errors, exceptions, unexpected behavior, performance issues, or any "something is wrong" scenarios. Follow a methodical debugging process.
---

# Investigate

Systematic debugging workflow. Move from symptoms to root cause with structured investigation.

## Investigation Process

### Phase 1: Capture the Symptom

Define what is happening:
- [ ] Exact error message or behavior
- [ ] When it started occurring
- [ ] Frequency (always, sometimes, under load)
- [ ] Environment (prod, staging, local, specific browser/device)
- [ ] Recent changes (deploys, config updates, data imports)

Ask or determine:
- "What did you expect to happen?"
- "What actually happened?"
- "Can you reproduce it?"

### Phase 2: Gather Evidence

Collect all relevant data:

**Logs:**
```bash
# Application logs
tail -n 500 logs/production.log | grep -i error

# System logs
journalctl -u <service> --since "1 hour ago"

# Container logs
docker logs <container> --tail 200
```

**Stack Traces:**
- Full exception with line numbers
- Chain of calls leading to error
- First occurrence vs recent occurrences

**Context:**
- User ID / session data
- Request parameters
- Database state
- Environment variables (sanitized)

**Reproduction Steps:**
- Minimal steps to trigger
- Preconditions required
- Data needed

### Phase 3: Form Hypotheses

Generate possible explanations. Consider:

| Category | Common Causes |
|----------|--------------|
| **Code** | Recent commit, edge case, null pointer, race condition |
| **Data** | Corrupt record, missing value, unexpected format, migration issue |
| **Config** | Wrong env var, feature flag, credential expiration, rate limit |
| **Infra** | Disk full, memory pressure, network timeout, DB connection pool |
| **Dependency** | External API down, library bug, version incompatibility |
| **Security** | Auth token expired, permission change, IP block, rate limiting |

Prioritize by likelihood:
1. Recent changes
2. Common patterns for this error type
3. Environmental factors

### Phase 4: Test Hypotheses

Verify or eliminate each hypothesis:

**Code Hypothesis:**
- Read relevant source files
- Check recent commits: `git log --oneline -20 -- <file>`
- Review diff: `git diff <last-known-good>..HEAD -- <file>`

**Data Hypothesis:**
- Query database for anomalies
- Check data format expectations
- Validate constraints

**Config Hypothesis:**
- Compare env vars: `diff <staging> <production>`
- Check feature flags
- Verify secrets/credentials not expired

**Infra Hypothesis:**
- Check resource usage: `df -h`, `free -m`, `top`
- Verify service status
- Test connectivity

**Dependency Hypothesis:**
- Check external service status pages
- Test API endpoints directly
- Review dependency changelogs

### Phase 5: Isolate Root Cause

Confirm the actual cause:
- Reproduce the issue consistently
- Demonstrate the fix resolves it
- Explain why it happens

### Phase 6: Fix and Verify

Implement the fix:
1. Write minimal fix addressing root cause
2. Add test covering the scenario
3. Verify fix works
4. Check for similar issues elsewhere

## Common Error Patterns

**500 Internal Server Error:**
- Check application logs first
- Look for unhandled exceptions
- Check database connectivity
- Verify recent deployments

**404 Not Found:**
- Route exists but handler missing?
- File path correct?
- Case sensitivity (Linux vs macOS)
- Static asset in right location?

**Database Errors:**
- Connection pool exhausted?
- Query timeout?
- Lock contention?
- Migration not run?

**Performance Issues:**
- N+1 queries?
- Missing indexes?
- Large result sets?
- Blocking operations?

**Authentication Failures:**
- Token expired?
- Clock skew?
- Secret rotated?
- Scope/permission changed?

## Output Format

```markdown
## Investigation Report

**Issue:** [Brief description]
**Severity:** [Critical/High/Medium/Low]
**Status:** [Investigating/Root Cause Found/Fixed]

---

### Symptom
[What is happening]

### Evidence
- Error: `...`
- Log snippet: `...`
- Repro steps: `...`

### Root Cause
[What is actually happening and why]

### Fix
[What needs to change]

### Prevention
[How to avoid this in future]
```

## Tools to Use

**Logs:**
- grep, awk, jq for parsing
- `tail -f` for real-time
- Log aggregation (Datadog, Splunk, CloudWatch)

**Process:**
- strace, dtrace for system calls
- lsof for open files
- netstat, ss for network

**Memory:**
- valgrind, heaptrack for leaks
- Memory profiler in language runtime

**Performance:**
- Profilers (language-specific)
- APM tools (New Relic, Sentry)
- Query analyzers
