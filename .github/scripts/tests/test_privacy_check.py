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
