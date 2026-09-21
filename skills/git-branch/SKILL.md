---
name: git-branch
description: Choose or create the correct Git branch before file-changing work, accounting for existing PRs, dirty state, merged branches, and shared history.
---

# Git Branch Selection

1. Inspect fresh state with `git fetch origin --prune`, `git status --short --branch`, `git branch -vv`, `git worktree list`, and `gh pr status` when available.
2. Route the task: new work gets a new branch from the actual default branch; a fix to unmerged work reuses its branch; an independent default-branch bug gets a separate branch.
3. Before reuse, check GitHub for squash/rebase merges, PR review state, the actual base, and whether the branch is shared or behind.
4. Never stash, discard, rebase, amend published commits, or force-push without appropriate user authorization. Protect dirty work and detached HEADs.
5. Report the branch, whether it was created or reused, its base, and relevant risks. Ask if the correct branch is genuinely ambiguous.
