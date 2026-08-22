Run this repo's test suite and report a pass/fail summary.

## Steps

1. Detect the test runner for the current project, in this order:
   - **Python**: if `pytest` is available and there's a `tests/` directory, `pytest.ini`, or a `[tool.pytest.ini_options]` section in `pyproject.toml` → run `python -m pytest -v --tb=short`
   - **Node**: if `package.json` has a `"test"` script → run `npm test` (or `yarn test` / `pnpm test` if `yarn.lock` / `pnpm-lock.yaml` is present instead of `package-lock.json`)
   - Otherwise, tell the user no test runner was detected for this project and stop — don't guess.

2. Run the tests, capturing:
   - The summary line (e.g. "5 passed, 1 failed in 3.2s")
   - On failure, the first failing test name and error message

3. Report the result as `Pass` / `Fail` / `Skip` (Skip only if every test was skipped, none failed), plus the summary line.

4. Ask the user whether this run should be logged via `/memory-log`. Don't log automatically — smoke runs are frequent and cheap; logging every one clutters `AI_MEMORY.md`. Only worth logging if it surfaced something notable (a new failure, a fix confirmed).
