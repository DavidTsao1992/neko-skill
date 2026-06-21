Run the Danpoints smoke tests and log results to the AI Task Memory database.

## Steps

1. Run the test suite:
   ```
   cd ~/work/danpoints && python -m pytest tests/ -v --tb=short 2>&1
   ```

2. Parse the output:
   - Extract the summary line (e.g. "5 passed, 1 failed in 3.2s")
   - If failures exist, capture the first failing test name and error message

3. Determine test result:
   - All pass → `Pass`
   - Any failure or error → `Fail`
   - All skipped, none failed → `Skip`

4. Log to Notion using `/notion-log` with:
   - **Task**: "Smoke test run"
   - **Module**: infra
   - **Status**: `Done` if Pass/Skip, `Failed` if Fail
   - **Test Result**: as determined above
   - **Branch**: current danpoints branch
   - **Notes**: full pytest summary line + first failure message if any

5. Print the test summary and Notion record URL.
