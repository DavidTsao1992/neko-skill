#!/usr/bin/env bash
# Build one marketplace ZIP per listed skill, into dist/ (or the directory given).
#
#   scripts/package.sh [dist-dir]
#
# A listing ships only a skill folder — no install.sh, no hook, no settings — so
# each ZIP holds exactly SKILL.md and, when the skill has one, reference/ (#14).
# Which skills are listed, and why, is in the README's "Marketplace" section.
set -euo pipefail
# Byte order for every sort, so the file order in a ZIP — and so the ZIP — does
# not depend on the machine's locale.
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$(mkdir -p "${1:-$ROOT/dist}" && cd "${1:-$ROOT/dist}" && pwd)"

# Listed as they are. repo-memory is built from memory-sync + memory-log below.
LISTED=(git-branch gh-issues python-venv test-smoke)

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# stage_skill <name>: copy skills/<name> into $STAGE/<name>, with reference.md
# moved to reference/ and the links to it rewritten.
stage_skill() {
  local name="$1" out="$STAGE/$1"
  mkdir -p "$out"
  python3 - "$ROOT/skills/$name" "$out" <<'PYEOF'
import pathlib, sys
src, out = map(pathlib.Path, sys.argv[1:])
skill = (src / "SKILL.md").read_text(encoding="utf-8")
refs = sorted(p for p in src.glob("*.md") if p.name != "SKILL.md")
for ref in refs:
    (out / "reference").mkdir(exist_ok=True)
    (out / "reference" / ref.name).write_text(ref.read_text(encoding="utf-8"), encoding="utf-8")
    skill = skill.replace(f"]({ref.name})", f"](reference/{ref.name})")
(out / "SKILL.md").write_text(skill, encoding="utf-8")
PYEOF
}

# repo-memory: memory-sync's steps as "At the start of a task", memory-log's as
# "After a task", in one SKILL.md. Generated, so it can't drift from the two
# skills it is made of; every rewrite below asserts its text still exists.
stage_repo_memory() {
  mkdir -p "$STAGE/repo-memory"
  python3 - "$ROOT/skills" "$STAGE/repo-memory/SKILL.md" <<'PYEOF'
import pathlib, re, sys
skills, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])

def body(name, title):
    text = (skills / name / "SKILL.md").read_text(encoding="utf-8")
    text = re.sub(r"\A---\n.*?\n---\n", "", text, flags=re.S).strip()
    assert text.startswith(f"# {title}\n"), f"{name}: expected '# {title}'"
    return text[len(f"# {title}\n"):].strip()

def replace(text, old, new):
    assert old in text, f"repo-memory: {old!r} not found — update scripts/package.sh"
    return text.replace(old, new)

load = body("memory-sync", "Memory Sync")
load = replace(load, "Load context from the current repository's local AI memory before starting a task.\n\n", "")
load = replace(load, "Append with the memory-log skill.", "Append after each task (see below).")
log = body("memory-log", "Memory Log")
log = replace(log, "the skeleton described by the\n   `memory-sync` skill", "the skeleton in step 1 above")

out.write_text(f"""---
name: repo-memory
description: Use at the start of a task in a repository to load its local AI_MEMORY.md — purpose, recent work, known failures, work in progress — and after finishing, failing, or pausing a task to record it there, so context and lessons carry over between sessions in a file versioned with the code.
---

# Repo Memory

One file, `AI_MEMORY.md` in the project root, carries context from one session to the next.

## At the start of a task

{load}

## After finishing, failing, or pausing a task

{log}
""", encoding="utf-8")
PYEOF
}

for name in "${LISTED[@]}"; do
  stage_skill "$name"
done
stage_repo_memory

# Fixed timestamps and no extra attributes, so the same sources give the same ZIP.
for dir in "$STAGE"/*/; do
  name="$(basename "$dir")"
  find "$dir" -exec touch -t 202601010000 {} +
  rm -f "$DIST/$name.zip"
  (cd "$dir" && find . -type f | sort | sed 's#^\./##' | zip -q -X -D "$DIST/$name.zip" -@)
  echo "✓ $DIST/$name.zip"
done
