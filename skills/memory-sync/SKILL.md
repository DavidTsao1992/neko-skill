---
name: memory-sync
description: Load a repository's local AI_MEMORY.md context before starting work, including recent progress, failures, and in-progress tasks.
---

# Memory Sync

Load context from the current repository's local AI memory before starting a task.

1. Look for `AI_MEMORY.md` in the project root. If it does not exist, create it with:

   ```markdown
   # AI Memory — <repo name>

   ## Purpose
   <!-- TODO -->

   ## Log
   <!-- Newest entries first. -->
   ```

   Stop after creating the file so the user can fill in the project purpose.
2. If it exists, summarize in at most 10 bullets: the purpose, the latest 5–8 entries, known `[Failed]` patterns, and `[In Progress]` work.
3. If Purpose is empty or `TODO`, ask for a one-paragraph project description and write it there.
4. If the task changes files, use the `git-branch` skill before the first edit.
5. Present the summary concisely before starting work.
