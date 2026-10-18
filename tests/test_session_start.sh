#!/usr/bin/env bash
# Tests for hooks/session-start.sh. Plain Bash, no framework: run it directly.
#
# Every case builds a throwaway repo next to an "outside" directory, runs the
# hook in the repo, and checks what it wrote — above all, that nothing was
# written outside the repo whatever the repo contains (#8).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/hooks/session-start.sh"
GEMINI_HOOK="$ROOT/hooks/session-start-gemini.sh"
FAILURES=0
CASES=0

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "  ✗ $*"; FAILURES=$((FAILURES + 1)); }

# new_case <name>: a fresh repo at $REPO (a Python project, with git) and an
# empty $OUTSIDE directory standing in for the user's home.
new_case() {
  CASES=$((CASES + 1))
  echo "• $1"
  REPO="$WORK/$CASES/repo"
  OUTSIDE="$WORK/$CASES/outside"
  mkdir -p "$REPO" "$OUTSIDE"
  git -C "$REPO" init -q
  echo "requests" > "$REPO/requirements.txt"
}

run_hook() {  # run_hook [dir] — prints the hook's output
  echo '{}' | NEKO_PROJECT_DIR="${1:-$REPO}" bash "$HOOK"
}

outside_untouched() {
  local left
  left="$(find "$OUTSIDE" -mindepth 1 | sed "s#$OUTSIDE/##" | sort | tr '\n' ' ')"
  [ "$left" = "${1:-}" ] || fail "outside the repo changed: [$left], expected [${1:-}]"
}

# ── the normal cases still work ──────────────────────────────────────────────

new_case "creates .env from .env.example and AI_MEMORY.md"
echo "KEY=value" > "$REPO/.env.example"
out="$(run_hook)"
[ "$(cat "$REPO/.env" 2>/dev/null)" = "KEY=value" ] || fail ".env not copied from .env.example"
[ "$(stat -f %Lp "$REPO/.env" 2>/dev/null || stat -c %a "$REPO/.env")" = "600" ] || fail ".env is not mode 600"
grep -q "^# AI Memory — repo$" "$REPO/AI_MEMORY.md" 2>/dev/null || fail "AI_MEMORY.md not created"
[[ "$out" == *"Created .env from .env.example"* ]] || fail "no message for .env: $out"

new_case "creates a commented .env when there is no template"
run_hook >/dev/null
grep -q "Auto-created by neko-skill" "$REPO/.env" 2>/dev/null || fail "empty .env not created"

new_case "a second run changes nothing and says nothing"
run_hook >/dev/null
before="$(cat "$REPO/.env" "$REPO/AI_MEMORY.md")"
out="$(run_hook)"
[ -z "$out" ] || fail "second run printed: $out"
[ "$(cat "$REPO/.env" "$REPO/AI_MEMORY.md")" = "$before" ] || fail "second run rewrote a file"

new_case "a non-Python repo gets AI_MEMORY.md but no .env"
rm "$REPO/requirements.txt"
run_hook >/dev/null
[ -e "$REPO/.env" ] && fail ".env created in a non-Python repo"
[ -f "$REPO/AI_MEMORY.md" ] || fail "AI_MEMORY.md not created"

# ── symlinks in the repo are never followed (#8) ─────────────────────────────

new_case ".env as a dangling symlink"
echo "PAYLOAD" > "$REPO/.env.example"
ln -s "$OUTSIDE/.zshenv" "$REPO/.env"
out="$(run_hook)"
outside_untouched
[[ "$out" == *"Skipped .env: it is a symlink"* ]] || fail "no skip message: $out"

new_case ".env as a symlink to an existing file"
echo "PAYLOAD" > "$REPO/.env.example"
echo "original" > "$OUTSIDE/target"
ln -s "$OUTSIDE/target" "$REPO/.env"
run_hook >/dev/null
[ "$(cat "$OUTSIDE/target")" = "original" ] || fail "symlink target was overwritten"

new_case "AI_MEMORY.md as a dangling symlink"
ln -s "$OUTSIDE/notes" "$REPO/AI_MEMORY.md"
out="$(run_hook)"
outside_untouched
[[ "$out" == *"Skipped AI_MEMORY.md: it is a symlink"* ]] || fail "no skip message: $out"

new_case "AI_MEMORY.md as a symlink to an existing file"
echo "original" > "$OUTSIDE/notes"
ln -s "$OUTSIDE/notes" "$REPO/AI_MEMORY.md"
run_hook >/dev/null
[ "$(cat "$OUTSIDE/notes")" = "original" ] || fail "symlink target was overwritten"

new_case ".env.example as a symlink to a file outside the repo"
echo "SECRET=from-outside" > "$OUTSIDE/secret"
ln -s "$OUTSIDE/secret" "$REPO/.env.example"
echo "OTHER=1" > "$REPO/.env.sample"
out="$(run_hook)"
[ -e "$REPO/.env" ] && fail ".env created from a symlinked template (or the next one): $(cat "$REPO/.env")"
[[ "$out" == *"Skipped .env: .env.example is not a regular file"* ]] || fail "no skip message: $out"

new_case ".env.example as a directory"
mkdir "$REPO/.env.example"
run_hook >/dev/null
[ -e "$REPO/.env" ] && fail ".env created although .env.example is a directory"

# ── only at the root of a real work tree ─────────────────────────────────────

new_case "a subdirectory of a repo is left alone"
mkdir "$REPO/sub" && echo "x" > "$REPO/sub/requirements.txt"
run_hook "$REPO/sub" >/dev/null
[ -n "$(ls -A "$REPO/sub" | grep -v '^requirements.txt$')" ] && fail "wrote into a subdirectory: $(ls -A "$REPO/sub")"

new_case "a directory with a fake .git is left alone"
rm -rf "$REPO/.git" && echo "not a repo" > "$REPO/.git"
run_hook >/dev/null
[ -e "$REPO/.env" ] || [ -e "$REPO/AI_MEMORY.md" ] && fail "wrote into a directory that is not a work tree"

new_case "a directory outside any repo is left alone"
rm -rf "$REPO/.git"
run_hook >/dev/null
[ -e "$REPO/.env" ] || [ -e "$REPO/AI_MEMORY.md" ] && fail "wrote outside a Git work tree"

# ── the Gemini wrapper still prints exactly one JSON object ──────────────────

new_case "Gemini wrapper output is one JSON object"
hooks="$WORK/$CASES/hooks"
mkdir -p "$hooks"
cp "$HOOK" "$hooks/neko-skill-session-start.sh"
cp "$GEMINI_HOOK" "$hooks/neko-skill-session-start-gemini.sh"
out="$(printf '{"cwd": "%s"}' "$REPO" | bash "$hooks/neko-skill-session-start-gemini.sh")"
printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "Created AI_MEMORY.md" in d["systemMessage"], d' \
  || fail "not one JSON object with the message: $out"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES failure(s) in $CASES cases"
  exit 1
fi
echo "all $CASES cases passed"
