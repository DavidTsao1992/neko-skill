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

install() {  # install [args…] — output in $WORK/$CASES/install.log
  env -u XDG_STATE_HOME HOME="$HOME_DIR" bash "$ROOT/install.sh" "$@" >"$WORK/$CASES/install.log" 2>&1 \
    || fail "install.sh $* exited non-zero: $(tail -3 "$WORK/$CASES/install.log")"
}

# A settings file as canonical JSON, so formatting differences don't count.
canonical() {
  python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1])), sort_keys=True))' "$1"
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

new_case "installs every skill and hook into an empty HOME"
install
for skill in "${SKILLS[@]}"; do
  for dir in .claude/skills .gemini/skills .agents/skills; do
    [ -f "$HOME_DIR/$dir/$skill/SKILL.md" ] || fail "$dir/$skill/SKILL.md missing"
  done
done
for dir in .claude/skills .gemini/skills .agents/skills; do
  for skill in git-branch gh-issues; do  # the skills that link to a reference file
    [ -f "$HOME_DIR/$dir/$skill/reference.md" ] || fail "$dir/$skill/reference.md missing"
  done
done
[ -e "$HOME_DIR/.claude/commands" ] && fail "installed into ~/.claude/commands"
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

# ── the old Claude commands are replaced, but only ones neko-skill shipped (#12) ─

new_case "a command neko-skill shipped is removed; an edited one is kept"
mkdir -p "$HOME_DIR/.claude/commands"
git -C "$ROOT" show 4245472:.claude/commands/memory-sync.md > "$HOME_DIR/.claude/commands/memory-sync.md"
git -C "$ROOT" show 4245472:.claude/commands/git-branch.md > "$HOME_DIR/.claude/commands/git-branch.md"
echo "my own tweak" >> "$HOME_DIR/.claude/commands/git-branch.md"
echo "mine" > "$HOME_DIR/.claude/commands/deploy.md"
install
[ -e "$HOME_DIR/.claude/commands/memory-sync.md" ] && fail "shipped memory-sync command not removed"
[ -f "$HOME_DIR/.claude/commands/git-branch.md" ] || fail "user-edited git-branch command was deleted"
[ -f "$HOME_DIR/.claude/commands/deploy.md" ] || fail "an unrelated command was deleted"
grep -q "kept $HOME_DIR/.claude/commands/git-branch.md" "$WORK/$CASES/install.log" || fail "no warning about the kept command"

# ── the user's edits are never silently overwritten (#13) ────────────────────

new_case "an edited skill is backed up before it is replaced, and the output says so"
install
skill="$HOME_DIR/.claude/skills/git-branch/SKILL.md"
echo "my own rule" >> "$skill"
edited="$(cat "$skill")"
install
[ "$(cat "$skill.bak" 2>/dev/null)" = "$edited" ] || fail "the edited copy was not kept as SKILL.md.bak"
cmp -s "$skill" "$ROOT/skills/git-branch/SKILL.md" || fail "the skill was not updated"
grep -q "$skill.bak" "$WORK/$CASES/install.log" || fail "the output does not mention the backup"

new_case "a second backup does not overwrite the first"
install
skill="$HOME_DIR/.claude/skills/git-branch/SKILL.md"
echo "edit one" >> "$skill"; install
echo "edit two" >> "$skill"; install
[ "$(find "$HOME_DIR/.claude/skills/git-branch" -name 'SKILL.md.bak*' | wc -l | tr -d ' ')" = 2 ] \
  || fail "expected two backups: $(ls "$HOME_DIR/.claude/skills/git-branch")"

new_case "a backup never replaces an earlier one, whatever names are taken"
install
skill="$HOME_DIR/.claude/skills/git-branch/SKILL.md"
echo "old backup" > "$skill.bak"
echo "older backup" > "$skill.bak.1"
echo "edit" >> "$skill"; install
if [ "$(cat "$skill.bak")" != "old backup" ] || [ "$(cat "$skill.bak.1")" != "older backup" ]; then
  fail "an existing backup was replaced"
fi
grep -q "^edit$" "$skill.bak.2" 2>/dev/null || fail "the new backup is not at SKILL.md.bak.2"

new_case "a file a previous install wrote but this release dropped is cleaned up"
install
manifest="$HOME_DIR/.local/state/neko-skill/installed.sha256"
for name in old-skill edited-skill; do
  mkdir -p "$HOME_DIR/.claude/skills/$name"
  echo "shipped once" > "$HOME_DIR/.claude/skills/$name/SKILL.md"
  printf '%s  %s\n' "$(python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' \
    "$HOME_DIR/.claude/skills/$name/SKILL.md")" "$HOME_DIR/.claude/skills/$name/SKILL.md" >> "$manifest"
done
echo "my change" >> "$HOME_DIR/.claude/skills/edited-skill/SKILL.md"
install
[ -e "$HOME_DIR/.claude/skills/old-skill" ] && fail "the dropped, unchanged file was left behind"
[ -f "$HOME_DIR/.claude/skills/edited-skill/SKILL.md" ] || fail "a dropped file the user changed was removed"
grep -q "kept $HOME_DIR/.claude/skills/edited-skill/SKILL.md" "$WORK/$CASES/install.log" || fail "no message about the kept file"
grep -q "old-skill" "$manifest" && fail "the dropped file is still in the manifest"

new_case "unchanged installs are upgraded without backups"
install
install
[ -z "$(find "$HOME_DIR" -name '*.bak*')" ] || fail "re-install made backups: $(find "$HOME_DIR" -name '*.bak*')"

new_case "a stock copy from an earlier release is upgraded without a backup"
mkdir -p "$HOME_DIR/.gemini/skills/git-branch" "$HOME_DIR/.claude/hooks"
git -C "$ROOT" show 4245472:skills/git-branch/SKILL.md > "$HOME_DIR/.gemini/skills/git-branch/SKILL.md"
git -C "$ROOT" show 4245472:hooks/session-start.sh > "$HOME_DIR/.claude/hooks/neko-skill-session-start.sh"
install
[ -z "$(find "$HOME_DIR" -name '*.bak*')" ] || fail "backed up a stock copy: $(find "$HOME_DIR" -name '*.bak*')"
cmp -s "$HOME_DIR/.gemini/skills/git-branch/SKILL.md" "$ROOT/skills/git-branch/SKILL.md" || fail "not upgraded"

# ── --uninstall removes exactly what install.sh added (#13) ──────────────────

new_case "--uninstall restores the settings and removes the files"
mkdir -p "$HOME_DIR/.claude" "$HOME_DIR/.codex"
echo '{"model": "opus", "hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "mine"}]}]}}' \
  > "$HOME_DIR/.claude/settings.json"
echo '{"hooks": {"SessionStart": [{"matcher": "startup", "hooks": [{"type": "command", "command": "other"}]}]}}' \
  > "$HOME_DIR/.codex/hooks.json"
claude_before="$(canonical "$HOME_DIR/.claude/settings.json")"
codex_before="$(canonical "$HOME_DIR/.codex/hooks.json")"
install
echo "my note" > "$HOME_DIR/.claude/skills/memory-log/notes.md"
install --uninstall
[ "$(canonical "$HOME_DIR/.claude/settings.json")" = "$claude_before" ] || fail "Claude settings differ after uninstall"
[ "$(canonical "$HOME_DIR/.codex/hooks.json")" = "$codex_before" ] || fail "Codex hooks differ after uninstall"
[ "$(canonical "$HOME_DIR/.gemini/settings.json")" = "{}" ] || fail "Gemini settings left non-empty: $(cat "$HOME_DIR/.gemini/settings.json")"
left="$(find "$HOME_DIR" -type f \( -name 'SKILL.md' -o -name 'reference.md' -o -name 'neko-skill-*' -o -name 'installed.sha256' \))"
[ -z "$left" ] || fail "files left after uninstall: $left"
[ -f "$HOME_DIR/.claude/skills/memory-log/notes.md" ] || fail "uninstall removed a file it did not install"

new_case "--uninstall keeps a file edited after install"
install
echo "edited" >> "$HOME_DIR/.agents/skills/test-smoke/SKILL.md"
install --uninstall
[ -f "$HOME_DIR/.agents/skills/test-smoke/SKILL.md" ] || fail "an edited skill was removed"
grep -q "kept $HOME_DIR/.agents/skills/test-smoke/SKILL.md" "$WORK/$CASES/install.log" || fail "no message about the kept file"

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
