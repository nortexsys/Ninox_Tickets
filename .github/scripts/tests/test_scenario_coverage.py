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


def test_the_tracked_tree_has_no_orphan_tags():
    assert coverage.main([]) == 0
