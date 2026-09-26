"""Fail on double-encoded text (UTF-8 read as cp1252 and saved again) in tracked *.md and inside *.docx.

GAP-024: nine living specs and the Funcional carried `Â§` for `§` and `â€"` for `—` since their first
commit, and nobody noticed for weeks. This check keeps it from coming back (plan v0.2, T0.10).

    python .github/scripts/encoding_guard.py            # the tracked tree
    python .github/scripts/encoding_guard.py FILE ...   # given files (used by the tests)

A line may carry the pattern only if it DESCRIBES the defect; such lines are listed in
encoding_guard_allowlist.txt as `path | text that identifies the line | reason`.
"""
from __future__ import annotations

import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ALLOWLIST = Path(__file__).with_name("encoding_guard_allowlist.txt")

# What a UTF-8 continuation byte (0x80-0xBF) becomes when read as cp1252.
_CONTINUATION = "".join(bytes([b]).decode("cp1252", errors="ignore") for b in range(0x80, 0xC0))
# A two-byte lead read as cp1252 (Â Ã for U+0080-U+00FF; Å Æ Ä for Latin Extended), or the
# three-byte lead of U+2000-U+20FF (â€: dashes, quotes, ellipsis, euro).
MOJIBAKE = re.compile("[ÂÃÄÅÆ][" + re.escape(_CONTINUATION) + "]|â€")


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
    return any(rel == path and marker in line for path, marker in allow)


def docx_lines(path: Path):
    with zipfile.ZipFile(path) as z:
        for name in z.namelist():
            if name.endswith(".xml"):
                text = z.read(name).decode("utf-8", errors="replace")
                for i, line in enumerate(text.splitlines(), 1):
                    yield f"{name}:{i}", line


def scan(paths: list[Path], allow: list[tuple[str, str]]) -> list[str]:
    findings = []
    for path in paths:
        rel = path.resolve().relative_to(ROOT).as_posix() if path.resolve().is_relative_to(ROOT) else str(path)
        if path.suffix.lower() == ".docx":
            lines = docx_lines(path)
        else:
            lines = ((str(i), l) for i, l in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1))
        for where, line in lines:
            match = MOJIBAKE.search(line)
            if match and not allowed(rel, line, allow):
                findings.append(f"{rel}:{where}: {match.group(0)!r} in {line.strip()[:120]!r}")
    return findings


def tracked() -> list[Path]:
    out = subprocess.run(["git", "ls-files", "-z", "*.md", "*.MD", "*.docx"], cwd=ROOT,
                         capture_output=True, check=True).stdout.decode("utf-8")
    return [ROOT / p for p in out.split("\0") if p]


def main(argv: list[str]) -> int:
    paths = [Path(a) for a in argv] if argv else tracked()
    findings = scan(paths, load_allowlist())
    for f in findings:
        print(f)
    print(f"encoding guard: {len(paths)} files, {len(findings)} findings")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
