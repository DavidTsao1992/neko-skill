# CLAUDE.md — neko-skill

Generic Claude Code, Gemini CLI, and Codex tooling: skills + a SessionStart hook for local, per-repo AI memory
(no external service required) and Python environment hygiene. Works on any web or app
project — nothing here is specific to one codebase.

---

## What this package provides

| File | Purpose |
|------|---------|
| `install.sh` | One-command setup — checks `pyenv`/`python3`, installs skills globally, registers the SessionStart hook |
| `hooks/session-start.sh` | Runs at every Claude Code, Gemini CLI and Codex session start; at the root of a Git work tree, creates `.env` (Python projects only) and `AI_MEMORY.md` if missing |
| `skills/memory-sync/` | `memory-sync` — reads the current repo's `AI_MEMORY.md` before starting a task |
| `skills/memory-log/` | `memory-log` — appends a timestamped entry to `AI_MEMORY.md` after a task |
| `skills/test-smoke/` | `test-smoke` — auto-detects and runs the current repo's test suite |
| `skills/python-venv/` | `python-venv` — ensures Python code runs in a pyenv-backed `.venv`, never system Python |
| `skills/gh-issues/` | `gh-issues` — breaks a feature request into atomic, dependency-ordered GitHub issues (`reference.md`: body template, sub-issue API) |
| `skills/git-branch/` | `git-branch` — picks or creates the right branch before any edit (`reference.md`: the risk checklist) |
| `legacy/claude-commands.sha256` | Hashes of the old `.claude/commands/*.md` files, so `install.sh` removes only unedited copies |
| `hooks/session-start-gemini.sh` | JSON-output wrapper required by Gemini CLI hooks |
| `tests/` | Plain-Bash tests for the hook and `install.sh` — `bash tests/run.sh` runs them all |
| `.github/workflows/ci.yml` | `shellcheck` plus the tests on Ubuntu and macOS, for every PR |

---

## How memory works

Each project gets its own `AI_MEMORY.md` at the directory Claude Code was launched from
(created automatically by the SessionStart hook the first time, if that directory is a
git repo). It has two sections:

- **Purpose** — one paragraph on what the project is for. Filled in on first real use via
  `/memory-sync`, not hardcoded by this toolkit.
- **Log** — timestamped, newest-first entries appended by `/memory-log`: what was done,
  status (`Done`/`Failed`/`In Progress`), and any gotcha worth a future agent knowing.

This replaces any external memory store (e.g. Notion) — everything lives in the target
repo itself, versioned alongside the code.

---

## How `.env` handling works

On every session start, the hook checks the launch directory for Python project markers
(`requirements.txt`, `pyproject.toml`, `Pipfile`, `setup.py`, `.python-version`). If one is
present, `.env` doesn't exist yet, and `git check-ignore` says Git would ignore it, it's
created (mode 600) — copied from `.env.example` / `.env.sample` if either exists, otherwise
created empty with a comment header. Non-Python projects and projects that already have a
`.env` are left untouched. In a repo whose `.gitignore` doesn't cover `.env` it is skipped with
a message: a secrets file Git would track is one `git add -A` from being committed (#9).
`NEKO_SKILL_NO_ENV=1` turns `.env` creation off entirely.

The hook acts only at the root of a Git work tree, and treats that directory as untrusted —
it is often a clone nobody has read yet. It never follows a symlink: if `.env`,
`AI_MEMORY.md`, `.env.example` or `.env.sample` is a link (or not a plain file), it skips that
file and says so, and it creates files with `noclobber` so a link that appears mid-run makes
the write fail rather than land outside the repo (#8).

`install.sh` separately checks whether `pyenv` is installed (informational only — it warns
but doesn't fail, since not every project needs Python).

---

## How `/python-venv` works

This is separate from the `.env` bootstrapping above — `.env` holds config/secrets,
`/python-venv` governs where packages get installed. When invoked, it makes sure any
Python in the project runs inside a `.venv` built from a pyenv-managed interpreter (never
system Python), and that installs go through that venv's own `pip` rather than
`source`-based activation, since each Bash call in Claude Code starts a fresh shell.

---

## How `/gh-issues` works

Takes a goal-shaped request ("add SSO") and turns it into a set of issues where each one is a
minimum *function* — a vertical slice that merges on its own and leaves the repo working —
rather than a layer ("add the model", "add the view"). It reads the existing code first so it
doesn't file work that's already done, builds a DAG of what blocks what, and shows the plan for
approval before creating anything.

Issues are created in topological order, blockers first, so every dependency points at a number
that already exists. Dependencies are GitHub's native blocked-by relationships
(`gh issue create --blocked-by`), which show on both issues with no backfill; with an older `gh`
they fall back to body text, appended to the existing body, never replacing it. Parent/child
grouping uses sub-issues.

---

## How `/git-branch` works

Answers one question before the first edit: which branch does this work belong on? New
development always gets a fresh branch off the latest default branch. A bug in work that is still
unmerged goes onto that existing branch, so its PR updates in place. A bug that reproduces on the
default branch — independent of the unmerged work — gets its own branch, so an urgent fix isn't
held hostage by an unrelated review.

The bulk of the skill is the risk checklist, because the failure modes are mostly invisible from
`git status`. The sharpest one: `git branch --merged` does not detect squash- or rebase-merged
branches, since the merged commits carry different SHAs — so a finished branch looks live, and
adding to it replays already-merged work. The skill asks GitHub instead
(`gh pr list --state merged --head <branch>`). Others worth knowing: pushing to an approved PR can
dismiss the approval; uncommitted changes follow you across a checkout; detached HEAD makes new
commits unreachable; and stacked or gitflow repos don't base on the default branch at all.

`/memory-sync` points at this skill so the branch decision happens at task start, not after the
first commit — deciding late means rewriting history to correct it.

---

## Development rules for this repo

- Skills are prompts, not code — keep them concise; token cost matters every time they load.
  `skills/<name>/SKILL.md` is the only copy of each one, for all three agents: steps in
  SKILL.md, long reference material in a `reference.md` beside it that SKILL.md links to.
  Descriptions say *when* to use the skill ("Use when …"), since agents select skills by them.
- `install.sh` must stay idempotent: re-running it should never duplicate hooks or clobber
  unrelated Claude, Gemini, or Codex settings.
  `tests/test_install.sh` checks both; keep it passing.
- Run `bash tests/run.sh` and `shellcheck install.sh hooks/*.sh tests/*.sh` before pushing —
  CI runs the same.
- Nothing in this repo should assume a specific target project, repo name, or external
  service. If you're tempted to hardcode one, it belongs in the target repo's own
  `AI_MEMORY.md`, not here.
- Never hardcode secrets or tokens.
- The hook runs in repositories the user has not reviewed. Never follow a symlink or write
  outside the project directory, and add a case to `tests/test_session_start.sh` for any new
  file it writes.
