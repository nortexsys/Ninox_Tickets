"""core_purity passes on the tree and fails on a planted non-core import (T0.3)."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import core_purity as purity  # noqa: E402


def test_the_tracked_tree_is_clean():
    assert purity.main([]) == 0


def test_an_allowed_import_passes(tmp_path):
    dart = tmp_path / "core.dart"
    dart.write_text(
        "import 'dart:math';\n"
        "import 'dart:convert';\n"
        "import 'package:paperdrop_core/paperdrop_core.dart';\n"
        "import 'relative.dart';\n"
        "export 'src/model.dart';\n",
        encoding="utf-8",
    )
    assert purity.scan([dart]) == []


def test_a_planted_dart_io_import_fails(tmp_path):
    dart = tmp_path / "core.dart"
    dart.write_text("import 'dart:io';\n", encoding="utf-8")
    findings = purity.scan([dart])
    assert len(findings) == 1 and "dart:io" in findings[0]


def test_a_planted_package_import_fails(tmp_path):
    dart = tmp_path / "core.dart"
    dart.write_text("import 'package:http/http.dart';\n", encoding="utf-8")
    findings = purity.scan([dart])
    assert len(findings) == 1 and "package:http/http.dart" in findings[0]


def test_a_comment_mentioning_an_import_is_not_a_finding(tmp_path):
    dart = tmp_path / "core.dart"
    dart.write_text("// import 'dart:io';\n/// export 'package:http/http.dart';\n", encoding="utf-8")
    assert purity.scan([dart]) == []
