#!/usr/bin/env bash
# neko-skill — Claude Code SessionStart hook
#
# Runs at the start of every Claude Code session, in whatever directory
# the session was launched from. It is safe to run repeatedly:
#   - creates .env only if this looks like a Python project and no .env exists yet
#   - creates AI_MEMORY.md only if this is a git repo and it doesn't exist yet
set -uo pipefail

STDIN_JSON="$(cat 2>/dev/null || true)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"

if [ -z "$PROJECT_DIR" ] && [ -n "$STDIN_JSON" ] && command -v python3 &>/dev/null; then
  PROJECT_DIR="$(printf '%s' "$STDIN_JSON" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("cwd", ""))
except Exception:
    print("")
' 2>/dev/null)"
fi

PROJECT_DIR="${PROJECT_DIR:-$PWD}"
cd "$PROJECT_DIR" 2>/dev/null || exit 0

is_python_project() {
  [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "Pipfile" ] || \
  [ -f "setup.py" ] || [ -f ".python-version" ]
}

MESSAGES=()

if is_python_project && [ ! -f ".env" ]; then
  if [ -f ".env.example" ]; then
    cp ".env.example" ".env"
    MESSAGES+=("Created .env from .env.example")
  elif [ -f ".env.sample" ]; then
    cp ".env.sample" ".env"
    MESSAGES+=("Created .env from .env.sample")
  else
    cat > ".env" <<'EOF'
# Auto-created by neko-skill's SessionStart hook.
# No .env.example was found in this project — add the variables it needs below.
EOF
    MESSAGES+=("Created empty .env (no .env.example found — fill in required vars)")
  fi
fi

if [ -d ".git" ] && [ ! -f "AI_MEMORY.md" ]; then
  REPO_NAME="$(basename "$PROJECT_DIR")"
  NOW="$(date +"%Y-%m-%dT%H:%M:%S%z")"
  cat > "AI_MEMORY.md" <<EOF
# AI Memory — $REPO_NAME

## Purpose
<!-- TODO: one paragraph on what this project is and why it exists. Fill in via /memory-sync or by hand. -->

## Log
<!-- Newest entries first. Append via /memory-log. -->
<!-- Format: - <ISO 8601 timestamp> — [Done|Failed|In Progress] Summary (— Notes) -->
- $NOW — [Done] AI_MEMORY.md initialized.
EOF
  MESSAGES+=("Created AI_MEMORY.md — purpose still needs to be filled in")
fi

if [ "${#MESSAGES[@]}" -gt 0 ]; then
  printf '%s\n' "${MESSAGES[@]}"
fi
exit 0
