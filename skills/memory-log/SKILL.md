---
name: memory-log
description: Use after finishing, failing, or pausing a task in a repository — records it as one timestamped, newest-first line in the repo's AI_MEMORY.md, with the single most useful note for the next session.
---

# Memory Log

1. If `AI_MEMORY.md` is missing from the project root, create the skeleton described by the
   `memory-sync` skill first.
2. Infer from the conversation, and ask only if genuinely missing:
   - **Status**: `Done`, `Failed`, or `In Progress`
   - **Summary**: one line — what was done
   - **Notes**: the single most useful thing for a future agent — a failure's root cause, a
     gotcha, a workaround, or "this works because X". Omit it when there is nothing non-obvious;
     don't pad.
3. Get the timestamp with `date +"%Y-%m-%dT%H:%M:%S%z"`.
4. Insert one line directly below `## Log`, newest first:
   `- <timestamp> — [Status] Summary (— Notes, if any)`
5. Show the inserted line so the user can verify it.
