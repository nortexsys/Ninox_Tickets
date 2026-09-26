"""Fail if paperdrop_core imports anything outside its allowed dependency set.

paperdrop_core is the pure-Dart layer that decides every value (plan v0.2 §5). It may
import nothing but ``dart:core``, ``dart:collection``, ``dart:math``, ``dart:convert``,
``dart:typed_data``, its own ``package:paperdrop_core/...`` files, and relative paths.
Any other ``import`` or ``export`` in ``packages/paperdrop_core/lib/**.dart`` is a
finding (setup-mvp-foundations, design §2).

Usage:
    python .github/scripts/core_purity.py              # the tracked tree
    python .github/scripts/core_purity.py FILE ...     # given files (used by the tests)
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

ALLOWED_DART = {
    "dart:core",
    "dart:collection",
    "dart:math",
    "dart:convert",
    "dart:typed_data",
}

# A Dart import/export directive at the start of a line, with its URI captured.
DIRECTIVE = re.compile(r"^\s*(?:import|export)\s+['\"]([^'\"]+)['\"]")


def allowed_uri(uri: str) -> bool:
    if uri in ALLOWED_DART:
        return True
    if uri.startswith("package:paperdrop_core/"):
        return True
    if not uri.startswith("dart:") and not uri.startswith("package:"):
        return True  # a relative path
    return False


def rel_for(path: Path) -> str:
    resolved = path.resolve()
    if resolved.is_relative_to(ROOT):
        return resolved.relative_to(ROOT).as_posix()
    return str(resolved)


def scan(paths: list[Path]) -> list[str]:
    findings = []
    for path in paths:
        rel = rel_for(path)
        for lineno, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            match = DIRECTIVE.search(line)
            if match and not allowed_uri(match.group(1)):
                findings.append(f"{rel}:{lineno}: {match.group(1)!r}")
    return findings


def tracked() -> list[Path]:
    out = subprocess.run(["git", "ls-files", "-z", "packages/paperdrop_core/lib/*.dart"],
                         cwd=ROOT, capture_output=True, check=True).stdout.decode("utf-8")
    return [ROOT / p for p in out.split("\0") if p]


def main(argv: list[str]) -> int:
    paths = [Path(a) for a in argv] if argv else tracked()
    findings = scan(paths)
    for f in findings:
        print(f)
    print(f"core purity: {len(paths)} files, {len(findings)} findings")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
