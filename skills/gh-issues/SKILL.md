---
name: gh-issues
description: Break a feature goal into atomic, independently mergeable GitHub issues with acceptance criteria and an explicit dependency graph.
---

# GitHub Issue Breakdown

1. Confirm authentication and the target repository. Inspect open issues, labels, templates, relevant code, tests, and `AI_MEMORY.md`.
2. Define the user-visible outcome and resolve only ambiguities that change the decomposition.
3. Create vertical slices that are independently mergeable, about one PR each, and objectively verifiable. Avoid layer-only issues and duplicates.
4. Build an acyclic dependency graph and topologically order it, identifying parallel work.
5. Show proposed titles, dependencies, and scope. Wait for explicit approval before creating issues.
6. Follow repository templates, or include Context, Scope, Out of scope, Acceptance criteria, and Dependencies.
7. Create blockers first, then add navigable `Blocked by` and `Blocks` references. Use real sub-issues only for parent-child relationships.
8. Report every created issue with its URL and identify what is ready now. Never invent labels silently.
