Decide which branch to work on before writing any code, and create one when the work is new.

## When this applies

Before the first edit of any task that changes files. Deciding this *after* committing means
rewriting history to fix it, so do it first.

## Steps

1. **Establish the real state.** Run these before deciding anything — a stale local view is the
   most common cause of a wrong call:

   ```bash
   git fetch origin --prune
   git status --short --branch     # dirty files, ahead/behind, detached HEAD
   git branch -vv                  # local branches + their upstreams
   gh pr status                    # PRs for the current branch, if gh is available
   ```

2. **Route the task.** Three cases only:

   - **New development** → always a new branch off the latest default branch. Never start new
     work on the branch of an unrelated feature, and never on the default branch itself.

     ```bash
     git checkout -b <type>/<short-slug> origin/<default-branch>
     ```

     Match the naming convention already in use — read `git branch -r` rather than imposing a
     scheme. Get the default branch from `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`;
     don't assume `main`.

   - **Fixing a bug in work that is still unmerged** → stay on that branch and add commits to it.
     Its PR updates automatically on push. Don't open a second branch to patch a first one unless
     the user asks for a stacked PR.

   - **Fixing a bug that exists independently of the unmerged work** → new branch off the default
     branch, not off the feature branch. Piling it onto the feature branch makes an urgent fix
     wait on an unrelated review. Ask yourself: does this bug reproduce on the default branch? If
     yes, it isn't part of that feature's work.

3. **Confirm before reusing a branch.** State which branch you're about to use and why, and check
   the risks below. If the choice is genuinely ambiguous, ask — branching costs nothing, while
   committing to the wrong branch is expensive to undo.

---

## Risks to check before committing to a branch

**The branch looks unmerged but isn't.** `git branch --merged` misses squash- and rebase-merged
branches, because the merged commits have different SHAs. Adding commits to such a branch replays
already-merged work and produces a PR full of duplicate changes. Ask GitHub, not git:

```bash
gh pr list --state merged --head <branch> --json number,mergedAt,title
```

If that returns anything, treat the branch as finished: branch off the default branch instead, and
suggest deleting the stale local branch.

**The PR is already approved or under review.** Pushing new commits to an approved PR can dismiss
the approval and restart review. Check `gh pr view <n> --json reviewDecision,isDraft`. If it's
approved and the fix isn't small or directly requested by a reviewer, say so and let the user
choose between amending that PR and opening a follow-up.

**The working tree is dirty.** Uncommitted changes follow you across `git checkout` and may block
it outright. Before switching, show the user `git status` and let them decide: commit to the
current branch, `git stash`, or abandon. Never stash or discard someone's uncommitted work on your
own initiative.

**HEAD is detached.** Commits made here are unreachable once you check out anything else. If
`git status` reports a detached HEAD, create a branch from it before doing anything else.

**The branch is shared.** If the upstream branch has commits you didn't write, or the PR has other
participants, never rebase, force-push, or amend published commits — that rewrites history under
someone else. Merge or add commits instead.

**The base branch is not the default branch.** Stacked PRs and gitflow repos base work on another
feature branch or on `develop`. Read `gh pr view <n> --json baseRefName` for the branch you're
extending rather than assuming, and pass `--base` explicitly when opening the PR.

**The branch is behind its base.** A branch cut weeks ago may not reflect current code. Check
`git status -sb` for behind-count and offer to update it — rebase if the branch is unpushed or
solely yours, merge if it's shared or the PR is under review.

**Protected default branch.** If you are somehow on the default branch with changes, don't try to
push; branch first, then push. A rejected push to a protected branch is the symptom, not the
problem.

**Another session or worktree holds the branch.** `git worktree list` shows whether the branch is
checked out elsewhere. Two agents committing to one branch will conflict; pick a different branch
or coordinate.

**Unrelated work already sitting on the branch.** If the branch contains commits outside this
task's scope, the resulting PR is unreviewable. Branch off the default branch and let the
unrelated work ship separately.

---

## Report

Before starting the work, state in one or two lines: the branch you're on, whether you created it
or reused it, what it's based on, and any risk above that applied and how you resolved it.
