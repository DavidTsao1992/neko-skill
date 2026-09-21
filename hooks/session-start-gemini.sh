#!/usr/bin/env bash
# Gemini CLI requires exactly one JSON object on hook stdout.
set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STDIN_JSON="$(cat 2>/dev/null || true)"
PROJECT_DIR=""
if [ -n "$STDIN_JSON" ] && command -v python3 &>/dev/null; then
  PROJECT_DIR="$(printf '%s' "$STDIN_JSON" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("cwd", ""))
except Exception:
    print("")
' 2>/dev/null)"
fi

MESSAGE="$(NEKO_PROJECT_DIR="${PROJECT_DIR:-$PWD}" "$HOOK_DIR/neko-skill-session-start.sh" </dev/null)"
python3 - "$MESSAGE" <<'PYEOF'
import json, sys
message = sys.argv[1]
payload = {"suppressOutput": True}
if message:
    payload["systemMessage"] = message
print(json.dumps(payload))
PYEOF
