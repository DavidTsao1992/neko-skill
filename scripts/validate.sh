#!/usr/bin/env bash
# Check marketplace ZIPs before they are uploaded (#14).
#
#   scripts/validate.sh dist/*.zip
#
# A listing runs in strangers' agents with nothing else of neko-skill around it,
# so each ZIP must be self-contained and leak nothing about this machine.
set -euo pipefail

[ "$#" -gt 0 ] || { echo "usage: $0 <zip>..." >&2; exit 2; }

python3 - "$@" <<'PYEOF'
import re, sys, zipfile, pathlib

FORBIDDEN = [
    (r"/Users/|/home/[a-z]", "an absolute home path"),
    (r"\.ts\.net\b|\b100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.\d+\.\d+\b", "a private host (Tailscale)"),
    (r"\b(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_\w{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})", "a token"),
    (r"install\.sh|SessionStart|\bhooks?\b", "the installer or the hook, which a listing does not ship"),
]
OTHER_SKILLS = {"memory-sync", "memory-log", "git-branch", "gh-issues", "python-venv", "test-smoke", "repo-memory"}

failures = 0
for path in map(pathlib.Path, sys.argv[1:]):
    name = path.stem
    problems = []
    with zipfile.ZipFile(path) as z:
        files = {i.filename: z.read(i).decode("utf-8") for i in z.infolist() if not i.is_dir()}
    for f in files:
        if f != "SKILL.md" and not re.fullmatch(r"reference/[\w.-]+\.md", f):
            problems.append(f"unexpected file {f} (only SKILL.md and reference/*.md)")
    skill = files.get("SKILL.md")
    if skill is None:
        problems.append("no SKILL.md at the top of the ZIP")
    else:
        m = re.match(r"\A---\n(.*?)\n---\n", skill, re.S)
        meta = dict(re.findall(r"^(\w[\w-]*):\s*(.*)$", m.group(1), re.M)) if m else {}
        if meta.get("name") != name:
            problems.append(f"frontmatter name is {meta.get('name')!r}, the ZIP is {name!r}")
        if not meta.get("description", "").startswith("Use "):
            problems.append("description must say when to use the skill ('Use when …' / 'Use at …')")
        for target in re.findall(r"\]\(([^)#:]+)\)", skill):
            if target not in files:
                problems.append(f"SKILL.md links to {target}, which is not in the ZIP")
    for f, text in files.items():
        for pattern, what in FORBIDDEN:
            for hit in re.finditer(pattern, text):
                problems.append(f"{f} mentions {what}: {hit.group(0)!r}")
        # Another neko-skill skill may only be suggested, never relied on.
        for line in text.splitlines():
            for other in OTHER_SKILLS - {name}:
                if f"`{other}`" in line and not re.search(r"\bif\b|installed", line):
                    problems.append(f"{f} relies on the {other} skill, which may not be installed: {line.strip()!r}")
    if problems:
        failures += 1
        print(f"✗ {path.name}")
        for p in problems:
            print(f"    {p}")
    else:
        print(f"✓ {path.name}")
sys.exit(1 if failures else 0)
PYEOF
