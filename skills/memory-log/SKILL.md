---
name: memory-log
description: Record a completed, failed, or in-progress task in the current repository's AI_MEMORY.md using a timestamped newest-first entry.
---

# Memory Log

1. If `AI_MEMORY.md` is missing, create the skeleton described by `memory-sync`.
2. Infer from context: Status (`Done`, `Failed`, or `In Progress`), a one-line Summary, and one genuinely useful Note. Omit the note when there is nothing non-obvious.
3. Get the timestamp with `date +"%Y-%m-%dT%H:%M:%S%z"`.
4. Insert directly below `## Log`, newest first: `- <timestamp> — [Status] Summary (— Notes, if any)`.
5. Show the inserted line for verification.
