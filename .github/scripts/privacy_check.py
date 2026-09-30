"""Fail on tracked content that could leak a private-corpus document or a person.

Design §6 (setup-mvp-foundations): the privacy job is deliberately stricter than needed.
A false positive costs one line in privacy_allowlist.txt; a false negative publishes a
person. The check scans the text files tracked by git and the XML inside tracked .docx
files, and skips other binaries (a NUL byte in the first block marks a binary).

Findings:
  * a FILE inside the private corpus (``Paperdrop_corpus``, ``docs/corpus/``,
    ``corpus_test/inbox/``, ``corpus_test/out/`` followed by a file name with an
    extension); naming the folder itself is fine;
  * a Spanish DNI (8 digits + letter) or NIE (X/Y/Z + 7 digits + letter) with a valid
    check letter, other than the synthetic tax id ``12345679S`` (DEC-001);
  * a 13-19 digit number (optionally grouped by spaces or dashes) that passes Luhn;
  * a token-like string: ``sk-``/``sk-ant-`` + 20+ characters, ``Bearer `` + 20+
    characters, a UUID-shaped string, or a 32+ hex string that is not exactly 40
    characters (a git commit id). ``pubspec.lock`` is allowlisted as a whole file
    because it carries package hashes.

Usage:
    python .github/scripts/privacy_check.py            # the tracked tree
    python .github/scripts/privacy_check.py FILE ...   # given files (used by the tests)

The allowlist format is ``path | identifying text | reason``. For a text file ``path`` is
the repository-relative path; for a .docx member it is ``relative.docx:word/document.xml``.
``identifying text`` is matched against the finding's exact text (not a substring), so an
allowlisted line does not hide a different kind of finding on the same source line. ``*``
as the identifying text allowlists the whole file (used for pubspec.lock, which carries
package hashes).

``privacy_allowlist.txt`` itself is scanned like any other file — it is not exempt as a
whole file. It legitimately quotes the identifying text of its own entries (e.g. a hash),
which the scanner then finds inside it too. A finding located *inside the allowlist file*
is allowed only when its exact text is the identifying text of an entry for a *different*
path, and that entry is justified: the same run finds that exact text at the entry's own
path as well. An entry that names no real finding (stale — the source changed or the entry
was miscopied) or a string that merely resembles one, pasted into the file with no entry
backing it (e.g. in a comment), both fail the check.
"""
from __future__ import annotations

import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ALLOWLIST = Path(__file__).with_name("privacy_allowlist.txt")

DNI_LETTERS = "TRWAGMYFPDXBNJZSQVHLCKE"
NIE_PREFIX = {"X": 0, "Y": 1, "Z": 2}
SYNTHETIC_DNI = "12345679S"

# A path into the private corpus followed by a file name with an extension. The four
# folder names alone are fine; the file name after them is what would leak content.
CORPUS_FILE = re.compile(
    r"(?:Paperdrop_corpus|docs/corpus/|corpus_test/inbox/|corpus_test/out/)"
    r"[^\s\"')\]}>]*\.[A-Za-z0-9][A-Za-z0-9_\-]{0,12}"
)

DNI = re.compile(r"(?<![0-9])([0-9]{8})([A-Za-z])(?![0-9A-Za-z])")
NIE = re.compile(r"(?<![0-9])([XYZxyz])([0-9]{7})([A-Za-z])(?![0-9A-Za-z])")

# 13-19 digits, optionally grouped by spaces or dashes.
CARD_GROUP = re.compile(r"(?<!\d)(?:\d[\s\-]*){12,18}\d(?!\d)")

SK_TOKEN = re.compile(r"sk-ant-[A-Za-z0-9_\-]{20,}|sk-[A-Za-z0-9_\-]{20,}")
BEARER_TOKEN = re.compile(r"Bearer [A-Za-z0-9_\-\.]{20,}")
UUID = re.compile(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
HEX = re.compile(r"(?<![0-9A-Fa-f])([0-9a-fA-F]{32,})(?![0-9A-Fa-f])")


def luhn_ok(digits: str) -> bool:
    values = [int(c) for c in digits]
    for i in range(len(values) - 2, -1, -2):
        values[i] *= 2
        if values[i] > 9:
            values[i] -= 9
    return sum(values) % 10 == 0


def dni_letter(digits: str) -> str:
    return DNI_LETTERS[int(digits) % 23]


def nie_ok(prefix: str, digits: str, letter: str) -> bool:
    return dni_letter(str(NIE_PREFIX[prefix.upper()]) + digits) == letter.upper()


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


def allowed(rel: str, finding: str, allow: list[tuple[str, str]]) -> bool:
    return any(path == rel and (marker == "*" or marker == finding) for path, marker in allow)


def is_text(path: Path) -> bool:
    with path.open("rb") as fh:
        head = fh.read(8192)
    return b"\x00" not in head


def docx_lines(path: Path):
    with zipfile.ZipFile(path) as z:
        for name in z.namelist():
            if name.endswith(".xml"):
                text = z.read(name).decode("utf-8", errors="replace")
                for i, line in enumerate(text.splitlines(), 1):
                    yield name, i, line


def rel_for(path: Path) -> str:
    resolved = path.resolve()
    if resolved.is_relative_to(ROOT):
        return resolved.relative_to(ROOT).as_posix()
    return str(resolved)


def findings_in_line(rel: str, where: str, line: str) -> list[str]:
    out = []
    for m in CORPUS_FILE.finditer(line):
        out.append((rel, where, "corpus-file", m.group(0)))

    for m in DNI.finditer(line):
        digits, letter = m.group(1), m.group(2)
        value = m.group(0)
        if value.upper() != SYNTHETIC_DNI and dni_letter(digits) == letter.upper():
            out.append((rel, where, "dni-nie", value))
    for m in NIE.finditer(line):
        prefix, digits, letter = m.group(1), m.group(2), m.group(3)
        if nie_ok(prefix, digits, letter):
            out.append((rel, where, "dni-nie", m.group(0)))

    for m in CARD_GROUP.finditer(line):
        digits = re.sub(r"[\s\-]", "", m.group(0))
        if 13 <= len(digits) <= 19 and luhn_ok(digits):
            out.append((rel, where, "luhn", m.group(0)))

    for m in SK_TOKEN.finditer(line):
        out.append((rel, where, "token", m.group(0)))
    for m in BEARER_TOKEN.finditer(line):
        out.append((rel, where, "token", m.group(0)))
    for m in UUID.finditer(line):
        out.append((rel, where, "token", m.group(0)))
    for m in HEX.finditer(line):
        value = m.group(0)
        if len(value) != 40:
            out.append((rel, where, "token", value))

    return out


def raw_findings(path: Path, rel: str) -> list[tuple[str, str, str, str]]:
    """Every finding in `path` (already resolved to `rel`), before the
    allowlist is applied."""
    out = []
    if path.suffix.lower() == ".docx":
        for name, lineno, text in docx_lines(path):
            rel_member = f"{rel}:{name}"
            out.extend(findings_in_line(rel_member, str(lineno), text))
        return out

    if not is_text(path):
        return out
    text = path.read_text(encoding="utf-8", errors="replace")
    for lineno, line in enumerate(text.splitlines(), 1):
        out.extend(findings_in_line(rel, str(lineno), line))
    return out


def check_allowlist_self_findings(
    allowlist_items: list[tuple[str, str, str, str]],
    raw_by_rel: dict[str, list[tuple[str, str, str, str]]],
    allow: list[tuple[str, str]],
    allowlist_rel: str,
) -> list[str]:
    """`privacy_allowlist.txt` is not exempt as a whole file: a finding found
    *inside it* is allowed only if its exact text is the identifying text of
    an entry for a *different* path, and that entry is justified — the same
    run finds that exact text at the entry's own path too. A planted string
    with no backing entry, or an entry whose path no longer produces the
    finding it names (stale), both fail."""
    out = []
    for item in allowlist_items:
        rel, where, kind, value = item
        candidates = [
            (other_path, marker)
            for other_path, marker in allow
            if other_path != allowlist_rel and marker == value
        ]
        if not candidates:
            out.append(
                f"{rel}:{where}: {kind}: {value!r} — appears in the allowlist file with "
                "no entry for another path naming it (planted text, not a justified entry)"
            )
            continue

        justified = any(
            any(other_item[3] == marker for other_item in raw_by_rel.get(other_path, []))
            for other_path, marker in candidates
        )
        if not justified:
            named_paths = ", ".join(sorted({other_path for other_path, _ in candidates}))
            out.append(
                f"{rel}:{where}: {kind}: {value!r} — allowlisted for {named_paths!r} but "
                "that path no longer produces this finding (stale entry)"
            )
    return out


def scan(paths: list[Path], allow: list[tuple[str, str]]) -> list[str]:
    # Findings are grouped by their own `path` column (item[0]): the plain
    # repository-relative path for a text file, or `relative.docx:member.xml`
    # for a .docx member — the same key the allowlist's `path` column names,
    # so a lookup by that column (below, and in check_allowlist_self_findings)
    # finds the right group regardless of how many physical files it spans.
    allowlist_rel = rel_for(ALLOWLIST)
    raw_by_rel: dict[str, list[tuple[str, str, str, str]]] = {}
    for path in paths:
        rel = rel_for(path)
        for item in raw_findings(path, rel):
            raw_by_rel.setdefault(item[0], []).append(item)

    findings = []
    for key, items in raw_by_rel.items():
        if key == allowlist_rel:
            continue
        for item in items:
            if not allowed(item[0], item[3], allow):
                findings.append(format_finding(item))

    if allowlist_rel in raw_by_rel:
        findings.extend(
            check_allowlist_self_findings(raw_by_rel[allowlist_rel], raw_by_rel, allow, allowlist_rel)
        )

    return findings


def format_finding(item: tuple[str, str, str, str]) -> str:
    rel, where, kind, value = item
    return f"{rel}:{where}: {kind}: {value!r}"


def tracked() -> list[Path]:
    out = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT,
                         capture_output=True, check=True).stdout.decode("utf-8")
    return [ROOT / p for p in out.split("\0") if p]


def main(argv: list[str]) -> int:
    paths = [Path(a) for a in argv] if argv else tracked()
    findings = scan(paths, load_allowlist())
    for f in findings:
        print(f)
    print(f"privacy check: {len(paths)} files, {len(findings)} findings")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
