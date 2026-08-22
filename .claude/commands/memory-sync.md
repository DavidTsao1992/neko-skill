Load context from this repo's local AI memory file before starting any task.

## Steps

1. Look for `AI_MEMORY.md` in the current project root. If it doesn't exist, the SessionStart hook should have created it already — if it's still missing, create it with this skeleton and stop here:

   ```
   # AI Memory — <repo name>

   ## Purpose
   <!-- TODO -->

   ## Log
   <!-- Newest entries first. Append via /memory-log. -->
   ```

2. If found, read it and summarize in ≤10 bullet points:
   - Purpose, in one line
   - The most recent 5–8 log entries
   - Any entries flagged `[Failed]` — known failure patterns to avoid repeating
   - Any entries flagged `[In Progress]` — work that may already be underway elsewhere

3. If the Purpose section is still `TODO` or empty, ask the user for a one-paragraph description of the project and write it in.

4. Present the summary concisely before starting the task — the goal is context, not exhaustive recitation.
