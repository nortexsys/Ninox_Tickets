"""no_ninox_db_id passes on the tree and fails on a planted mention (T0.3, GAP-012)."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import no_ninox_db_id as guard  # noqa: E402


def test_the_tracked_tree_is_clean():
    assert guard.main([]) == 0


def test_a_planted_mention_fails(tmp_path):
    dart = tmp_path / "main.dart"
    dart.write_text("final db = 'NINOX_DB_ID';\n", encoding="utf-8")
    assert len(guard.scan([dart], [])) == 1


def test_an_allowlisted_line_passes_and_only_that_line(tmp_path, monkeypatch):
    monkeypatch.setattr(guard, "ROOT", tmp_path)
    md = tmp_path / "notes.md"
    md.write_text("the rule bans NINOX_DB_ID\nbut this use of NINOX_DB_ID is not allowed\n", encoding="utf-8")
    findings = guard.scan([md], [("notes.md", "the rule bans")])
    assert len(findings) == 1 and ":2:" in findings[0]


def test_a_whole_file_allowlist_entry_passes(tmp_path, monkeypatch):
    monkeypatch.setattr(guard, "ROOT", tmp_path)
    md = tmp_path / "own-script.py"
    md.write_text("print('NINOX_DB_ID')\nprint('NINOX_DB_ID')\n", encoding="utf-8")
    assert guard.scan([md], [("own-script.py", "*")]) == []
