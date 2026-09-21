#!/usr/bin/env bash
# neko-skill — Claude Code, Gemini CLI, and Codex installer
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_SRC="$TOOLKIT_DIR/.claude/commands"
SKILLS_SRC="$TOOLKIT_DIR/skills"
HOOK_SRC="$TOOLKIT_DIR/hooks/session-start.sh"
GEMINI_HOOK_SRC="$TOOLKIT_DIR/hooks/session-start-gemini.sh"

CLAUDE_HOME="$HOME/.claude"
GEMINI_HOME="$HOME/.gemini"
CODEX_HOME="$HOME/.codex"
CODEX_SKILLS_HOME="$HOME/.agents/skills"
NEKO_MCP_URL="${NEKO_MCP_URL:-}"

if [ -n "$NEKO_MCP_URL" ]; then
  case "$NEKO_MCP_URL" in
    http://*/mcp|https://*/mcp) ;;
    *) echo "✗ NEKO_MCP_URL must be an HTTP(S) URL ending in /mcp." >&2; exit 1 ;;
  esac
fi

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

echo "Installing Claude Code commands..."
mkdir -p "$CLAUDE_HOME/commands"
for command_file in "$COMMANDS_SRC"/*.md; do
  cp "$command_file" "$CLAUDE_HOME/commands/$(basename "$command_file")"
  echo "  ✓ /$(basename "${command_file%.md}")"
done
echo ""

install_skills() {
  local platform="$1"
  local destination="$2"
  echo "Installing $platform skills to $destination ..."
  mkdir -p "$destination"
  for skill_dir in "$SKILLS_SRC"/*; do
    local name
    name="$(basename "$skill_dir")"
    mkdir -p "$destination/$name"
    cp "$skill_dir/SKILL.md" "$destination/$name/SKILL.md"
    echo "  ✓ $name"
  done
  echo ""
}

install_skills "Gemini CLI" "$GEMINI_HOME/skills"
install_skills "Codex" "$CODEX_SKILLS_HOME"

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

if [ -n "$NEKO_MCP_URL" ]; then
echo "Registering neko-mcp at $NEKO_MCP_URL ..."
if command -v claude &>/dev/null; then
  # Claude defaults to project-local scope; use the user scope for this installer.
  if python3 - "$HOME/.claude.json" <<'PYEOF'
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        config = json.load(f)
except FileNotFoundError:
    sys.exit(1)
sys.exit(0 if "neko-mcp" in config.get("mcpServers", {}) else 1)
PYEOF
  then
    claude mcp remove --scope user neko-mcp
  fi
  claude mcp add --scope user --transport http neko-mcp "$NEKO_MCP_URL"
  echo "  ✓ Claude Code"
else
  echo "  ⚠ Claude CLI not found; install it and rerun this script to register MCP."
fi

# Gemini's HTTP transport key is httpUrl, not url (which selects legacy SSE).
python3 - "$GEMINI_HOME/settings.json" "$NEKO_MCP_URL" <<'PYEOF'
import json, os, sys, tempfile

path, url = sys.argv[1:]
with open(path, encoding="utf-8") as f:
    settings = json.load(f)
settings.setdefault("mcpServers", {})["neko-mcp"] = {"httpUrl": url}
fd, temporary = tempfile.mkstemp(prefix=".settings-", dir=os.path.dirname(path))
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    os.replace(temporary, path)
except BaseException:
    os.unlink(temporary)
    raise
PYEOF
echo "  ✓ Gemini CLI"

if command -v codex &>/dev/null; then
  if codex mcp get neko-mcp &>/dev/null; then
    codex mcp remove neko-mcp
  fi
  codex mcp add neko-mcp --url "$NEKO_MCP_URL"
  echo "  ✓ Codex"
else
  echo "  ⚠ Codex CLI not found; install it and rerun this script to register MCP."
fi
echo ""
else
  echo "Skipping neko-mcp registration (set NEKO_MCP_URL to configure it)."
  echo ""
fi

echo "=== Setup complete ==="
echo ""
echo "Installed: memory-sync, memory-log, test-smoke, python-venv, gh-issues, git-branch"
echo "Claude: use /memory-sync (and the other slash commands)."
echo "Gemini: ask naturally or activate a skill with /skills."
echo "Codex: ask naturally, use /skills, or mention \$memory-sync."
if [ -n "$NEKO_MCP_URL" ]; then
  echo "neko-mcp: $NEKO_MCP_URL (start the server separately, then restart your clients)."
fi
echo ""
echo "The hook creates AI_MEMORY.md in Git repos and .env in Python projects when missing."
echo "Codex will ask you to review and trust the hook via /hooks."
