#!/usr/bin/env bash
# neko — Claude Code installer
# Usage: ./install.sh
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_SRC="$TOOLKIT_DIR/.claude/commands"
HOOK_SRC="$TOOLKIT_DIR/hooks/session-start.sh"

CLAUDE_HOME="$HOME/.claude"
COMMANDS_DEST="$CLAUDE_HOME/commands"
HOOKS_DEST="$CLAUDE_HOME/hooks"
HOOK_DEST="$HOOKS_DEST/neko-session-start.sh"
SETTINGS="$CLAUDE_HOME/settings.json"

echo "=== neko — Setup ==="
echo ""

# ── 1. Check for pyenv ───────────────────────────────────────────────────────
if command -v pyenv &>/dev/null; then
  echo "✓ pyenv: $(pyenv --version)"
else
  echo "⚠ pyenv not found."
  echo "  This toolkit assumes Python projects are managed with pyenv."
  echo "  Install with: brew install pyenv   (then add pyenv init to your shell profile)"
fi

# ── 2. Check python3 (needed to safely merge hook config below) ────────────
if command -v python3 &>/dev/null; then
  echo "✓ python3: $(python3 --version 2>&1)"
else
  echo "⚠ python3 not found — hook registration below will fall back to manual instructions."
fi
echo ""

# ── 3. Install skills to ~/.claude/commands/ ────────────────────────────────
echo "Installing Claude Code skills to $COMMANDS_DEST ..."
mkdir -p "$COMMANDS_DEST"
for skill in "$COMMANDS_SRC"/*.md; do
  filename="$(basename "$skill")"
  cp "$skill" "$COMMANDS_DEST/$filename"
  echo "  ✓ /${filename%.md}"
done
echo ""

# ── 4. Install the SessionStart hook script ──────────────────────────────────
echo "Installing SessionStart hook script..."
mkdir -p "$HOOKS_DEST"
cp "$HOOK_SRC" "$HOOK_DEST"
chmod +x "$HOOK_DEST"
echo "  ✓ $HOOK_DEST"
echo ""

# ── 5. Register the hook in ~/.claude/settings.json (idempotent merge) ──────
echo "Registering SessionStart hook in $SETTINGS ..."
mkdir -p "$CLAUDE_HOME"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

if command -v python3 &>/dev/null; then
  python3 - "$SETTINGS" "$HOOK_DEST" <<'PYEOF'
import json, sys

settings_path, hook_cmd = sys.argv[1], sys.argv[2]
with open(settings_path) as f:
    data = json.load(f)

hooks = data.setdefault("hooks", {})
session_start = hooks.setdefault("SessionStart", [])

already = any(
    h.get("type") == "command" and h.get("command") == hook_cmd
    for entry in session_start
    for h in entry.get("hooks", [])
)

if not already:
    session_start.append({"matcher": "", "hooks": [{"type": "command", "command": hook_cmd}]})
    with open(settings_path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print("  ✓ hook registered")
else:
    print("  ✓ hook already registered")
PYEOF
else
  echo "  ⚠ python3 not found — add this to $SETTINGS by hand:"
  echo "  \"hooks\": {\"SessionStart\": [{\"matcher\": \"\", \"hooks\": [{\"type\": \"command\", \"command\": \"$HOOK_DEST\"}]}]}"
fi
echo ""

# ── 6. Done ───────────────────────────────────────────────────────────────
echo "=== Setup complete ==="
echo ""
echo "Skills installed (available in any Claude Code session):"
for skill in "$COMMANDS_SRC"/*.md; do
  filename="$(basename "$skill")"
  echo "  /${filename%.md}"
done
echo ""
echo "Every Claude Code session start will now, in the launch directory:"
echo "  - create .env if it looks like a Python project and .env is missing"
echo "  - create AI_MEMORY.md if this is a git repo and it doesn't exist yet"
echo ""
echo "Per-repo workflow:"
echo "  1. /memory-sync   — load this repo's purpose + recent history before starting"
echo "  2. do the work"
echo "  3. /memory-log    — append a timestamped entry to AI_MEMORY.md"
