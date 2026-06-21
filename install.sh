#!/usr/bin/env bash
# Danpoints AI Package — one-command installer
# Usage: bash install.sh
set -euo pipefail

REPO="DavidTsao1992/danpoints"
AI_REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_SRC="$AI_REPO_DIR/.claude/commands"
COMMANDS_DEST="$HOME/.claude/commands"
NOTION_DB_URL="https://app.notion.com/p/59e160ca0a41460d9a141f2a2b47997d"

echo "=== Danpoints AI Package Setup ==="
echo ""

# ── 1. Check for updates ────────────────────────────────────────────────────────
echo "Checking for AI package updates..."
git -C "$AI_REPO_DIR" fetch origin --quiet 2>/dev/null || true
UPDATE_COUNT=$(git -C "$AI_REPO_DIR" log HEAD..origin/main --oneline 2>/dev/null | wc -l | tr -d ' ')
if [ "$UPDATE_COUNT" -gt "0" ]; then
  echo "  ⚠ $UPDATE_COUNT new commit(s) available — run: git pull origin main"
  git -C "$AI_REPO_DIR" log HEAD..origin/main --oneline 2>/dev/null | head -5 | sed 's/^/    /'
else
  echo "✓ AI package is up to date"
fi
echo ""

# ── 2. Check gh CLI ─────────────────────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
  echo "ERROR: gh CLI not found. Install with: brew install gh"
  exit 1
fi
echo "✓ gh CLI: $(gh --version | head -1)"

# ── 3. Check gh auth ────────────────────────────────────────────────────────────
if ! gh auth status &>/dev/null; then
  echo ""
  echo "ERROR: gh CLI is not authenticated."
  echo "       Run: echo 'YOUR_PAT' | gh auth login --with-token"
  echo "       PAT needs: repo scope"
  exit 1
fi
GH_USER=$(gh api user --jq .login 2>/dev/null || echo "unknown")
echo "✓ gh authenticated as: $GH_USER"

# ── 4. Verify repo access ───────────────────────────────────────────────────────
if ! gh repo view "$REPO" --json name &>/dev/null; then
  echo "ERROR: Cannot access $REPO — check PAT repo scope."
  exit 1
fi
echo "✓ Repo access: $REPO"

# ── 5. Install skills globally to ~/.claude/commands/ ──────────────────────────
echo ""
echo "Installing Claude skills to $COMMANDS_DEST ..."
mkdir -p "$COMMANDS_DEST"

for skill in "$COMMANDS_SRC"/*.md; do
  filename="$(basename "$skill")"
  dest="$COMMANDS_DEST/$filename"
  cp "$skill" "$dest"
  echo "  ✓ /$( echo "$filename" | sed 's/\.md$//')"
done

# ── 6. Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "=== Setup complete ==="
echo ""
echo "Claude skills installed (available in any Claude Code session):"
echo "  /notion-sync   — load AI Task Memory context before starting a task"
echo "  /notion-log    — log task result to Notion after completion"
echo "  /test-smoke    — run pytest on danpoints and log results"
echo ""
echo "Notion AI Task Memory DB:"
echo "  $NOTION_DB_URL"
echo ""
echo "Workflow:"
echo "  1. /notion-sync → work on danpoints → gh pr create --base stg"
echo "  2. Human approves → GitHub Actions auto-deploys to PythonAnywhere"
echo "  3. /test-smoke → /notion-log"
