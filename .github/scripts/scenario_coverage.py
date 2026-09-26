"""Report which spec scenarios have a scenario-tagged test (plan v0.2 §11.1).

A test covers a scenario when its name contains the tag ``[<capability>/<requirement>]``
and the scenario's name verbatim, case-insensitively:

    test('[setup-wizard/two-stage-matching-with-a-strict-threshold] below the threshold the field stays unmapped', ...);

The report is Markdown: per capability, the scenario count, covered count, uncovered
count, and the uncovered scenario names; plus every orphan ``[x/y]`` tag that names no
existing requirement. Exit code is 0 unless an orphan tag exists (an uncovered scenario
is not an error; the empty workspace is the baseline).

Usage:
    python .github/scripts/scenario_coverage.py [--out PATH]
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIREMENT = re.compile(r"^### Requirement:\s*(.+?)\s*$")
SCENARIO = re.compile(r"^#### Scenario:\s*(.+?)\s*$")
TEST_CALL = re.compile(r"\b(?:test|testWidgets|group)\s*\(\s*['\"]([^'\"]+)['\"]")
TAG = re.compile(r"\[([^/\]]+)/([^\]]+)\]")


def spec_files() -> list[Path]:
    out = subprocess.run(["git", "ls-files", "-z", "openspec/specs/*/spec.md"],
                         cwd=ROOT, capture_output=True, check=True).stdout.decode("utf-8")
    return [ROOT / p for p in out.split("\0") if p]


def test_files() -> list[Path]:
    out = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT,
                         capture_output=True, check=True).stdout.decode("utf-8")
    paths = [p for p in out.split("\0") if p]
    result = []
    for p in paths:
        if p.startswith("app/test/") and p.endswith(".dart"):
            result.append(ROOT / p)
        elif p.startswith("packages/") and "/test/" in p and p.endswith(".dart"):
            result.append(ROOT / p)
    return result


def parse_specs(paths: list[Path]) -> list[tuple[str, str, str]]:
    """Return (capability, requirement, scenario) tuples in file order."""
    rows = []
    for path in paths:
        capability = path.parent.name
        requirement = None
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            m = REQUIREMENT.match(line)
            if m:
                requirement = m.group(1).strip()
                continue
            m = SCENARIO.match(line)
            if m and requirement is not None:
                rows.append((capability, requirement, m.group(1).strip()))
    return rows


def parse_tests(paths: list[Path]) -> list[tuple[str, str]]:
    """Return (test name, repository-relative file) tuples."""
    tests = []
    for path in paths:
        rel = path.resolve().relative_to(ROOT).as_posix() if path.resolve().is_relative_to(ROOT) else str(path)
        text = path.read_text(encoding="utf-8", errors="replace")
        for line in text.splitlines():
            m = TEST_CALL.search(line)
            if m:
                tests.append((m.group(1), rel))
    return tests


def compute(specs: list[tuple[str, str, str]], tests: list[tuple[str, str]]):
    requirements = {(cap, req) for cap, req, _scenario in specs}
    covered = {}
    orphan_tags = []

    test_names = [(name.lower(), file) for name, file in tests]
    for cap, req, scenario in specs:
        tag = f"[{cap}/{req}]".lower()
        scenario_lower = scenario.lower()
        covered[(cap, req, scenario)] = any(
            tag in name and scenario_lower in name for name, _file in test_names
        )

    for name, file in tests:
        for cap, req in TAG.findall(name):
            cap = cap.strip()
            req = req.strip()
            if (cap, req) not in requirements:
                orphan_tags.append((f"[{cap}/{req}]", name, file))

    return covered, orphan_tags


def render(specs: list[tuple[str, str, str]], tests: list[tuple[str, str]]) -> str:
    covered, orphans = compute(specs, tests)
    capabilities: dict[str, list[tuple[str, str, str]]] = {}
    for cap, req, scenario in specs:
        capabilities.setdefault(cap, []).append((cap, req, scenario))

    lines = ["# Scenario coverage", ""]
    lines.append(f"Spec scenarios: {len(specs)} · test names read: {len(tests)} · "
                 f"orphan tags: {len(orphans)}")
    lines.append("")
    lines.append("## Orphan tags")
    if orphans:
        for tag, name, file in orphans:
            lines.append(f"- `{tag}` — test `{name}` in `{file}`")
    else:
        lines.append("None")
    lines.append("")

    for cap in sorted(capabilities):
        rows = capabilities[cap]
        covered_count = sum(1 for row in rows if covered[row])
        uncovered = [row for row in rows if not covered[row]]
        lines.append(f"## {cap}")
        lines.append("")
        lines.append(f"- Scenarios: {len(rows)}")
        lines.append(f"- Covered: {covered_count}")
        lines.append(f"- Uncovered: {len(uncovered)}")
        if uncovered:
            lines.append("")
            lines.append("Uncovered scenarios:")
            for _c, req, scenario in uncovered:
                lines.append(f"- `{req}`: {scenario}")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", metavar="PATH", help="write the report to this path instead of stdout")
    args = parser.parse_args(argv)

    specs = parse_specs(spec_files())
    tests = parse_tests(test_files())
    _covered, orphans = compute(specs, tests)
    report = render(specs, tests)

    if args.out:
        Path(args.out).write_text(report, encoding="utf-8")
        print(f"scenario coverage: wrote {args.out}")
    else:
        sys.stdout.write(report)
    return 1 if orphans else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
