---
name: test-smoke
description: Use when asked to run the tests or check that a Python or Node repository still works — detects the test runner (pytest, or npm/yarn/pnpm test), runs it, and reports a one-line pass, fail, or skip result.
---

# Smoke Test

1. Detect the runner, in this order:
   - **Python**: pytest is available and there is a `tests/` directory, `pytest.ini`, or
     `[tool.pytest.ini_options]` in `pyproject.toml` → run `python -m pytest -v --tb=short` with
     the project's virtual environment (see the `python-venv` skill).
   - **Node**: `package.json` has a `test` script → `npm test`, or `yarn test` / `pnpm test` when
     `yarn.lock` / `pnpm-lock.yaml` is present instead of `package-lock.json`.
   - Otherwise say no test runner was detected and stop — don't guess.
2. Capture the summary line (e.g. "5 passed, 1 failed in 3.2s") and, on failure, the first failing
   test and its error.
3. Report `Pass`, `Fail`, or `Skip` (only when every test was skipped and none failed), with the
   summary line.
4. Offer to record it with the `memory-log` skill only when the run surfaced something notable —
   a new failure, or a fix confirmed. Never log routine runs automatically.
