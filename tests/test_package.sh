#!/usr/bin/env bash
# Tests for scripts/package.sh and scripts/validate.sh (#14). Plain Bash: run it directly.
set -uo pipefail
export LC_ALL=C  # sort in byte order, as package.sh does

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LISTINGS=(gh-issues git-branch python-venv repo-memory test-smoke)
FAILURES=0
CASES=0

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "  ✗ $*"; FAILURES=$((FAILURES + 1)); }
new_case() { CASES=$((CASES + 1)); echo "• $1"; }

DIST="$WORK/dist"
bash "$ROOT/scripts/package.sh" "$DIST" >/dev/null || fail "package.sh failed"

new_case "one ZIP per listing, and nothing else"
built="$(find "$DIST" -name '*.zip' -exec basename {} .zip \; | sort | tr '\n' ' ')"
[ "$built" = "${LISTINGS[*]} " ] || fail "built [$built], expected [${LISTINGS[*]} ]"

new_case "each ZIP holds SKILL.md and reference/ only"
for name in "${LISTINGS[@]}"; do
  files="$(unzip -Z1 "$DIST/$name.zip" | sort | tr '\n' ' ')"
  case "$name" in
    gh-issues|git-branch) want="SKILL.md reference/reference.md " ;;
    *) want="SKILL.md " ;;
  esac
  [ "$files" = "$want" ] || fail "$name.zip holds [$files], expected [$want]"
done

new_case "every built ZIP passes validate.sh"
bash "$ROOT/scripts/validate.sh" "$DIST"/*.zip >/dev/null || fail "$(bash "$ROOT/scripts/validate.sh" "$DIST"/*.zip | grep -A3 '✗')"

new_case "repo-memory carries both halves and no dangling references"
skill="$(unzip -p "$DIST/repo-memory.zip" SKILL.md)"
[[ "$skill" == *"## At the start of a task"* && "$skill" == *"## After finishing, failing, or pausing a task"* ]] \
  || fail "a section is missing"
[[ "$skill" == *"\`memory-sync\`"* || "$skill" == *"memory-log skill"* ]] && fail "still refers to memory-sync / memory-log"

new_case "the same sources build the same ZIPs, whatever the umask"
first="$(cd "$DIST" && shasum -a 256 -- *.zip)"
(umask 077 && bash "$ROOT/scripts/package.sh" "$DIST" >/dev/null)
[ "$(cd "$DIST" && shasum -a 256 -- *.zip)" = "$first" ] || fail "a rebuild under umask 077 changed the ZIPs"
(umask 022 && bash "$ROOT/scripts/package.sh" "$DIST" >/dev/null)
[ "$(cd "$DIST" && shasum -a 256 -- *.zip)" = "$first" ] || fail "a rebuild under umask 022 changed the ZIPs"

# validate.sh has to catch what it is for, not just pass clean input.
bad_zip() {  # bad_zip <name> <SKILL.md body> [extra file]
  local dir="$WORK/bad/$1"
  rm -rf "$dir" && mkdir -p "$dir"
  printf -- '---\nname: %s\ndescription: Use when testing.\n---\n\n%s\n' "$1" "$2" > "$dir/SKILL.md"
  [ -z "${3:-}" ] || echo x > "$dir/$3"
  rm -f "$WORK/bad/$1.zip"
  (cd "$dir" && zip -q -r "../$1.zip" .)
}
rejects() {  # rejects <case> <name> <body> [extra file]
  new_case "validate.sh rejects $1"
  bad_zip "$2" "$3" "${4:-}"
  bash "$ROOT/scripts/validate.sh" "$WORK/bad/$2.zip" >/dev/null 2>&1 && fail "accepted it"
}
rejects "a macOS home path" demo "Read /Users/someone/notes.md"
rejects "a Linux home path" demo "Read /home/Alice/notes.md"
rejects "root's home" demo "Copy /root/.ssh/config"
rejects "a Windows profile" demo 'Open C:\Users\alice\notes.md'
# Fake tokens are assembled at run time: a token-shaped literal in the repo is
# exactly what secret scanners flag, fake or not (GitHub raised an alert on one).
FILLER="abcdefghijklmnopqrstuvwxyz0123456789"
rejects "a GitHub token" demo "token ghp""_$FILLER"
rejects "an OpenAI project key" demo "key sk-""proj-abc_DEF-$FILLER"
rejects "an Anthropic key" demo "key sk-""ant-api03-$FILLER"
rejects "a temporary AWS key" demo "aws_access_key_id = AS""IA$(printf '%s' "$FILLER" | tr '[:lower:]' '[:upper:]' | cut -c1-16)"
rejects "a Tailscale IPv6 address" demo "Reach it at fd7a:115c:a1e0:ab12:4843:cd96:6240:4f12."
rejects "a reference to the hook" demo "The SessionStart hook creates it."
rejects "relying on another skill" demo "Then use the \`git-branch\` skill."
rejects "relying on another skill under an unrelated if" demo "If the tree is dirty, use the \`git-branch\` skill."
rejects "a broken link" demo "See [notes](reference/missing.md)."
rejects "an extra file" demo "Fine." "run.sh"

new_case "validate.sh checks links inside reference/ too"
bad_zip demo "See [ref](reference/a.md)."
mkdir -p "$WORK/bad/demo/reference"
echo "Back to [the steps](../SKILL.md); see [b](b.md)." > "$WORK/bad/demo/reference/a.md"
rm -f "$WORK/bad/demo.zip" && (cd "$WORK/bad/demo" && zip -q -r ../demo.zip .)
bash "$ROOT/scripts/validate.sh" "$WORK/bad/demo.zip" >/dev/null 2>&1 && fail "accepted a broken link in reference/a.md"
echo "Back to [the steps](../SKILL.md)." > "$WORK/bad/demo/reference/a.md"
rm -f "$WORK/bad/demo.zip" && (cd "$WORK/bad/demo" && zip -q -r ../demo.zip .)
bash "$ROOT/scripts/validate.sh" "$WORK/bad/demo.zip" >/dev/null 2>&1 || fail "rejected a valid ../SKILL.md link"

new_case "a rebuild removes ZIPs of listings it no longer builds, and nothing else"
echo "stale" > "$DIST/old-name.zip"
echo "old-name.zip" >> "$DIST/.listings"
echo "someone else's" > "$DIST/unrelated.zip"
bash "$ROOT/scripts/package.sh" "$DIST" >/dev/null
[ -e "$DIST/old-name.zip" ] && fail "the dropped listing's ZIP was left behind"
[ -f "$DIST/unrelated.zip" ] || fail "a ZIP the script did not make was removed"
rm -f "$DIST/unrelated.zip"

new_case "validate.sh rejects a frontmatter name that is not the ZIP's"
bad_zip demo "Fine."
mv "$WORK/bad/demo.zip" "$WORK/bad/renamed.zip"
bash "$ROOT/scripts/validate.sh" "$WORK/bad/renamed.zip" >/dev/null 2>&1 && fail "accepted it"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES failure(s) in $CASES cases"
  exit 1
fi
echo "all $CASES cases passed"
