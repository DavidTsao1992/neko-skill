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

Create with `gh issue create --title "..." --body-file - --label "..."`, piping the body through a
heredoc so the Markdown survives intact. Record each returned number before creating the next.

## Back-references

After all issues exist, add `Blocks: #N` to each blocker with `gh issue edit <n> --body-file -`,
so the graph can be followed from both ends.

## Parent issue and sub-issues

```bash
PARENT_ID=$(gh issue view <parent> --json id -q .id)
gh api graphql -f query='mutation($p:ID!,$u:String!){addSubIssue(input:{issueId:$p,subIssueUrl:$u}){clientMutationId}}' \
  -f p="$PARENT_ID" -f u="https://github.com/<owner>/<repo>/issues/<child>"
```

GitHub has no public API for blocked-by dependencies; sub-issues are the only relationship it
models, so use them for parent/child only and keep dependencies in the body text.
