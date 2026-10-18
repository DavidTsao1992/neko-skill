#!/usr/bin/env bash
# Tests for install.sh. Plain Bash, no framework: run it directly.
#
# install.sh writes into other people's home directories, so every case runs it
# against a throwaway HOME and checks the two promises in CLAUDE.md: re-running
# it never duplicates hooks, and it never clobbers unrelated settings.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS=(gh-issues git-branch memory-log memory-sync python-venv test-smoke)
FAILURES=0
CASES=0

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "  ✗ $*"; FAILURES=$((FAILURES + 1)); }

new_case() {
  CASES=$((CASES + 1))
  echo "• $1"
  HOME_DIR="$WORK/$CASES/home"
  mkdir -p "$HOME_DIR"
}

install() {
  HOME="$HOME_DIR" bash "$ROOT/install.sh" >"$WORK/$CASES/install.log" 2>&1 \
    || fail "install.sh exited non-zero: $(tail -3 "$WORK/$CASES/install.log")"
}

# Number of SessionStart hook entries running `command` in a settings file.
hook_count() {
  python3 - "$1" "$2" <<'PYEOF'
import json, sys
path, command = sys.argv[1:]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
print(sum(
    1
    for group in data.get("hooks", {}).get("SessionStart", [])
    for hook in group.get("hooks", [])
    if hook.get("command") == command
))
PYEOF
}

settings_files() {
  printf '%s\n' \
    "$HOME_DIR/.claude/settings.json" \
    "$HOME_DIR/.gemini/settings.json" \
    "$HOME_DIR/.codex/hooks.json"
}

# ── a clean install ──────────────────────────────────────────────────────────

new_case "installs every skill, command and hook into an empty HOME"
install
for skill in "${SKILLS[@]}"; do
  [ -f "$HOME_DIR/.claude/commands/$skill.md" ] || fail "Claude command $skill missing"
  [ -f "$HOME_DIR/.gemini/skills/$skill/SKILL.md" ] || fail "Gemini skill $skill missing"
  [ -f "$HOME_DIR/.agents/skills/$skill/SKILL.md" ] || fail "Codex skill $skill missing"
done
for hook in .claude/hooks/neko-skill-session-start.sh .gemini/hooks/neko-skill-session-start-gemini.sh \
            .codex/hooks/neko-skill-session-start.sh; do
  [ -x "$HOME_DIR/$hook" ] || fail "$hook missing or not executable"
done
[ "$(hook_count "$HOME_DIR/.claude/settings.json" "$HOME_DIR/.claude/hooks/neko-skill-session-start.sh")" = 1 ] \
  || fail "Claude hook not registered exactly once"
[ "$(hook_count "$HOME_DIR/.gemini/settings.json" "$HOME_DIR/.gemini/hooks/neko-skill-session-start-gemini.sh")" = 1 ] \
  || fail "Gemini hook not registered exactly once"
[ "$(hook_count "$HOME_DIR/.codex/hooks.json" "$HOME_DIR/.codex/hooks/neko-skill-session-start.sh")" = 1 ] \
  || fail "Codex hook not registered exactly once"

# ── idempotent ───────────────────────────────────────────────────────────────

new_case "a second run leaves every settings file byte-for-byte the same"
install
while read -r f; do cp "$f" "$f.first"; done < <(settings_files)
install
while read -r f; do
  cmp -s "$f" "$f.first" || fail "$(basename "$(dirname "$f")")/$(basename "$f") changed on re-run: $(diff "$f.first" "$f" | head -5)"
done < <(settings_files)

# ── unrelated settings survive ───────────────────────────────────────────────

new_case "existing settings and other people's hooks are kept"
mkdir -p "$HOME_DIR/.claude" "$HOME_DIR/.gemini" "$HOME_DIR/.codex"
cat > "$HOME_DIR/.claude/settings.json" <<'EOF'
{"model": "opus", "hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "/usr/local/bin/mine"}]}],
 "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "guard"}]}]}}
EOF
echo '{"theme": "dark", "mcpServers": {"x": {"httpUrl": "http://x/mcp"}}}' > "$HOME_DIR/.gemini/settings.json"
echo '{"hooks": {"SessionStart": [{"matcher": "startup", "hooks": [{"type": "command", "command": "other"}]}]}}' \
  > "$HOME_DIR/.codex/hooks.json"
install
install
python3 - "$HOME_DIR" <<'PYEOF' || fail "unrelated settings were lost (see above)"
import json, sys
home = sys.argv[1]
load = lambda p: json.load(open(f"{home}/{p}", encoding="utf-8"))
claude, gemini, codex = load(".claude/settings.json"), load(".gemini/settings.json"), load(".codex/hooks.json")
problems = []
if claude.get("model") != "opus": problems.append("claude model")
if claude["hooks"].get("PreToolUse", [{}])[0].get("matcher") != "Bash": problems.append("claude PreToolUse")
commands = [h["command"] for g in claude["hooks"]["SessionStart"] for h in g["hooks"]]
if "/usr/local/bin/mine" not in commands: problems.append("claude's own SessionStart hook")
if gemini.get("theme") != "dark" or "x" not in gemini.get("mcpServers", {}): problems.append("gemini settings")
codex_commands = [h["command"] for g in codex["hooks"]["SessionStart"] for h in g["hooks"]]
if "other" not in codex_commands: problems.append("codex's own hook")
for p in problems:
    print(f"    lost: {p}")
sys.exit(1 if problems else 0)
PYEOF

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES failure(s) in $CASES cases"
  exit 1
fi
echo "all $CASES cases passed"
