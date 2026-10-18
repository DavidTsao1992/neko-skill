#!/usr/bin/env bash
# Run every tests/test_*.sh; exit non-zero if any of them fails.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
status=0
for test in test_*.sh; do
  echo "=== $test"
  bash "$test" || status=1
  echo
done
exit "$status"
