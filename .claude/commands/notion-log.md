Log the result of the current task to the Danpoints AI Task Memory database.

## References
- AI Task Memory DB: https://app.notion.com/p/59e160ca0a41460d9a141f2a2b47997d

## Steps

1. Gather the following — infer from conversation context first, ask only if genuinely missing:
   - **Task**: one-line description of what was done
   - **Module**: which danpoints blueprint — one of: core, users, blog_posts, line_stock, data_guru, ai_slide, destiny, tarot, neko_api, error_pages, infra
   - **Status**: `Done` | `Failed` | `In Progress`
   - **Branch**: run `git -C ~/work/danpoints branch --show-current`
   - **PR URL**: GitHub PR URL if one was opened, blank otherwise
   - **Test Result**: `Pass` | `Fail` | `Skip` (Skip if no tests were run)
   - **Notes**: the single most useful thing for a future Claude instance to know — root cause of failures, gotchas, workarounds, or "this works because X". Vague notes are useless.
   - **Date**: today in YYYY-MM-DD format

2. Use the Notion MCP `notion-create-pages` tool to create a new record in the AI Task Memory DB with the fields above.

3. Print the created record URL so the user can verify.
