---
name: memory-sync
description: Use at the start of a task in a repository, before making changes — loads the repo's local AI_MEMORY.md (purpose, recent log entries, known failures, work in progress) so earlier sessions' context and mistakes are not lost; creates the file if it is missing.
---

# Memory Sync

Load context from the current repository's local AI memory before starting a task.

1. Look for `AI_MEMORY.md` in the project root. If it is missing, create it and stop, so the
   user can fill in the purpose:

   ```markdown
   # AI Memory — <repo name>

   ## Purpose
   <!-- TODO -->

   ## Log
   <!-- Newest entries first. Append with the memory-log skill. -->
   ```

2. If it exists, summarize it in at most 10 bullets:
   - the purpose, in one line;
   - the most recent 5–8 log entries;
   - entries marked `[Failed]` — failure patterns not to repeat;
   - entries marked `[In Progress]` — work that may already be underway elsewhere.
3. If Purpose is empty or `TODO`, ask for a one-paragraph description of the project and write it in.
4. If the task will change files and a `git-branch` skill is installed, use it before the first edit.
5. Present the summary concisely before starting — the goal is context, not recitation.
