# neko-skill

Claude Code skills + a SessionStart hook that give every project you work on:

- **Local, versioned AI memory** — an `AI_MEMORY.md` per repo tracking purpose and a
  timestamped log of what's been done, instead of an external tool like Notion.
- **Automatic `.env` bootstrapping** for Python projects, so environment setup doesn't
  silently break agent-driven development.
- **A smoke-test skill** that auto-detects your test runner (pytest or npm/yarn/pnpm).
- **A Python venv skill** that keeps package installs inside a pyenv-backed `.venv`
  instead of the system interpreter.
- **An issue-breakdown skill** that turns a feature request into atomic GitHub issues,
  each independently mergeable, wired up in dependency order.

Works on any web or app repo — nothing here is tied to a specific project.

## Install

```bash
git clone git@github.com:DavidTsao1992/neko-skill.git
cd neko-skill
./install.sh
```

This installs five skills globally to `~/.claude/commands/` (`/memory-sync`,
`/memory-log`, `/test-smoke`, `/python-venv`, `/gh-issues`) and registers a SessionStart hook in
`~/.claude/settings.json` that runs on every Claude Code session, in whichever
directory it's launched from. It also checks whether `pyenv` and `python3` are
available and tells you if they're missing. Safe to re-run.

## Usage

In any project:

```
1. /memory-sync   — load this repo's purpose + recent history before starting
2. do the work
3. /memory-log     — append a timestamped entry to AI_MEMORY.md
```

`/test-smoke` can be run any time to check the current repo's test suite.
`/python-venv` can be run any time a task touches Python — it makes sure packages install
into a pyenv-backed `.venv` rather than system Python.
`/gh-issues` takes a feature request, reviews what the repo already has, and files a set of
atomic issues in dependency order — it shows the plan for approval before creating anything.

See [CLAUDE.md](CLAUDE.md) for how the memory file, `.env` bootstrapping, `/python-venv`,
and `/gh-issues` work under the hood.

## License

[MIT](LICENSE)
