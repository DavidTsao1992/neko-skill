---
name: gh-issues
description: Use when the user describes a goal ("add SSO", "make the importer resumable") rather than a single change and wants it tracked as GitHub issues — breaks it into atomic, independently mergeable issues with acceptance criteria and a dependency graph, shows the plan for approval, then creates them blockers first.
---

# GitHub Issue Breakdown

One self-contained change needs one issue — don't split what is already atomic.

1. **Preflight.** `gh auth status` is logged in and `gh repo view --json nameWithOwner` is the
   intended repo; if not, ask. Gather what the repo expects: `gh issue list --state open --limit 50`
   (avoid duplicates), `gh label list` (only existing labels — propose new ones, never invent them
   silently), and `.github/ISSUE_TEMPLATE/` (follow it if present).
2. **Understand the request.** Restate the goal in one sentence and the user-visible outcome that
   marks it done. Ask only about ambiguity that changes the decomposition; make routine calls
   yourself and state the assumption.
3. **Survey what exists.** Read the code the work touches, the data models, the test layout and
   `AI_MEMORY.md` if present. An issue for something already built, or one that contradicts the
   architecture, is worse than none.
4. **Decompose.** Each issue is one *vertical slice* that does one useful thing end to end (not a
   layer like "add the model"), is independently mergeable, is about one PR of work, and has
   acceptance criteria a reviewer can check without asking.
5. **Build the dependency graph.** Keep it acyclic — a cycle means the split is wrong. Order it
   topologically and note which issues can run in parallel.
6. **Show the plan and wait for explicit approval** — a table of title, depends-on and one-line
   scope. Creating issues is public and noisy to undo; never skip this.
7. **Create blockers first**, so every dependency points at an issue that already exists. Use the
   repo's template, or the body structure in [reference.md](reference.md), and record
   dependencies as GitHub blocked-by relationships ([reference.md](reference.md)).
8. **Group large sets.** Make a parent issue and attach the others as sub-issues — parent/child
   only. Never overwrite an issue body to add a reference: append to it.
9. **Report** each issue as `#N — title (blocked by …)` with its URL, name what is ready to start,
   and offer to record the breakdown with the `memory-log` skill.
