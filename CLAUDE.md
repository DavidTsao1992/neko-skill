# CLAUDE.md — danpoints-ai

This repo is the AI package for the [Danpoints](https://github.com/DavidTsao1992/danpoints) project.
It provides Claude Code skills and a one-command installer so any Claude instance can manage Danpoints with shared memory and context.

---

## What this package provides

| File | Purpose |
|------|---------|
| `install.sh` | One-command setup — checks gh CLI auth, installs skills globally |
| `.claude/commands/notion-sync.md` | `/notion-sync` skill — reads AI Task Memory before any task |
| `.claude/commands/notion-log.md` | `/notion-log` skill — writes task result to Notion after completion |
| `.claude/commands/test-smoke.md` | `/test-smoke` skill — runs pytest on danpoints and logs result |

---

## Key references

| Resource | URL |
|----------|-----|
| Danpoints repo | https://github.com/DavidTsao1992/danpoints |
| Notion project plan | https://www.notion.so/Danpoints-AI-modules-386c27d6930f804a9f19f5f5da5c693f |
| AI Task Memory DB | https://app.notion.com/p/59e160ca0a41460d9a141f2a2b47997d |
| Data source ID | `collection://bb259ede-7143-45e4-9e42-a8c244ea18ff` |

---

## Workflow (for Claude working in danpoints)

```
1. /notion-sync          ← load prior task history and known failures
2. develop on feat/fix/chore branch inside ~/work/danpoints
3. gh pr create --base stg --repo DavidTsao1992/danpoints
4. human approves → deploy.yml auto-deploys to PythonAnywhere
5. /test-smoke           ← run tests
6. /notion-log           ← record outcome
```

---

## Development rules for this repo

- Any change to a skill or install.sh → open PR to `main` (this repo has no stg; it is the tooling layer)
- Keep skills concise — they are prompts, not code; token cost matters
- When updating the Notion DB schema, update the data source ID in both skills and this CLAUDE.md
- Never hardcode secrets; install.sh must read credentials from the environment or gh CLI keychain
