# CLAUDE.md — neko-skill

Generic Claude Code tooling: skills + a SessionStart hook for local, per-repo AI memory
(no external service required) and Python environment hygiene. Works on any web or app
project — nothing here is specific to one codebase.

---

## What this package provides

| File | Purpose |
|------|---------|
| `install.sh` | One-command setup — checks `pyenv`/`python3`, installs skills globally, registers the SessionStart hook |
| `hooks/session-start.sh` | Runs at every Claude Code session start; creates `.env` (Python projects only) and `AI_MEMORY.md` if missing |
| `.claude/commands/memory-sync.md` | `/memory-sync` — reads the current repo's `AI_MEMORY.md` before starting a task |
| `.claude/commands/memory-log.md` | `/memory-log` — appends a timestamped entry to `AI_MEMORY.md` after a task |
| `.claude/commands/test-smoke.md` | `/test-smoke` — auto-detects and runs the current repo's test suite |
| `.claude/commands/python-venv.md` | `/python-venv` — ensures Python code runs in a pyenv-backed `.venv`, never system Python |
| `.claude/commands/gh-issues.md` | `/gh-issues` — breaks a feature request into atomic, dependency-ordered GitHub issues |

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
present and `.env` doesn't exist yet, it's created — copied from `.env.example` /
`.env.sample` if either exists, otherwise created empty with a comment header. Non-Python
projects and projects that already have a `.env` are left untouched.

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

Issues are created in topological order, blockers first, so every `Blocked by: #N` reference
points at a number that already exists — no second pass needed. Only the reverse `Blocks:` links
are backfilled afterwards. GitHub's public API models parent/child sub-issues (`addSubIssue`)
but has no blocked-by mutation, so dependencies live in the issue body as text.

---

## Development rules for this repo

- Skills are prompts, not code — keep them concise; token cost matters every time they load.
- `install.sh` must stay idempotent: re-running it should never duplicate hook entries or
  clobber unrelated keys in `~/.claude/settings.json`.
- Nothing in this repo should assume a specific target project, repo name, or external
  service. If you're tempted to hardcode one, it belongs in the target repo's own
  `AI_MEMORY.md`, not here.
- Never hardcode secrets or tokens.
