#!/usr/bin/env bash
# neko-skill — Claude Code, Gemini CLI, and Codex installer
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEGACY_COMMANDS="$TOOLKIT_DIR/legacy/claude-commands.sha256"
SKILLS_SRC="$TOOLKIT_DIR/skills"
HOOK_SRC="$TOOLKIT_DIR/hooks/session-start.sh"
GEMINI_HOOK_SRC="$TOOLKIT_DIR/hooks/session-start-gemini.sh"

CLAUDE_HOME="$HOME/.claude"
GEMINI_HOME="$HOME/.gemini"
CODEX_HOME="$HOME/.codex"
CODEX_SKILLS_HOME="$HOME/.agents/skills"

echo "=== neko-skill — Claude, Gemini, and Codex setup ==="
echo ""

if command -v pyenv &>/dev/null; then
  echo "✓ pyenv: $(pyenv --version)"
else
  echo "⚠ pyenv not found (required only by the python-venv skill)."
fi

if command -v python3 &>/dev/null; then
  echo "✓ python3: $(python3 --version 2>&1)"
else
  echo "✗ python3 is required to merge hook configuration safely."
  exit 1
fi
echo ""

# Each skill is a folder: SKILL.md plus any reference files it links to. The same
# folder is installed for all three agents (#12).
install_skills() {
  local platform="$1"
  local destination="$2"
  echo "Installing $platform skills to $destination ..."
  mkdir -p "$destination"
  for skill_dir in "$SKILLS_SRC"/*/; do
    local name
    name="$(basename "$skill_dir")"
    mkdir -p "$destination/$name"
    cp "$skill_dir"*.md "$destination/$name/"
    echo "  ✓ $name"
  done
  echo ""
}

install_skills "Claude Code" "$CLAUDE_HOME/skills"
install_skills "Gemini CLI" "$GEMINI_HOME/skills"
install_skills "Codex" "$CODEX_SKILLS_HOME"

# Earlier versions installed Claude slash commands, ~/.claude/commands/<name>.md, which
# the skills above replace. Remove a copy only if it is byte-for-byte one this repo
# shipped; a command the user wrote or edited is left alone, with a warning.
for skill_dir in "$SKILLS_SRC"/*/; do
  name="$(basename "$skill_dir")"
  old="$CLAUDE_HOME/commands/$name.md"
  if [ ! -f "$old" ] || [ -L "$old" ]; then
    continue
  fi
  hash="$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$old")"
  if grep -qx "$hash  $name" "$LEGACY_COMMANDS"; then
    rm "$old"
    echo "  ✓ removed the old /$name command (now a skill)"
  else
    echo "  ⚠ kept $old: it differs from every version neko-skill shipped. It has the same name as the $name skill; remove it if you no longer need it."
  fi
done
echo ""

echo "Installing SessionStart hooks..."
mkdir -p "$CLAUDE_HOME/hooks" "$GEMINI_HOME/hooks" "$CODEX_HOME/hooks"
cp "$HOOK_SRC" "$CLAUDE_HOME/hooks/neko-skill-session-start.sh"
cp "$HOOK_SRC" "$GEMINI_HOME/hooks/neko-skill-session-start.sh"
cp "$GEMINI_HOOK_SRC" "$GEMINI_HOME/hooks/neko-skill-session-start-gemini.sh"
cp "$HOOK_SRC" "$CODEX_HOME/hooks/neko-skill-session-start.sh"
chmod +x \
  "$CLAUDE_HOME/hooks/neko-skill-session-start.sh" \
  "$GEMINI_HOME/hooks/neko-skill-session-start.sh" \
  "$GEMINI_HOME/hooks/neko-skill-session-start-gemini.sh" \
  "$CODEX_HOME/hooks/neko-skill-session-start.sh"

merge_session_start_hook() {
  local settings="$1"
  local hook_path="$2"
  local matcher="$3"
  mkdir -p "$(dirname "$settings")"
  [ -f "$settings" ] || printf '{}\n' > "$settings"

  python3 - "$settings" "$hook_path" "$matcher" <<'PYEOF'
import json, shlex, sys

settings_path, hook_path, matcher = sys.argv[1:]
with open(settings_path, encoding="utf-8") as f:
    data = json.load(f)

command = shlex.quote(hook_path)
session_start = data.setdefault("hooks", {}).setdefault("SessionStart", [])
already = any(
    hook.get("type") == "command" and hook.get("command") == command
    for group in session_start
    for hook in group.get("hooks", [])
)
if not already:
    group = {"hooks": [{"type": "command", "command": command}]}
    if matcher:
        group["matcher"] = matcher
    session_start.append(group)
    with open(settings_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print(f"  ✓ registered in {settings_path}")
else:
    print(f"  ✓ already registered in {settings_path}")
PYEOF
}

merge_session_start_hook "$CLAUDE_HOME/settings.json" "$CLAUDE_HOME/hooks/neko-skill-session-start.sh" ""
merge_session_start_hook "$GEMINI_HOME/settings.json" "$GEMINI_HOME/hooks/neko-skill-session-start-gemini.sh" ""
merge_session_start_hook "$CODEX_HOME/hooks.json" "$CODEX_HOME/hooks/neko-skill-session-start.sh" "startup|resume|clear|compact"
echo ""

echo "=== Setup complete ==="
echo ""
echo "Installed: memory-sync, memory-log, test-smoke, python-venv, gh-issues, git-branch"
echo "Claude: use /memory-sync (skills are also picked up from a matching request)."
echo "Gemini: ask naturally or activate a skill with /skills."
echo "Codex: ask naturally, use /skills, or mention \$memory-sync."
echo ""
echo "The hook creates AI_MEMORY.md in Git repos, and .env in Python projects that git-ignore it,"
echo "when missing. Set NEKO_SKILL_NO_ENV=1 to skip .env."
echo "Codex will ask you to review and trust the hook via /hooks."
