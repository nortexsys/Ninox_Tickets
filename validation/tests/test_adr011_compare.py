"""Tests for validation/adr011_compare.py (close-adr-011-pdf-text-route, task 2.1).

Every JSON and CSV read here is synthetic, written under `validation/tests/fixtures/adr011/`.
No file of the private corpus is read by this test, by the script, or by anything it imports.
"""
from __future__ import annotations

import csv
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import adr011_compare as m  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "adr011"
REPO_ROOT = Path(__file__).resolve().parents[2]


# --------------------------------------------------------------------------------------------
# Number parsing
# --------------------------------------------------------------------------------------------


def test_parse_amount_accepts_the_four_documented_formats():
    assert m.parse_amount_cents("1.234,56") == 123456
    assert m.parse_amount_cents("1,234.56") == 123456
    assert m.parse_amount_cents("1234,56") == 123456
    assert m.parse_amount_cents("1234.56") == 123456


def test_parse_amount_accepts_a_trailing_or_leading_currency_symbol_or_code():
    assert m.parse_amount_cents("19,99 EUR") == 1999
    assert m.parse_amount_cents("EUR 19,99") == 1999
    assert m.parse_amount_cents("€19,99") == 1999
    assert m.parse_amount_cents("$19.99") == 1999


def test_parse_amount_does_not_reject_a_registry_volume_shaped_token():
    # "8.741" is a thousands-grouped integer like any other: 8741.00, never rejected by shape.
    assert m.parse_amount_cents("8.741") == 874100


def test_parse_amount_handles_a_plain_integer_and_a_sign():
    assert m.parse_amount_cents("125.00") == 12500
    assert m.parse_amount_cents("4.000,00") == 400000
    assert m.parse_amount_cents("-19,99") == -1999


def test_parse_amount_rejects_a_non_number_token():
    assert m.parse_amount_cents("TOTAL") is None
    assert m.parse_amount_cents("") is None
    assert m.parse_amount_cents("Tomo") is None
    assert m.parse_amount_cents("19/99") is None


# --------------------------------------------------------------------------------------------
# Geometry: IoU and the matched share
# --------------------------------------------------------------------------------------------


def test_iou_of_identical_boxes_is_one():
    w = m.Word("x", 0.0, 10.0, 0.0, 10.0)
    assert m.iou(w, w) == 1.0


def test_iou_of_disjoint_boxes_is_zero():
    a = m.Word("x", 0.0, 10.0, 0.0, 10.0)
    b = m.Word("x", 100.0, 110.0, 100.0, 110.0)
    assert m.iou(a, b) == 0.0


def test_iou_boundary_just_above_and_below_half():
    # Two 10x10 boxes, one shifted right by 4 (area overlap 6x10=60, union=100+100-60=140,
    # iou=60/140≈0.4286 — below 0.5). Shifted by 2 instead gives overlap 8x10=80,
    # union=100+100-80=120, iou=80/120≈0.667 — above 0.5.
    a = m.Word("x", 0.0, 10.0, 0.0, 10.0)
    below_half = m.Word("x", 4.0, 14.0, 0.0, 10.0)
    above_half = m.Word("x", 2.0, 12.0, 0.0, 10.0)
    assert m.iou(a, below_half) < 0.5
    assert m.iou(a, above_half) >= 0.5


# --------------------------------------------------------------------------------------------
# Word matching (greedy, nearest centre, same text)
# --------------------------------------------------------------------------------------------


def test_match_words_pairs_identical_text_by_nearest_centre():
    # Two occurrences of "10,00" in the reference, two in the candidate, at swapped positions:
    # nearest-centre matching must pair each with the geometrically closest one, not the first.
    ref = [
        m.Word("10,00", 0.0, 20.0, 0.0, 10.0),
        m.Word("10,00", 100.0, 120.0, 0.0, 10.0),
    ]
    cand = [
        m.Word("10,00", 101.0, 121.0, 0.0, 10.0),  # nearer to ref[1]
        m.Word("10,00", 1.0, 21.0, 0.0, 10.0),  # nearer to ref[0]
    ]
    pairs = m.match_words(ref, cand)
    assert set(pairs) == {(0, 1), (1, 0)}


def test_match_words_never_matches_different_text():
    ref = [m.Word("TOTAL", 0.0, 20.0, 0.0, 10.0)]
    cand = [m.Word("SUBTOTAL", 0.0, 20.0, 0.0, 10.0)]
    assert m.match_words(ref, cand) == []


def test_match_words_is_one_to_one():
    ref = [m.Word("X", 0.0, 10.0, 0.0, 10.0)]
    cand = [
        m.Word("X", 0.0, 10.0, 0.0, 10.0),
        m.Word("X", 50.0, 60.0, 0.0, 10.0),
    ]
    pairs = m.match_words(ref, cand)
    assert len(pairs) == 1


# --------------------------------------------------------------------------------------------
# Line grouping
# --------------------------------------------------------------------------------------------


def test_group_lines_splits_two_vertically_separate_rows():
    words = [
        m.Word("A", 0.0, 10.0, 0.0, 12.0),
        m.Word("B", 20.0, 30.0, 0.0, 12.0),
        m.Word("C", 0.0, 10.0, 20.0, 32.0),
    ]
    lines = m.group_lines(words)
    assert len(lines) == 2
    assert lines[0] == [0, 1]  # "A","B" same row, left to right
    assert lines[1] == [2]


def test_group_lines_orders_lines_top_to_bottom_regardless_of_input_order():
    words = [
        m.Word("below", 0.0, 10.0, 100.0, 112.0),
        m.Word("above", 0.0, 10.0, 0.0, 12.0),
    ]
    lines = m.group_lines(words)
    assert [words[i].text for line in lines for i in line] == ["above", "below"]


# --------------------------------------------------------------------------------------------
# Total-label probe (hand-built pages, not file-based)
# --------------------------------------------------------------------------------------------


def test_probe_binds_same_line_to_the_right():
    words = [
        m.Word("TOTAL", 400.0, 440.0, 700.0, 712.0),
        m.Word("19,99", 460.0, 500.0, 700.0, 712.0),
    ]
    occurrences = m.find_label_occurrences(words)
    assert len(occurrences) == 1
    bbox = m._bbox_of(words, occurrences[0])
    bound = m.find_bound_word(words, set(occurrences[0]), bbox)
    assert bound is not None and bound.text == "19,99"


def test_probe_falls_through_to_next_line_below_when_nothing_is_to_the_right():
    words = [
        m.Word("TOTAL", 300.0, 340.0, 700.0, 712.0),
        m.Word("125,00", 310.0, 360.0, 730.0, 742.0),
    ]
    occurrences = m.find_label_occurrences(words)
    bbox = m._bbox_of(words, occurrences[0])
    bound = m.find_bound_word(words, set(occurrences[0]), bbox)
    assert bound is not None and bound.text == "125,00"


def test_probe_rejects_a_nearer_number_that_does_not_overlap_horizontally():
    # A registry-volume-shaped number on the closest line below, but off to the side: the correct
    # total is on a farther line, directly under the label. Layout decides, not vertical nearness
    # alone, and never the words' order in the file.
    words = [
        m.Word("TOTAL", 300.0, 340.0, 700.0, 712.0),
        m.Word("FACTURA", 344.0, 400.0, 700.0, 712.0),
        m.Word("8.741", 450.0, 480.0, 714.0, 726.0),  # nearest line, no horizontal overlap
        m.Word("125,00", 310.0, 360.0, 730.0, 742.0),  # farther line, overlaps horizontally
    ]
    occurrences = m.find_label_occurrences(words)
    assert len(occurrences) == 1
    assert set(occurrences[0]) == {0, 1}
    bbox = m._bbox_of(words, occurrences[0])
    bound = m.find_bound_word(words, set(occurrences[0]), bbox)
    assert bound is not None and bound.text == "125,00"


def test_probe_finds_no_amount_when_none_is_laid_out_right_or_below():
    words = [
        m.Word("TOTAL", 400.0, 440.0, 700.0, 712.0),
        m.Word("8.741", 0.0, 30.0, 700.0, 712.0),  # to the left, never considered
    ]
    occurrences = m.find_label_occurrences(words)
    bbox = m._bbox_of(words, occurrences[0])
    bound = m.find_bound_word(words, set(occurrences[0]), bbox)
    assert bound is None


def test_probe_reports_no_label_found_when_the_label_is_absent():
    words = [m.Word("FOO", 0.0, 10.0, 0.0, 12.0)]
    assert m.find_label_occurrences(words) == []


def test_probe_matches_a_multi_word_label_only_as_consecutive_words_on_one_line():
    words = [
        m.Word("TOTAL", 300.0, 340.0, 700.0, 712.0),
        m.Word("FACTURA", 344.0, 400.0, 700.0, 712.0),
    ]
    occurrences = m.find_label_occurrences(words)
    assert len(occurrences) == 1
    assert set(occurrences[0]) == {0, 1}


def test_probe_case_and_diacritic_insensitive():
    # "Total à payer" (fr), typed upper-case and with the accent dropped, as three separate words.
    words = [
        m.Word("TOTAL", 300.0, 340.0, 700.0, 712.0),
        m.Word("A", 344.0, 360.0, 700.0, 712.0),
        m.Word("PAYER", 364.0, 410.0, 700.0, 712.0),
    ]
    occurrences = m.find_label_occurrences(words)
    assert len(occurrences) == 1
    assert set(occurrences[0]) == {0, 1, 2}


def test_probe_tolerates_a_trailing_colon_and_binds_the_value_to_the_right():
    words = [
        m.Word("Total:", 400.0, 440.0, 700.0, 712.0),
        m.Word("19,99", 460.0, 500.0, 700.0, 712.0),
    ]
    occurrences = m.find_label_occurrences(words)
    assert len(occurrences) == 1
    assert set(occurrences[0]) == {0}
    bbox = m._bbox_of(words, occurrences[0])
    bound = m.find_bound_word(words, set(occurrences[0]), bbox)
    assert bound is not None and bound.text == "19,99"


def test_probe_tolerates_a_trailing_period_and_parentheses():
    assert len(m.find_label_occurrences([m.Word("TOTAL.", 0.0, 40.0, 0.0, 12.0)])) == 1
    assert len(m.find_label_occurrences([m.Word("(Total)", 0.0, 40.0, 0.0, 12.0)])) == 1


def test_probe_does_not_match_a_word_that_merely_contains_a_label():
    # "Subtotal:" starts with a letter, not punctuation, so nothing is stripped from that end —
    # it stays "subtotal", distinct from "total", and is correctly not an occurrence.
    words = [m.Word("Subtotal:", 0.0, 50.0, 0.0, 12.0)]
    assert m.find_label_occurrences(words) == []


def test_probe_tolerates_punctuation_on_a_multi_word_term():
    words = [
        m.Word("TOTAL", 300.0, 340.0, 700.0, 712.0),
        m.Word("FACTURA:", 344.0, 410.0, 700.0, 712.0),
    ]
    occurrences = m.find_label_occurrences(words)
    assert len(occurrences) == 1
    assert set(occurrences[0]) == {0, 1}


def test_total_probe_end_to_end_on_handwritten_words():
    doc = m.Doc(
        doc_id="x",
        tool="t",
        sha256="s",
        sha256_after="s",
        ms_per_page=(1.0,),
        pages=(
            m.Page(
                index=0,
                width=595.0,
                height=842.0,
                words=(
                    m.Word("TOTAL", 400.0, 440.0, 700.0, 712.0),
                    m.Word("19,99", 460.0, 500.0, 700.0, 712.0),
                ),
            ),
        ),
    )
    result = m.total_probe(doc, confirmed_cents=1999)
    assert result.outcome == "yes"
    assert result.occurrences == 1
    assert result.bound_confirmed == 1

    wrong = m.total_probe(doc, confirmed_cents=1234)
    assert wrong.outcome == "no"
    assert wrong.bound_confirmed == 0

    missing = m.total_probe(doc, confirmed_cents=None)
    assert missing.outcome == "not probed"


# --------------------------------------------------------------------------------------------
# Totals CSV
# --------------------------------------------------------------------------------------------


def test_load_totals_from_the_committed_semicolon_bom_fixture():
    totals = m.load_totals(FIXTURES / "totals-main.csv")
    assert totals == {
        "doc-01": 1999,
        "doc-02": 1999,
        "doc-03": 12500,
        "doc-04": None,
        "doc-05": 12500,
    }


def test_load_totals_detects_a_comma_delimiter_with_quoted_amounts(tmp_path):
    path = tmp_path / "totals.csv"
    path.write_text(
        "doc_id,total_propuesto_EUR,correcto_si_no,total_correcto_si_no\n"
        'doc-x,"1.234,56",si,si\n',
        encoding="utf-8",
    )
    totals = m.load_totals(path)
    assert totals == {"doc-x": 123456}


def test_load_totals_detects_a_semicolon_delimiter(tmp_path):
    path = tmp_path / "totals.csv"
    path.write_text(
        "doc_id;total_propuesto_EUR;correcto_si_no;total_correcto_si_no\n"
        "doc-y;125.00;si;si\n",
        encoding="utf-8",
    )
    totals = m.load_totals(path)
    assert totals == {"doc-y": 12500}


def test_load_totals_reads_a_bom(tmp_path):
    path = tmp_path / "totals.csv"
    path.write_bytes(
        "\ufeffdoc_id;total_propuesto_EUR;correcto_si_no;total_correcto_si_no\n"
        "doc-z;19,99;si;si\n".encode("utf-8")
    )
    totals = m.load_totals(path)
    assert totals == {"doc-z": 1999}


def test_load_totals_uses_the_override_column_when_not_confirmed(tmp_path):
    path = tmp_path / "totals.csv"
    path.write_text(
        "doc_id;total_propuesto_EUR;correcto_si_no;total_correcto_si_no;total_real_EUR\n"
        "doc-w;99,00;no;no;125,00\n",
        encoding="utf-8",
    )
    totals = m.load_totals(path)
    assert totals == {"doc-w": 12500}


def test_load_totals_is_missing_without_an_override_column(tmp_path):
    path = tmp_path / "totals.csv"
    path.write_text(
        "doc_id;total_propuesto_EUR;correcto_si_no;total_correcto_si_no\n"
        "doc-v;99,00;no;no\n",
        encoding="utf-8",
    )
    totals = m.load_totals(path)
    assert totals == {"doc-v": None}


def test_sniff_delimiter_falls_back_to_counting_when_sniffing_is_ambiguous():
    assert m.sniff_delimiter("a;b;c\n1;2;3\n") == ";"
    assert m.sniff_delimiter("a,b,c\n1,2,3\n") == ","


# --------------------------------------------------------------------------------------------
# Loading the extraction files
# --------------------------------------------------------------------------------------------


def test_discover_doc_ids_finds_every_reference_file():
    ids = m.discover_doc_ids(FIXTURES)
    assert ids == ["doc-01", "doc-02", "doc-03", "doc-04", "doc-05", "doc-06"]


def test_load_doc_reads_the_schema():
    doc = m.load_doc(FIXTURES / "doc-01.ref-pdfplumber-words.json")
    assert doc.doc_id == "doc-01"
    assert doc.sha256 == doc.sha256_after
    assert len(doc.pages) == 1
    assert doc.pages[0].words[0].text == "TOTAL"


# --------------------------------------------------------------------------------------------
# End-to-end report, against the five committed documents
# --------------------------------------------------------------------------------------------


def test_build_report_matches_the_crafted_fixture_set():
    from datetime import date

    text, data = m.build_report(
        FIXTURES, FIXTURES / "totals-main.csv", report_date=date(2026, 10, 2)
    )

    assert data["documents"] == 6
    assert data["missing_candidate_files"] == 0
    assert data["totals_missing"] == 2

    overall = data["overall"]
    assert overall["pdfbox-android"]["recall"] == 1.0
    assert overall["pdfbox-android"]["iou_share"] == 1.0
    assert round(overall["pdfbox-android"]["precision"], 4) == round(18 / 19, 4)
    assert round(overall["pdfrx"]["recall"], 4) == round(12 / 18, 4)
    assert round(overall["pdfrx"]["precision"], 4) == round(12 / 15, 4)
    assert round(overall["pdfrx"]["iou_share"], 4) == round(11 / 18, 4)

    probe = data["probe"]
    assert probe["doc-01"]["pdfbox-android"]["outcome"] == "yes"
    assert probe["doc-01"]["pdfrx"]["outcome"] == "yes"
    assert probe["doc-02"]["pdfbox-android"]["outcome"] == "yes"
    assert probe["doc-02"]["pdfrx"]["outcome"] == "yes"
    assert probe["doc-03"]["pdfbox-android"]["outcome"] == "yes"
    assert probe["doc-03"]["pdfrx"]["outcome"] == "no label found"
    assert probe["doc-04"]["pdfbox-android"]["outcome"] == "not probed"
    assert probe["doc-05"]["pdfbox-android"]["outcome"] == "no"
    assert probe["doc-05"]["pdfrx"]["outcome"] == "no"
    assert probe["doc-06"]["pdfbox-android"]["outcome"] == "not probed"
    assert probe["doc-06"]["pdfrx"]["outcome"] == "not probed"

    assert data["read_only_ok"]["pdfbox-android"]["doc-01"] is True
    assert data["read_only_ok"]["pdfrx"]["doc-01"] is False

    assert data["timing"]["pdfbox-android"]["median_ms"] == 10.0
    assert data["timing"]["pdfbox-android"]["max_ms"] == 14.0
    assert data["timing"]["pdfbox-android"]["pages"] == 6
    assert data["timing"]["pdfrx"]["median_ms"] == 8.0
    assert data["timing"]["pdfrx"]["max_ms"] == 9.0
    assert data["timing"]["pdfrx"]["pages"] == 6

    # doc-06: a candidate whose "words" are two multi-word runs — every word-level figure for it
    # is exactly zero, which is the bug this correction makes visible rather than hiding.
    assert "# ADR-011 comparison — 2026-10-02" in text
    assert "| doc-06 | 0 | 4 | 2 | 0.0% | 0.0% | 0.0% |" in text

    segmentation = data["segmentation"]
    assert segmentation["reference"]["whitespace_share"] == 0.0
    assert segmentation["pdfbox-android"]["whitespace_share"] == 0.0
    assert segmentation["pdfrx"]["whitespace_share"] == 0.2
    assert segmentation["reference"]["tokens"] == 18
    assert segmentation["pdfbox-android"]["tokens"] == 19
    assert segmentation["pdfrx"]["tokens"] == 15


# --------------------------------------------------------------------------------------------
# Segmentation — a candidate whose "words" are not words, reported rather than hidden
# --------------------------------------------------------------------------------------------


def _write_doc(path, doc_id, tool, words, sha="s", sha_after="s", ms=(1.0,)):
    path.write_text(
        json.dumps(
            {
                "doc_id": doc_id,
                "tool": tool,
                "sha256": sha,
                "sha256_after": sha_after,
                "ms_per_page": list(ms),
                "pages": [
                    {
                        "index": 0,
                        "width": 595.0,
                        "height": 842.0,
                        "words": [
                            {"text": t, "x0": i * 50.0, "x1": i * 50.0 + 40.0, "top": 0.0, "bottom": 12.0}
                            for i, t in enumerate(words)
                        ],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )


def test_segmentation_reports_whitespace_tokens_and_a_much_longer_median_length(tmp_path):
    # Reference: four five-character words, no whitespace in any of them — median length 5.
    _write_doc(
        tmp_path / "seg.ref-pdfplumber-words.json",
        "seg",
        "pdfplumber 0.11.4",
        ["AAAAA", "BBBBB", "CCCCC", "DDDDD"],
    )
    # Good candidate: the same four words, unchanged — no whitespace, median 5.
    _write_doc(
        tmp_path / "seg.pdfbox-android-words.json",
        "seg",
        "pdfbox-android 2.0.27.0",
        ["AAAAA", "BBBBB", "CCCCC", "DDDDD"],
    )
    # Bad candidate: two merged runs, 21 characters each, each containing one space.
    _write_doc(
        tmp_path / "seg.pdfrx-words.json",
        "seg",
        "pdfrx 0.5.0",
        ["AAAAAAAAAA BBBBBBBBBB", "CCCCCCCCCC DDDDDDDDDD"],
    )
    totals = tmp_path / "totals.csv"
    totals.write_text(
        "doc_id;total_propuesto_EUR;correcto_si_no;total_correcto_si_no\n", encoding="utf-8"
    )

    _, data = m.build_report(tmp_path, totals)
    seg = data["segmentation"]

    assert seg["reference"]["whitespace_share"] == 0.0
    assert seg["reference"]["median_token_length"] == 5
    assert seg["pdfbox-android"]["whitespace_share"] == 0.0
    assert seg["pdfbox-android"]["median_token_length"] == 5
    assert seg["pdfrx"]["whitespace_share"] == 1.0
    assert seg["pdfrx"]["median_token_length"] == 21

    # Every word-level figure for the bad candidate is zero — exactly the symptom reported, not
    # hidden behind a blank cell.
    overall = data["overall"]["pdfrx"]
    assert overall["recall"] == 0.0
    assert overall["precision"] == 0.0
    assert overall["iou_share"] == 0.0


def test_segmentation_whitespace_share_distinguishes_a_well_and_badly_segmented_candidate(
    tmp_path,
):
    _write_doc(tmp_path / "x.ref-pdfplumber-words.json", "x", "pdfplumber", ["ONE", "TWO"])
    _write_doc(tmp_path / "x.pdfbox-android-words.json", "x", "pdfbox-android", ["ONE", "TWO"])
    _write_doc(tmp_path / "x.pdfrx-words.json", "x", "pdfrx", ["ONE TWO"])
    totals = tmp_path / "totals.csv"
    totals.write_text(
        "doc_id;total_propuesto_EUR;correcto_si_no;total_correcto_si_no\n", encoding="utf-8"
    )

    _, data = m.build_report(tmp_path, totals)
    assert data["segmentation"]["pdfbox-android"]["whitespace_share"] == 0.0
    assert data["segmentation"]["pdfrx"]["whitespace_share"] == 1.0


# --------------------------------------------------------------------------------------------
# The report holds numbers only — never a sha256, a printed amount, or a path outside validation/
# --------------------------------------------------------------------------------------------


def test_report_never_contains_a_raw_sha256_value():
    text, _ = m.build_report(FIXTURES, FIXTURES / "totals-main.csv")
    for sha in (
        "sha-doc01-ref",
        "sha-doc01-a",
        "sha-doc01-b-before",
        "sha-doc01-b-after",
    ):
        assert sha not in text


def test_report_never_contains_a_printed_amount_or_the_confirmed_total():
    text, _ = m.build_report(FIXTURES, FIXTURES / "totals-main.csv")
    # Neither the document's own printed figures nor the confirmed totals the probe compared
    # against appear anywhere in the report — only whether the probe bound them.
    for forbidden in ("19,99", "19.99", "125,00", "125.00", "99,00", "3,47", "8.741"):
        assert forbidden not in text


def test_report_never_contains_a_private_corpus_path():
    text, _ = m.build_report(FIXTURES, FIXTURES / "totals-main.csv")
    assert "Paperdrop_corpus" not in text
    assert str(FIXTURES) not in text


def test_report_contains_only_numbers_and_the_fixed_vocabulary_for_probe_outcomes():
    text, _ = m.build_report(FIXTURES, FIXTURES / "totals-main.csv")
    probe_section = text.split("## Total-label probe", 1)[1].split("##", 1)[0]
    outcome_words = {"yes", "no", "no label found", "not probed"}
    for line in probe_section.splitlines():
        if not line.startswith("| doc-"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        assert cells[-1] in outcome_words


# --------------------------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------------------------


def test_cli_writes_the_report_and_optional_json(tmp_path):
    out = tmp_path / "report.md"
    out_json = tmp_path / "report.json"
    rc = m.main(
        [
            "--dir",
            str(FIXTURES),
            "--totals",
            str(FIXTURES / "totals-main.csv"),
            "--out",
            str(out),
            "--json",
            str(out_json),
        ]
    )
    assert rc == 0
    assert out.exists()
    assert out_json.exists()
    data = json.loads(out_json.read_text(encoding="utf-8"))
    assert data["documents"] == 6


def test_cli_as_a_subprocess(tmp_path):
    out = tmp_path / "report.md"
    script = REPO_ROOT / "validation" / "adr011_compare.py"
    result = subprocess.run(
        [
            sys.executable,
            str(script),
            "--dir",
            str(FIXTURES),
            "--totals",
            str(FIXTURES / "totals-main.csv"),
            "--out",
            str(out),
        ],
        cwd=str(REPO_ROOT),
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr
    assert out.exists()
    assert "ADR-011 comparison" in out.read_text(encoding="utf-8")


# --------------------------------------------------------------------------------------------
# The committed sample report
# --------------------------------------------------------------------------------------------


def test_expected_report_fixture_exists_and_is_privacy_clean():
    sample = FIXTURES / "expected-report.md"
    assert sample.exists(), (
        "validation/tests/fixtures/adr011/expected-report.md must be committed "
        "(generated from this test's fixtures)"
    )
    text = sample.read_text(encoding="utf-8")
    assert "ADR-011 comparison" in text
    for sha in ("sha-doc01-ref", "sha-doc01-a", "sha-doc01-b-before", "sha-doc01-b-after"):
        assert sha not in text
    for forbidden in ("19,99", "125,00", "99,00"):
        assert forbidden not in text
    assert "Paperdrop_corpus" not in text
