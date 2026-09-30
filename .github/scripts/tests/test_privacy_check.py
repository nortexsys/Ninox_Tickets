"""privacy_check passes on the tree and fails on planted personal-data patterns (T0.3)."""
from __future__ import annotations

import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import privacy_check as privacy  # noqa: E402


def luhn_check_digit(body: str) -> str:
    values = [int(c) for c in body + "0"]
    for i in range(len(values) - 2, -1, -2):
        values[i] *= 2
        if values[i] > 9:
            values[i] -= 9
    return str((10 - sum(values) % 10) % 10)


def make_luhn_card() -> str:
    body = "4" + "1" * 14
    return body + luhn_check_digit(body)


def make_uuid() -> str:
    return "01234567-89ab-cdef-0123-" + "456789abcdef"


def test_the_tracked_tree_is_clean():
    assert privacy.main([]) == 0


def test_a_valid_dni_fails_and_the_synthetic_one_passes(tmp_path):
    valid_dni = "12345678" + privacy.dni_letter("12345678")
    bad = tmp_path / "dni.txt"
    bad.write_text(valid_dni, encoding="utf-8")
    assert len(privacy.scan([bad], [])) == 1

    good = tmp_path / "synthetic.txt"
    good.write_text("12345679S", encoding="utf-8")
    assert privacy.scan([good], []) == []


def test_a_valid_luhn_card_fails(tmp_path):
    card = make_luhn_card()
    assert privacy.luhn_ok(card)
    planted = tmp_path / "card.txt"
    planted.write_text(card, encoding="utf-8")
    findings = privacy.scan([planted], [])
    assert len(findings) == 1 and "luhn" in findings[0]


def test_a_uuid_fails_and_a_40_hex_commit_id_passes(tmp_path):
    planted = tmp_path / "uuid.txt"
    planted.write_text(make_uuid(), encoding="utf-8")
    findings = privacy.scan([planted], [])
    assert len(findings) == 1 and "token" in findings[0]

    commit = tmp_path / "commit.txt"
    commit.write_text("0123456789abcdef0123456789abcdef01234567", encoding="utf-8")
    assert privacy.scan([commit], []) == []


def test_a_private_corpus_file_reference_fails(tmp_path):
    planted = tmp_path / "notes.md"
    planted.write_text("see " + "corpus_test/" + "out/ninox_log.json", encoding="utf-8")
    findings = privacy.scan([planted], [])
    assert len(findings) == 1 and "corpus-file" in findings[0]


def test_an_allowlisted_finding_passes_and_only_that_finding(tmp_path, monkeypatch):
    monkeypatch.setattr(privacy, "ROOT", tmp_path)
    planted = tmp_path / "notes.md"
    planted.write_text("see " + "corpus_test/" + "out/ninox_log.json" + " and " + make_uuid(), encoding="utf-8")
    allow = [("notes.md", "corpus_test/" + "out/ninox_log.json")]
    findings = privacy.scan([planted], allow)
    assert len(findings) == 1 and "token" in findings[0]


def test_a_token_inside_a_docx_fails(tmp_path):
    docx = tmp_path / "doc.docx"
    with zipfile.ZipFile(docx, "w") as z:
        z.writestr("word/document.xml", f"<w:t>{make_uuid()}</w:t>")
    findings = privacy.scan([docx], [])
    assert len(findings) == 1 and "word/document.xml" in findings[0]


# --- The allowlist file is scanned like any other file (qa-m1-week1, task C) ---
#
# Only synthetic values are used: a well-known published Luhn test card
# number (not a real card) and, where a Spanish identifier's shape is
# needed, DEC-001's synthetic tax id "12345679S" — which the DNI/NIE checker
# deliberately never flags, so the scenarios below that must produce a real
# finding use the Luhn number instead. It is built by concatenation, like the
# corpus-path literal above, so this test file's own source does not contain
# the contiguous digit run and is not itself a finding.

PUBLISHED_TEST_CARD = "4111" "1111" "1111" "1111"


def setup_allowlist(tmp_path, monkeypatch, allowlist_text: str) -> Path:
    """Point `privacy.ROOT` and `privacy.ALLOWLIST` at a synthetic tree so the
    allowlist self-check recognises the planted file as *the* allowlist."""
    monkeypatch.setattr(privacy, "ROOT", tmp_path)
    allowlist_path = tmp_path / "privacy_allowlist.txt"
    allowlist_path.write_text(allowlist_text, encoding="utf-8")
    monkeypatch.setattr(privacy, "ALLOWLIST", allowlist_path)
    return allowlist_path


def test_a_planted_identifier_in_the_allowlist_with_no_entry_fails(tmp_path, monkeypatch):
    # A comment, not a `path | text | reason` entry: load_allowlist() would
    # skip it, but the file is still scanned like any other text file.
    allowlist_path = setup_allowlist(
        tmp_path,
        monkeypatch,
        f"# for reference, see {PUBLISHED_TEST_CARD}\n",
    )
    findings = privacy.scan([allowlist_path], [])
    assert len(findings) == 1
    assert "no entry for another path" in findings[0]


def test_a_legitimate_entry_in_the_allowlist_passes(tmp_path, monkeypatch):
    allowlist_path = setup_allowlist(
        tmp_path,
        monkeypatch,
        f"some/path.txt | {PUBLISHED_TEST_CARD} | synthetic test card, used for regression coverage\n",
    )
    other = tmp_path / "some" / "path.txt"
    other.parent.mkdir(parents=True)
    other.write_text(PUBLISHED_TEST_CARD, encoding="utf-8")

    allow = [("some/path.txt", PUBLISHED_TEST_CARD)]
    findings = privacy.scan([allowlist_path, other], allow)
    assert findings == []


def test_a_stale_entry_in_the_allowlist_fails(tmp_path, monkeypatch):
    # The entry names a path that, in this run, does not produce the finding
    # it claims to justify (the file was not scanned, or no longer holds it).
    allowlist_path = setup_allowlist(
        tmp_path,
        monkeypatch,
        f"some/other.txt | {PUBLISHED_TEST_CARD} | synthetic test card, used for regression coverage\n",
    )
    allow = [("some/other.txt", PUBLISHED_TEST_CARD)]
    findings = privacy.scan([allowlist_path], allow)
    assert len(findings) == 1
    assert "stale entry" in findings[0]


def test_allowed_matches_the_finding_exactly_not_as_a_substring():
    # The docstring's claim ("matched against the finding's exact text") is
    # made true here: a marker that is only a substring of the finding does
    # not allow it.
    assert privacy.allowed("f.txt", PUBLISHED_TEST_CARD, [("f.txt", PUBLISHED_TEST_CARD[:-1])]) is False
    assert privacy.allowed("f.txt", PUBLISHED_TEST_CARD, [("f.txt", PUBLISHED_TEST_CARD)]) is True
