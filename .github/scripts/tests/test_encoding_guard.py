"""The encoding guard catches double-encoded text in Markdown and inside a .docx (T0.10)."""
from __future__ import annotations

import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import encoding_guard as guard  # noqa: E402

BROKEN = "§ read twice".encode("utf-8").decode("cp1252")  # the GAP-024 defect, made on purpose


def test_the_tracked_tree_is_clean():
    assert guard.main([]) == 0


def test_a_planted_defect_in_markdown_fails(tmp_path):
    md = tmp_path / "spec.md"
    md.write_text(f"# Spec\n\nSee {BROKEN}.\n", encoding="utf-8")
    findings = guard.scan([md], [])
    assert len(findings) == 1 and ":3:" in findings[0]


def test_a_planted_defect_inside_a_docx_fails(tmp_path):
    docx = tmp_path / "doc.docx"
    with zipfile.ZipFile(docx, "w") as z:
        z.writestr("word/document.xml", f"<w:t>Clean</w:t>\n<w:t>{BROKEN}</w:t>")
        z.writestr("word/media/image1.png", b"\x89PNG not scanned")
    findings = guard.scan([docx], [])
    assert len(findings) == 1 and "word/document.xml:2" in findings[0]


def test_every_common_mojibake_is_caught_and_correct_text_is_not(tmp_path):
    good = "§ — “quoted” € ñ á é í ó ú ü Ñ · ° º ª ¿ ¡ … Ç"
    bad = good.encode("utf-8").decode("cp1252", errors="replace")
    md = tmp_path / "t.md"
    md.write_text(good, encoding="utf-8")
    assert guard.scan([md], []) == []
    md.write_text(bad, encoding="utf-8")
    assert guard.scan([md], [])


def test_an_allowlisted_line_passes_and_only_that_line(tmp_path, monkeypatch):
    monkeypatch.setattr(guard, "ROOT", tmp_path)
    md = tmp_path / "register.md"
    md.write_text(f"GAP-024 describes {BROKEN}\nand this is {BROKEN} too\n", encoding="utf-8")
    findings = guard.scan([md], [("register.md", "GAP-024 describes")])
    assert len(findings) == 1 and ":2:" in findings[0]
