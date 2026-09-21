# neko-skill

Portable skills and a SessionStart hook for Claude Code, Gemini CLI, and Codex that give every project you work on:

- **Local, versioned AI memory** — an `AI_MEMORY.md` per repo tracking purpose and a
  timestamped log of what's been done, instead of an external tool like Notion.
- **Automatic `.env` bootstrapping** for Python projects, so environment setup doesn't
  silently break agent-driven development.
- **A smoke-test skill** that auto-detects your test runner (pytest or npm/yarn/pnpm).
- **A Python venv skill** that keeps package installs inside a pyenv-backed `.venv`
  instead of the system interpreter.
- **An issue-breakdown skill** that turns a feature request into atomic GitHub issues,
  each independently mergeable, wired up in dependency order.
- **A branch skill** that picks the right branch before the first edit — new branch for new
  work, existing branch for a fix to something unmerged — and checks the traps around that
  call, like squash-merged branches that still look live.

Works on any web or app repo — nothing here is tied to a specific project.

## Install

```bash
git clone git@github.com:DavidTsao1992/neko-skill.git
cd neko-skill
./install.sh
```

To register a separately running `neko-mcp` HTTP server for Claude Code (user
scope), Gemini CLI, and Codex, set its URL when you run the installer:

```bash
NEKO_MCP_URL=http://<server-address>:8766/mcp ./install.sh
```

Without `NEKO_MCP_URL`, the installer leaves existing MCP connections untouched.
Start `neko-mcp` separately and restart the clients after registration. Re-running
the installer with a URL updates the endpoint.

This installs all six workflows for each supported agent:

| Agent | Skills or commands | SessionStart config |
|---|---|---|
| Claude Code | `~/.claude/commands/*.md` | `~/.claude/settings.json` |
| Gemini CLI | `~/.gemini/skills/<name>/SKILL.md` | `~/.gemini/settings.json` |
| Codex | `~/.agents/skills/<name>/SKILL.md` | `~/.codex/hooks.json` |

It is safe to re-run and preserves unrelated settings without duplicating hook entries.
Codex requires new or changed hooks to be reviewed once with `/hooks` before they run.

## Usage

In any project:

```
1. memory-sync   — load this repo's purpose + recent history before starting
2. git-branch    — make sure you're on the right branch before the first edit
3. do the work
4. memory-log     — append a timestamped entry to AI_MEMORY.md
```

`/test-smoke` can be run any time to check the current repo's test suite.
`/python-venv` can be run any time a task touches Python — it makes sure packages install
into a pyenv-backed `.venv` rather than system Python.
`/gh-issues` takes a feature request, reviews what the repo already has, and files a set of
atomic issues in dependency order — it shows the plan for approval before creating anything.

Claude users invoke these as slash commands. Gemini and Codex select them automatically from a
matching request, or you can activate/mention them explicitly using each tool's skill UI.

See [CLAUDE.md](CLAUDE.md) for implementation details.

## License

[MIT](LICENSE)
