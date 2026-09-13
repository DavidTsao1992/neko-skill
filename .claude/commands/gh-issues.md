Turn a feature request into a set of atomic GitHub issues with correct dependency order.

## When this applies

The user describes work as a goal ("add SSO", "make the importer resumable") rather than a
single change, and wants it tracked as issues. One self-contained change needs one issue —
don't split what is already atomic.

## Steps

1. **Preflight.** Confirm `gh auth status` is logged in and `gh repo view --json nameWithOwner`
   resolves the intended repo — if the current directory isn't the target repo, ask before
   going further. Then gather what the repo already expects:
   - `gh issue list --state open --limit 50` — existing work, to avoid duplicates
   - `gh label list` — only use labels that already exist; propose new ones, don't invent silently
   - `ls .github/ISSUE_TEMPLATE/` — if templates exist, follow their structure

2. **Understand the request.** Restate the goal in one sentence and name the user-visible
   outcome that marks it done. Ask only about ambiguity that would change the decomposition —
   scope boundaries, whether an existing system is being replaced or extended. Don't
   interrogate; make routine calls yourself and state the assumption.

3. **Survey what exists.** Read the actual code before writing any issue: the modules the work
   touches, current data models, test layout, `AI_MEMORY.md` if present. An issue that asks for
   something already built, or that contradicts the existing architecture, is worse than no
   issue. Note what can be reused.

4. **Decompose into atomic issues.** Each issue must be:
   - **One minimum function** — a vertical slice that does one useful thing end to end, not a
     layer ("add the model", "add the view"). Prefer "persist draft orders" over "add DB table".
   - **Independently mergeable** — merging it alone leaves the repo working and tested. If it
     can't be, it belongs merged with its neighbour or behind a flag.
   - **One PR's worth of work.** If it needs more than a few files' worth of change, split it.
     If it's a one-line tweak, fold it into a sibling.
   - **Verifiable** — acceptance criteria a reviewer can check without asking the author.

5. **Build the dependency graph.** For each issue, list which issues must merge first. Keep it
   a DAG — a cycle means the split is wrong, so go back to step 4 and re-cut it. Topologically
   sort so blockers come first, and flag issues at the same depth as parallelizable.

6. **Show the plan and wait for approval.** Present a table — number, title, depends-on, one-line
   scope — before creating anything. Creating issues is public and noisy to undo, so never skip
   this. Apply the user's edits to the plan and re-confirm if the graph changed.

7. **Create in topological order.** Blockers first — that way every `Blocked by` reference points
   at an issue number that already exists, and no backfill is needed. Body structure (unless a
   repo template says otherwise):

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

   Create with `gh issue create --title "..." --body-file - --label "..."`, piping the body via
   heredoc so markdown survives intact. Record each returned issue number before moving on.

8. **Wire the back-references.** After all issues exist, add `Blocks: #N` to each blocker with
   `gh issue edit <n> --body-file -`, so the graph is navigable from both ends. If the set is
   large enough to need a parent tracking issue, create it and attach real sub-issue links:

   ```bash
   PARENT_ID=$(gh issue view <parent> --json id -q .id)
   gh api graphql -f query='mutation($p:ID!,$u:String!){addSubIssue(input:{issueId:$p,subIssueUrl:$u}){clientMutationId}}' \
     -f p="$PARENT_ID" -f u="https://github.com/<owner>/<repo>/issues/<child>"
   ```

   GitHub has no public API for blocked-by dependencies — those live in the body text above.
   Sub-issues are the only relationship the API models, so use them for parent/child only.

9. **Report and log.** Print each created issue as `#N — title (blocked by …)` with its URL, and
   name which issues are ready to start now. Offer `/memory-log` to record the breakdown.
