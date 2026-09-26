"""Fail on any tracked text line that mentions ``NINOX_DB_ID`` outside the allowlist.

GAP-012: an environment variable named ``NINOX_DB_ID`` points at a production database on
the PO's machine. The project rule is never to use it (AGENTS.md §1.4); this check makes the
rule enforceable in CI (plan v0.2, T0.3). The allowlist contains the files that state or
enforce the rule, each line identified by a text fragment, plus the check's own three files.

Usage:
    python .github/scripts/no_ninox_db_id.py              # the tracked tree
    python .github/scripts/no_ninox_db_id.py FILE ...     # given files (used by the tests)

Binary files are skipped: a "line" is a text concept, and ``git grep`` (which produced the
allowlist) does not search binary content either.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ALLOWLIST = Path(__file__).with_name("no_ninox_db_id_allowlist.txt")
FORBIDDEN = "NINOX_DB_ID"


def load_allowlist(path: Path = ALLOWLIST) -> list[tuple[str, str]]:
    entries = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        parts = [p.strip() for p in raw.split("|")]
        if len(parts) != 3 or not all(parts):
            raise SystemExit(f"allowlist line needs `path | identifying text | reason`: {raw!r}")
        entries.append((parts[0], parts[1]))
    return entries


def allowed(rel: str, line: str, allow: list[tuple[str, str]]) -> bool:
    return any(path == rel and (marker == "*" or marker in line) for path, marker in allow)


def is_text(path: Path) -> bool:
    with path.open("rb") as fh:
        head = fh.read(8192)
    return b"\x00" not in head


def rel_for(path: Path) -> str:
    resolved = path.resolve()
    if resolved.is_relative_to(ROOT):
        return resolved.relative_to(ROOT).as_posix()
    return str(resolved)


def scan(paths: list[Path], allow: list[tuple[str, str]]) -> list[str]:
    findings = []
    for path in paths:
        if not is_text(path):
            continue
        rel = rel_for(path)
        for lineno, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if FORBIDDEN in line and not allowed(rel, line, allow):
                findings.append(f"{rel}:{lineno}: {line.strip()[:160]!r}")
    return findings


def tracked() -> list[Path]:
    out = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT,
                         capture_output=True, check=True).stdout.decode("utf-8")
    return [ROOT / p for p in out.split("\0") if p]


def main(argv: list[str]) -> int:
    paths = [Path(a) for a in argv] if argv else tracked()
    findings = scan(paths, load_allowlist())
    for f in findings:
        print(f)
    print(f"no-ninox-db-id: {len(paths)} files, {len(findings)} findings")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
