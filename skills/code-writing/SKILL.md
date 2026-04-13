---
name: code-writing
description: Write, modify, and refactor production code. Use when the user asks to implement a feature, fix a bug, add a function, wire up an integration, clean up code, or otherwise make code changes. Follow a practical implementation workflow and write concise comments while writing code so non-obvious logic is easier to understand.
---

# Code Writing

Implement code changes directly and keep the solution practical, readable, and verified.

## Workflow

1. Read the relevant files before changing anything.
2. Understand the local patterns, naming, and architecture.
3. Make the smallest change that fully solves the request.
4. Write concise comments while writing code, especially around non-obvious logic, edge cases, or tricky control flow.
5. Preserve existing conventions unless there is a strong reason to improve them.
6. Run targeted verification for the changed area when possible.
7. Summarize what changed, what was verified, and any remaining risk.

## Implementation Rules

- Prefer simple control flow over clever abstractions.
- Keep functions focused and avoid mixing unrelated responsibilities.
- Reuse existing helpers and utilities before adding new ones.
- Add comments that explain intent or constraints, not comments that restate obvious code.
- Remove or avoid dead branches, duplicated logic, and placeholder code.
- Match the project's existing testing and error-handling style.

## Comment Guidance

Write comments when:
- The logic is correct but not immediately obvious.
- A workaround or compatibility constraint exists.
- A boundary condition or edge case is easy to miss.
- A future maintainer would reasonably ask "why is this here?"

Avoid comments that only narrate the syntax.

## Verification

- Run the smallest useful test, lint, or build command for the touched code.
- If verification cannot be run, state that clearly with the reason.
