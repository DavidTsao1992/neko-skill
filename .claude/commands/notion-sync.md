Fetch context from the Danpoints AI Task Memory database before starting any task.

## References
- AI Task Memory DB: https://app.notion.com/p/59e160ca0a41460d9a141f2a2b47997d
- Data source: collection://bb259ede-7143-45e4-9e42-a8c244ea18ff

## Steps

1. Use the Notion MCP `notion-fetch` tool on the AI Task Memory DB URL to retrieve recent records.

2. If the user mentioned a specific module or task, filter for records with that Module or keyword in Task.

3. Prioritise records where Status = "Failed" — these are known failure patterns to avoid.

4. Summarise findings in ≤10 bullet points:
   - Recently completed work (Done) — avoid duplicating effort
   - Known failures and root cause (Failed + Notes) — avoid repeating the same mistake
   - In-progress work (In Progress) — what is already being worked on

5. Check whether the danpoints-ai package has updates:
   ```
   git -C ~/work/danpoints-ai fetch origin --quiet 2>/dev/null; git -C ~/work/danpoints-ai log HEAD..origin/main --oneline 2>/dev/null | head -5
   ```
   If new commits exist on origin/main, alert the user before proceeding.

Present the summary concisely before starting the task. The goal is context, not exhaustive logging.
