"""scenario_coverage counts tagged tests and reports orphan tags (T0.7)."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import scenario_coverage as coverage  # noqa: E402


def write_spec(tmp_path: Path, capability: str, requirement: str, scenario: str) -> Path:
    spec_dir = tmp_path / "specs" / capability
    spec_dir.mkdir(parents=True)
    spec = spec_dir / "spec.md"
    spec.write_text(
        f"# Spec\n\n### Requirement: {requirement}\n\n#### Scenario: {scenario}\n",
        encoding="utf-8",
    )
    return spec


def write_test(tmp_path: Path, name: str) -> Path:
    test_dir = tmp_path / "packages" / "pkg" / "test"
    test_dir.mkdir(parents=True)
    dart = test_dir / "a_test.dart"
    dart.write_text(f"import 'package:test/test.dart';\n\nvoid main() {{\n  test('{name}', () {{}});\n}}\n", encoding="utf-8")
    return dart


def test_a_tagged_test_counts(tmp_path):
    spec = write_spec(tmp_path, "cap", "req", "does the thing")
    dart = write_test(tmp_path, "[cap/req] does the thing")
    specs = coverage.parse_specs([spec])
    tests = coverage.parse_tests([dart])
    covered, orphans = coverage.compute(specs, tests)
    assert covered[("cap", "req", "does the thing")] is True
    assert orphans == []


def test_a_wrong_scenario_name_does_not_count(tmp_path):
    spec = write_spec(tmp_path, "cap", "req", "does the thing")
    dart = write_test(tmp_path, "[cap/req] does something else")
    specs = coverage.parse_specs([spec])
    tests = coverage.parse_tests([dart])
    covered, orphans = coverage.compute(specs, tests)
    assert covered[("cap", "req", "does the thing")] is False
    assert orphans == []


def test_an_orphan_tag_is_reported(tmp_path):
    spec = write_spec(tmp_path, "cap", "req", "does the thing")
    dart = write_test(tmp_path, "[cap/missing] does the thing")
    specs = coverage.parse_specs([spec])
    tests = coverage.parse_tests([dart])
    covered, orphans = coverage.compute(specs, tests)
    assert orphans == [("[cap/missing]", "[cap/missing] does the thing", str(dart.resolve()))]


def write_multiline_test(tmp_path: Path, name: str) -> Path:
    """A `test(` call whose name string is on the line after the call, the
    shape `dart format` produces when the single-line call would not fit in
    80 columns."""
    test_dir = tmp_path / "packages" / "pkg" / "test"
    test_dir.mkdir(parents=True)
    dart = test_dir / "a_test.dart"
    dart.write_text(
        "import 'package:test/test.dart';\n\n"
        "void main() {\n"
        "  test(\n"
        f"    '{name}',\n"
        "    () {},\n"
        "  );\n"
        "}\n",
        encoding="utf-8",
    )
    return dart


def write_adjacent_literal_test(tmp_path: Path, part_one: str, part_two: str) -> Path:
    """A `test(` call whose name is two adjacent string literals (Dart's
    implicit string concatenation), each on its own line."""
    test_dir = tmp_path / "packages" / "pkg" / "test"
    test_dir.mkdir(parents=True)
    dart = test_dir / "a_test.dart"
    dart.write_text(
        "import 'package:test/test.dart';\n\n"
        "void main() {\n"
        "  test(\n"
        f"    '{part_one}'\n"
        f"    '{part_two}',\n"
        "    () {},\n"
        "  );\n"
        "}\n",
        encoding="utf-8",
    )
    return dart


def test_a_tag_moved_to_the_next_line_by_dart_format_still_counts(tmp_path):
    spec = write_spec(tmp_path, "cap", "req", "does the thing")
    dart = write_multiline_test(tmp_path, "[cap/req] does the thing")
    specs = coverage.parse_specs([spec])
    tests = coverage.parse_tests([dart])
    covered, orphans = coverage.compute(specs, tests)
    assert covered[("cap", "req", "does the thing")] is True
    assert orphans == []


def test_a_tag_split_across_adjacent_string_literals_still_counts(tmp_path):
    spec = write_spec(tmp_path, "cap", "req", "does the thing")
    dart = write_adjacent_literal_test(tmp_path, "[cap/req] does ", "the thing")
    specs = coverage.parse_specs([spec])
    tests = coverage.parse_tests([dart])
    covered, orphans = coverage.compute(specs, tests)
    assert covered[("cap", "req", "does the thing")] is True
    assert orphans == []


def test_the_real_tree_counts_the_provenance_tag_moved_by_dart_format():
    """Regression for the real example: `test(` and the tagged string are on
    different lines in `canonical_document_test.dart`."""
    path = coverage.ROOT / "packages" / "paperdrop_core" / "test" / "model" / "canonical_document_test.dart"
    tests = coverage.parse_tests([path])
    names = [name for name, _file in tests]
    assert any(
        "[extraction-pipeline/provenance-on-every-value] every value is tagged" in name
        for name in names
    )


def test_the_tracked_tree_has_no_orphan_tags():
    assert coverage.main([]) == 0
