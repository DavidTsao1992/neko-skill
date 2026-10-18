#!/usr/bin/env bash
# neko-skill — Claude Code, Gemini CLI, and Codex installer
#
#   ./install.sh               install or upgrade
#   ./install.sh --uninstall   remove exactly what install.sh added
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEGACY_COMMANDS="$TOOLKIT_DIR/legacy/claude-commands.sha256"
LEGACY_SHIPPED="$TOOLKIT_DIR/legacy/shipped.sha256"
SKILLS_SRC="$TOOLKIT_DIR/skills"
HOOK_SRC="hooks/session-start.sh"
GEMINI_HOOK_SRC="hooks/session-start-gemini.sh"

CLAUDE_HOME="$HOME/.claude"
GEMINI_HOME="$HOME/.gemini"
CODEX_HOME="$HOME/.codex"
CODEX_SKILLS_HOME="$HOME/.agents/skills"

# What install.sh wrote, as "<sha256>  <path>". It tells a copy the user has
# since edited (back it up before replacing it) from one that is still ours
# (just replace it), and it is the list --uninstall removes (#13).
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/neko-skill"
MANIFEST="$STATE_DIR/installed.sha256"

CLAUDE_HOOK="$CLAUDE_HOME/hooks/neko-skill-session-start.sh"
GEMINI_HOOK="$GEMINI_HOME/hooks/neko-skill-session-start.sh"
GEMINI_WRAPPER="$GEMINI_HOME/hooks/neko-skill-session-start-gemini.sh"
CODEX_HOOK="$CODEX_HOME/hooks/neko-skill-session-start.sh"

MODE=install
case "${1:-}" in
  "") ;;
  --uninstall) MODE=uninstall ;;
  -h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "✗ unknown option: $1 (try --help)" >&2; exit 2 ;;
esac

if ! command -v python3 &>/dev/null; then
  echo "✗ python3 is required to edit settings files safely." >&2
  exit 1
fi

sha256() {
  python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"
}

# The hash install.sh recorded for a path last time, or nothing.
recorded_hash() {
  [ -f "$MANIFEST" ] || return 0
  awk -v p="$1" 'substr($0, 67) == p { print $1 }' "$MANIFEST"
}

NEW_MANIFEST=""
BACKED_UP=()

# install_file <repo-relative source> <destination>
# Replaces the destination only when it is missing, already identical, the copy
# install.sh wrote last time, or a stock copy of an earlier release. Anything
# else is the user's edit: it is moved to <destination>.bak (or .bak.N) first, and reported.
install_file() {
  local rel="$1" dest="$2" src="$TOOLKIT_DIR/$1" current backup
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ -L "$dest" ] || [ ! -f "$dest" ]; then
      current="not-a-file"
    else
      current="$(sha256 "$dest")"
    fi
    if [ "$current" != "$(sha256 "$src")" ] \
        && [ "$current" != "$(recorded_hash "$dest")" ] \
        && ! grep -qx "$current  $rel" "$LEGACY_SHIPPED"; then
      # .bak, then .bak.1, .bak.2, …: the first name not taken, so an earlier
      # backup is never the one replaced.
      backup="$dest.bak"
      local n=1
      while [ -e "$backup" ] || [ -L "$backup" ]; do
        backup="$dest.bak.$n"
        n=$((n + 1))
      done
      mv "$dest" "$backup"
      BACKED_UP+=("$backup")
    fi
  fi
  cp "$src" "$dest"
  NEW_MANIFEST+="$(sha256 "$dest")  $dest"$'\n'
}

# ── uninstall ────────────────────────────────────────────────────────────────

remove_session_start_hook() {
  local settings="$1" hook_path="$2"
  [ -f "$settings" ] || return 0
  python3 - "$settings" "$hook_path" <<'PYEOF'
import json, shlex, sys

settings_path, hook_path = sys.argv[1:]
with open(settings_path, encoding="utf-8") as f:
    data = json.load(f)
groups = data.get("hooks", {}).get("SessionStart")
if not groups:
    sys.exit(0)
ours = {hook_path, shlex.quote(hook_path)}
kept = []
for group in groups:
    hooks = [h for h in group.get("hooks", []) if h.get("command") not in ours]
    if hooks:
        kept.append({**group, "hooks": hooks})
    elif not group.get("hooks"):
        kept.append(group)
if kept == groups:
    sys.exit(0)
if kept:
    data["hooks"]["SessionStart"] = kept
else:
    del data["hooks"]["SessionStart"]
    if not data["hooks"]:
        del data["hooks"]
with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(f"  ✓ removed from {settings_path}")
PYEOF
}

if [ "$MODE" = uninstall ]; then
  echo "=== neko-skill — uninstall ==="
  echo ""
  if [ ! -f "$MANIFEST" ]; then
    echo "Nothing recorded in $MANIFEST: no files to remove (installs before #13 kept no record)."
  else
    echo "Removing installed files..."
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      hash="${line%%  *}"
      path="${line#*  }"
      if [ ! -f "$path" ] || [ -L "$path" ]; then
        continue
      elif [ "$(sha256 "$path")" = "$hash" ]; then
        rm "$path"
        rmdir "$(dirname "$path")" 2>/dev/null || true
        echo "  ✓ $path"
      else
        echo "  ⚠ kept $path: it changed after install"
      fi
    done < "$MANIFEST"
    rm "$MANIFEST"
    rmdir "$STATE_DIR" 2>/dev/null || true
  fi
  echo ""
  echo "Removing SessionStart hook registrations..."
  remove_session_start_hook "$CLAUDE_HOME/settings.json" "$CLAUDE_HOOK"
  remove_session_start_hook "$GEMINI_HOME/settings.json" "$GEMINI_WRAPPER"
  remove_session_start_hook "$CODEX_HOME/hooks.json" "$CODEX_HOOK"
  echo ""
  echo "=== Uninstall complete ==="
  echo "Backups (*.bak) and anything you changed after installing were left in place."
  exit 0
fi

# ── install ──────────────────────────────────────────────────────────────────

echo "=== neko-skill — Claude, Gemini, and Codex setup ==="
echo ""

if command -v pyenv &>/dev/null; then
  echo "✓ pyenv: $(pyenv --version)"
else
  echo "⚠ pyenv not found (required only by the python-venv skill)."
fi
echo "✓ python3: $(python3 --version 2>&1)"
echo ""

INSTALLED=()
for skill_dir in "$SKILLS_SRC"/*/; do
  INSTALLED+=("$(basename "$skill_dir")")
done

# Each skill is a folder: SKILL.md plus any reference files it links to. The same
# folder is installed for all three agents (#12).
install_skills() {
  local platform="$1" destination="$2" name file
  echo "Installing $platform skills to $destination ..."
  for name in "${INSTALLED[@]}"; do
    for file in "$SKILLS_SRC/$name"/*.md; do
      install_file "skills/$name/$(basename "$file")" "$destination/$name/$(basename "$file")"
    done
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
for name in "${INSTALLED[@]}"; do
  old="$CLAUDE_HOME/commands/$name.md"
  if [ ! -f "$old" ] || [ -L "$old" ]; then
    continue
  fi
  if grep -qx "$(sha256 "$old")  $name" "$LEGACY_COMMANDS"; then
    rm "$old"
    echo "  ✓ removed the old /$name command (now a skill)"
  else
    echo "  ⚠ kept $old: it differs from every version neko-skill shipped. It has the same name as the $name skill; remove it if you no longer need it."
  fi
done

echo "Installing SessionStart hooks..."
install_file "$HOOK_SRC" "$CLAUDE_HOOK"
install_file "$HOOK_SRC" "$GEMINI_HOOK"
install_file "$GEMINI_HOOK_SRC" "$GEMINI_WRAPPER"
install_file "$HOOK_SRC" "$CODEX_HOOK"
chmod +x "$CLAUDE_HOOK" "$GEMINI_HOOK" "$GEMINI_WRAPPER" "$CODEX_HOOK"

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

merge_session_start_hook "$CLAUDE_HOME/settings.json" "$CLAUDE_HOOK" ""
merge_session_start_hook "$GEMINI_HOME/settings.json" "$GEMINI_WRAPPER" ""
merge_session_start_hook "$CODEX_HOME/hooks.json" "$CODEX_HOOK" "startup|resume|clear|compact"
echo ""

# Files a previous install wrote that this release no longer ships (a skill or
# file removed or renamed): remove them if they are still as installed, so they
# don't linger untracked; keep, and say so, any the user has changed.
if [ -f "$MANIFEST" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    hash="${line%%  *}"
    path="${line#*  }"
    case "$NEW_MANIFEST" in *"  $path"$'\n'*) continue ;; esac
    if [ ! -f "$path" ] || [ -L "$path" ]; then
      continue
    elif [ "$(sha256 "$path")" = "$hash" ]; then
      rm "$path"
      rmdir "$(dirname "$path")" 2>/dev/null || true
      echo "  ✓ removed $path (no longer part of neko-skill)"
    else
      echo "  ⚠ kept $path: no longer part of neko-skill, but changed since it was installed"
    fi
  done < "$MANIFEST"
fi

mkdir -p "$STATE_DIR"
printf '%s' "$NEW_MANIFEST" > "$MANIFEST"

if [ "${#BACKED_UP[@]}" -gt 0 ]; then
  echo "⚠ These had been changed since neko-skill installed them; your version was kept as:"
  printf '    %s\n' "${BACKED_UP[@]}"
  echo ""
fi

echo "=== Setup complete ==="
echo ""
echo "Installed: ${INSTALLED[*]}"
echo "Claude: use /memory-sync (skills are also picked up from a matching request)."
echo "Gemini: ask naturally or activate a skill with /skills."
echo "Codex: ask naturally, use /skills, or mention \$memory-sync."
echo ""
echo "The hook creates AI_MEMORY.md in Git repos, and .env in Python projects that git-ignore it,"
echo "when missing. Set NEKO_SKILL_NO_ENV=1 to skip .env."
echo "Codex will ask you to review and trust the hook via /hooks."
echo "Undo with ./install.sh --uninstall."
