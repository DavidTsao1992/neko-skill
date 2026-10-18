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
import posixpath, re, sys, zipfile, pathlib

FORBIDDEN = [
    (r"(?i)/Users/|/home/[^/\s]+/|/root/|\b[A-Z]:[\\/](Users|Documents and Settings)[\\/]", "an absolute home path"),
    # MagicDNS names, and device addresses from 100.64.0.0/10 and fd7a:115c:a1e0::/48.
    (r"(?i)\.ts\.net\b|\b100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.\d+\.\d+\b|\bfd7a:115c:a1e0:", "a private host (Tailscale)"),
    # GitHub, OpenAI/Anthropic (sk-, sk-proj-, sk-ant-…, with - and _), AWS long-term
    # (AKIA) and temporary STS (ASIA) access keys, Google, Slack.
    (r"\b(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_\w{20,}|sk-[A-Za-z0-9_-]{20,}|A(KI|SI)A[0-9A-Z]{16}"
     r"|AIza[0-9A-Za-z_-]{30,}|xox[abprs]-[A-Za-z0-9-]{10,})", "a token"),
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
    for f, text in files.items():
        # Every shipped Markdown file's relative links, resolved from its own folder.
        for target in re.findall(r"\]\(([^)#\s]+)", text):
            if re.match(r"[a-z][a-z0-9+.-]*:", target, re.I):
                continue  # https:, mailto:, …
            resolved = posixpath.normpath(posixpath.join(posixpath.dirname(f), target))
            if resolved not in files:
                problems.append(f"{f} links to {target}, which is not in the ZIP")
        for pattern, what in FORBIDDEN:
            for hit in re.finditer(pattern, text):
                problems.append(f"{f} mentions {what}: {hit.group(0)!r}")
        # Another neko-skill skill may only be suggested, never relied on: the line
        # must make it conditional on that skill being installed, not on anything else.
        for line in text.splitlines():
            for other in OTHER_SKILLS - {name}:
                if f"`{other}`" in line and not re.search(r"\binstalled\b", line):
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
