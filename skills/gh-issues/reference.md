# GitHub issue breakdown — reference

## Issue body

Use this unless the repository has its own template:

```
## Context
Why this is needed, one short paragraph. Link the code it touches.

## Scope
- What this issue changes

## Out of scope
- What a reviewer might expect but should not find here, and which issue covers it

## Acceptance criteria
- [ ] Checkable statement of done
- [ ] Test that proves it

## Dependencies
Blocked by: #12, #13
```

Create with `gh issue create --title "..." --body-file - --label "..." --blocked-by 12,13`, piping
the body through a heredoc so the Markdown survives intact. Record each returned number before
creating the next.

## Dependencies

GitHub tracks blocked-by / blocking natively, and shows both directions on each issue.

- **When `gh issue create --help` lists `--blocked-by`:** pass `--blocked-by` when
  creating, or add one later with `gh issue edit <n> --add-blocked-by <m>`. There is nothing to
  backfill: the blocker shows "Blocking" by itself.
- **Otherwise (older gh):** keep the `Blocked by` line in the body, and add `Blocks: #N` to each blocker
  afterwards **by appending to its current body**. `gh issue edit --body-file` *replaces* the
  whole body, so piping in only the new line erases Context, Scope and Acceptance criteria:

  ```bash
  { gh issue view <n> --json body -q .body; printf '\nBlocks: #%s\n' <m>; } \
    | gh issue edit <n> --body-file -
  ```

## Parent issue and sub-issues

```bash
PARENT_ID=$(gh issue view <parent> --json id -q .id)
gh api graphql -f query='mutation($p:ID!,$u:String!){addSubIssue(input:{issueId:$p,subIssueUrl:$u}){clientMutationId}}' \
  -f p="$PARENT_ID" -f u="https://github.com/<owner>/<repo>/issues/<child>"
```

Use sub-issues for parent/child only; dependencies between siblings are blocked-by relationships.
