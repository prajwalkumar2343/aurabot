---
name: skill-routing
description: Route user requests to specialized skills for better results. Use when the user asks about product ideas, bugs/errors, shipping/deploying, QA/testing, code review, documentation, retrospectives, design systems, visual audits, architecture reviews, checkpoints, or code quality. This skill ensures specialized workflows are invoked instead of ad-hoc answers.
---

# Skill Routing

Route user requests to the appropriate specialized skill as the FIRST action.

## Routing Rules

| User Request | Invoke Skill |
|-------------|--------------|
| Product ideas, "is this worth building", brainstorming | `product-manager` |
| Bugs, errors, "why is this broken", 500 errors | `investigate` |
| Ship, deploy, push, create PR | `ship` |
| Code review, check my diff | `review` |
| Update docs after shipping | `document-release` |
| Design system, brand | `design-consultation` |
| Visual audit, design polish | `design-review` |
| Save progress, checkpoint, resume | `checkpoint` |
| Code quality, health check | `health` |

## Usage

1. Identify which routing rule matches the user's request
2. Immediately invoke the corresponding skill using the `Skill` tool
3. Do NOT answer directly or use other tools first
4. Let the specialized skill handle the request

## Important

- Specialized skills have workflows that produce better results than ad-hoc answers
- Always route as the first action before doing anything else
- If no rule matches, proceed with normal handling
