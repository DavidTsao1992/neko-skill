---
name: git-branch
description: Use before the first file edit of any task in a Git repository, to choose or create the right branch — a new branch for new work, the existing branch for a fix to unmerged work — while checking for squash-merged branches, dirty trees, approved PRs and shared history.
---

# Git Branch Selection

Decide which branch to work on before writing any code. Deciding after committing means
rewriting history to fix it.

1. **Establish the real state.** A stale local view is the most common cause of a wrong call:

   ```bash
   git fetch origin --prune
   git status --short --branch     # dirty files, ahead/behind, detached HEAD
   git branch -vv                  # local branches and their upstreams
   git worktree list               # is the branch checked out elsewhere?
   gh pr status                    # PRs for the current branch, if gh is available
   ```

2. **Route the task.** Three cases only:
   - **New development** → a new branch off the latest default branch, never on an unrelated
     feature branch or on the default branch itself:
     `git checkout -b <type>/<short-slug> origin/<default-branch>`. Get the default branch from
     `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` rather than assuming `main`,
     and follow the naming already in `git branch -r`.
   - **A fix to work that is still unmerged** → stay on that branch and add commits; its PR
     updates on push. Don't open a second branch to patch a first unless asked for a stacked PR.
   - **A bug that exists independently of the unmerged work** → a new branch off the default
     branch. If the bug reproduces on the default branch, it isn't part of that feature.

3. **Before reusing a branch, check the risks** in [reference.md](reference.md): squash- or
   rebase-merged branches that still look live, approved PRs, dirty trees, detached HEAD, shared
   branches, non-default bases, branches behind their base, and worktrees.

4. **Never** stash, discard, rebase, amend published commits, or force-push without the user's
   explicit say-so. If the right branch is genuinely ambiguous, ask — branching costs nothing,
   committing to the wrong branch is expensive to undo.

5. **Report** in one or two lines before starting: the branch, whether it was created or reused,
   its base, and any risk that applied and how it was resolved.
