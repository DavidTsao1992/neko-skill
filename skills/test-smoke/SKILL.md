---
name: test-smoke
description: Detect and run a repository's Python or Node test suite, then report a concise pass, fail, or skip result.
---

# Smoke Test

1. Detect the runner. For Python with pytest configuration or `tests/`, use the active project virtual environment and run `python -m pytest -v --tb=short`. For Node with a test script, use the package manager indicated by the lockfile. If neither applies, report no runner and do not guess.
2. Capture the summary. On failure, include the first failing test and error.
3. Report `Pass`, `Fail`, or `Skip` (only when every test skipped and none failed).
4. Offer to use `memory-log` only when the run surfaced something notable; never log routine smoke runs automatically.
