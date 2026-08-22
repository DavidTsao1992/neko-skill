Append a timestamped entry to this repo's `AI_MEMORY.md` after completing a task.

## Steps

1. If `AI_MEMORY.md` doesn't exist yet in the project root, create it first:

   ```
   # AI Memory — <repo name>

   ## Purpose
   <!-- TODO -->

   ## Log
   <!-- Newest entries first. Append via /memory-log. -->
   ```

2. Gather the following — infer from conversation context first, ask only if genuinely missing:
   - **Status**: `Done` | `Failed` | `In Progress`
   - **Summary**: one line, what was done
   - **Notes**: the single most useful thing for a future agent to know — root cause of a failure, a gotcha, a workaround, or "this works because X". Omit entirely if there's nothing non-obvious to add — don't pad it.

3. Insert one new line directly under the `## Log` heading (newest entry first) in this format:

   ```
   - <ISO 8601 timestamp with offset> — [Status] Summary (— Notes, if any)
   ```

   Get the timestamp with `date +"%Y-%m-%dT%H:%M:%S%z"`.

4. Print the appended line so the user can verify it.
