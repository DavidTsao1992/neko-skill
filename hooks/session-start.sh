#!/usr/bin/env bash
# neko-skill — portable SessionStart hook
#
# Runs at the start of every Claude Code, Gemini CLI and Codex session, in
# whatever directory the session was launched from. It is safe to run
# repeatedly, and only ever acts at the root of a Git work tree:
#   - creates .env only if this looks like a Python project, nothing named .env
#     exists, and Git would ignore it (NEKO_SKILL_NO_ENV=1 turns this off)
#   - creates AI_MEMORY.md only if nothing named AI_MEMORY.md exists
set -uo pipefail

STDIN_JSON="$(cat 2>/dev/null || true)"
PROJECT_DIR="${NEKO_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}"

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

# The directory is often a repository nobody has read yet — a fresh clone — so
# nothing in it is trusted (#8). A repo that shipped `.env` or `AI_MEMORY.md` as
# a symlink used to have this hook write through it, to wherever it pointed.
# Now a file is created only if no entry of that name exists, symlinks
# included, and with noclobber, so bash opens it O_EXCL: a link that appears
# between the check and the write makes the write fail rather than follow it.
set -o noclobber

# Only at the root of a Git work tree: not in a subdirectory of one, and not in
# a directory that merely contains something called .git.
TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$TOPLEVEL" ] || [ "$(cd "$TOPLEVEL" && pwd -P)" != "$(pwd -P)" ]; then
  exit 0
fi

MESSAGES=()

absent() {  # nothing by that name: no file, directory, or symlink (dangling or not)
  [ ! -e "$1" ] && [ ! -L "$1" ]
}

regular_file() {  # a file in this directory itself, not a link to one somewhere else
  [ -f "$1" ] && [ ! -L "$1" ]
}

is_python_project() {
  [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "Pipfile" ] || \
  [ -f "setup.py" ] || [ -f ".python-version" ]
}

# The template to copy into .env: "" for none, or "!<name>" when the first one
# present is not a plain file — then nothing is copied, not even a later one.
env_template() {
  local candidate
  for candidate in ".env.example" ".env.sample"; do
    if regular_file "$candidate"; then
      printf '%s' "$candidate"
      return
    elif ! absent "$candidate"; then
      printf '!%s' "$candidate"
      return
    fi
  done
}

# .env holds secrets, so it is only created where Git will not pick it up (#9):
# in a repo whose .gitignore misses it, the next `git add -A` would commit
# whatever gets filled in. NEKO_SKILL_NO_ENV=1 turns .env creation off entirely.
if is_python_project && [ "${NEKO_SKILL_NO_ENV:-}" != "1" ]; then
  if ! absent ".env"; then
    [ -L ".env" ] && MESSAGES+=("Skipped .env: it is a symlink")
  elif ! git check-ignore -q .env 2>/dev/null; then
    MESSAGES+=("Skipped .env: it would not be git-ignored — add .env to .gitignore to have it created")
  else
    template="$(env_template)"
    case "$template" in
      "!"*)
        MESSAGES+=("Skipped .env: ${template#!} is not a regular file") ;;
      "")
        if (umask 077 && printf '%s\n' \
              "# Auto-created by neko-skill's SessionStart hook." \
              "# No .env.example was found in this project — add the variables it needs below." \
              > ".env") 2>/dev/null; then
          MESSAGES+=("Created empty .env (no .env.example found — fill in required vars)")
        fi ;;
      *)
        if (umask 077 && cat "$template" > ".env") 2>/dev/null; then
          MESSAGES+=("Created .env from $template")
        fi ;;
    esac
  fi
fi

if ! absent "AI_MEMORY.md"; then
  [ -L "AI_MEMORY.md" ] && MESSAGES+=("Skipped AI_MEMORY.md: it is a symlink")
else
  REPO_NAME="$(basename "$PROJECT_DIR")"
  NOW="$(date +"%Y-%m-%dT%H:%M:%S%z")"
  if printf '%s\n' \
      "# AI Memory — $REPO_NAME" \
      "" \
      "## Purpose" \
      "<!-- TODO: one paragraph on what this project is and why it exists. Fill in via /memory-sync or by hand. -->" \
      "" \
      "## Log" \
      "<!-- Newest entries first. Append via /memory-log. -->" \
      "<!-- Format: - <ISO 8601 timestamp> — [Done|Failed|In Progress] Summary (— Notes) -->" \
      "- $NOW — [Done] AI_MEMORY.md initialized." \
      > "AI_MEMORY.md" 2>/dev/null; then
    MESSAGES+=("Created AI_MEMORY.md — purpose still needs to be filled in")
  fi
fi

if [ "${#MESSAGES[@]}" -gt 0 ]; then
  printf '%s\n' "${MESSAGES[@]}"
fi
exit 0
