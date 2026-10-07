"""ADR-011 comparison script — word positional fidelity and the total-label probe.

Design: `openspec/changes/close-adr-011-pdf-text-route/design.md` §1-§2.
Task: `openspec/changes/close-adr-011-pdf-text-route/tasks.md` 2.1.

Reads, per document, three JSON files of one shape (design §2) from `--dir`:

    <doc_id>.ref-pdfplumber-words.json     the reference extraction (pdfplumber)
    <doc_id>.pdfbox-android-words.json     candidate A
    <doc_id>.pdfrx-words.json              candidate B

and a totals CSV (`--totals`), and writes a Markdown report (`--out`) holding **numbers only**:
never a document's text, a printed value, an amount, a supplier name, an identifier read from a
document, or a file path of the private corpus. The confirmed total itself is never printed either
— the report says only whether the total-label probe bound it.

Standard library only. No document of the private corpus is read by this file; every test runs on
synthetic JSON fixtures under `validation/tests/fixtures/adr011/`.

Usage:
    python validation/adr011_compare.py --dir <folder of JSONs> --totals <totals csv> \
        --out <report.md> [--json <report.json>]
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import re
import statistics
import sys
import unicodedata
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path
from typing import Iterable, Optional

CANDIDATES: tuple[str, ...] = ("pdfbox-android", "pdfrx")
REFERENCE_SUFFIX = "ref-pdfplumber-words"

# `LabelKind.total` terms, copied verbatim from
# `packages/paperdrop_core/lib/src/dictionaries/labels.dart` (Funcional Annex C). This script does
# not read the Dart source at run time — it is a small, stable, public list, copied once — and
# QA never edits `lib/`.
TOTAL_LABELS: tuple[str, ...] = (
    "A PAGAR",
    "TOTAL",
    "TOTAL A PAGAR",
    "IMPORTE TOTAL",
    "TOTAL FACTURA",
    "TOTAL GENERAL",
    "SUMA TOTAL",
    "Zu zahlen",
    "Gesamtbetrag",
    "Endbetrag",
    "Rechnungsbetrag",
    "Total",
    "Total TTC",
    "Montant TTC",
    "Total à payer",
    "Importo",
    "Totale",
    "Totale fattura",
)

_FIXED_TOTALS_COLUMNS = {
    "doc_id",
    "total_propuesto_eur",
    "correcto_si_no",
    "total_correcto_si_no",
}


# --------------------------------------------------------------------------------------------
# Value types
# --------------------------------------------------------------------------------------------


@dataclass(frozen=True)
class Word:
    """One positioned word, in PDF points with a top-left origin (design §2)."""

    text: str
    x0: float
    x1: float
    top: float
    bottom: float

    @property
    def height(self) -> float:
        return self.bottom - self.top

    @property
    def width(self) -> float:
        return self.x1 - self.x0

    @property
    def cx(self) -> float:
        return (self.x0 + self.x1) / 2

    @property
    def cy(self) -> float:
        return (self.top + self.bottom) / 2


@dataclass(frozen=True)
class Page:
    """One page of positioned words."""

    index: int
    width: float
    height: float
    words: tuple[Word, ...]


@dataclass(frozen=True)
class Doc:
    """One extraction file: a document read by one tool (reference or candidate)."""

    doc_id: str
    tool: str
    sha256: str
    sha256_after: str
    ms_per_page: tuple[float, ...]
    pages: tuple[Page, ...]


@dataclass
class PageStats:
    """Word-level comparison of one page, candidate against reference."""

    page_index: int
    ref_words: int
    cand_words: int
    matched: int
    iou_hits: int

    @property
    def recall(self) -> Optional[float]:
        return (self.matched / self.ref_words) if self.ref_words else None

    @property
    def precision(self) -> Optional[float]:
        return (self.matched / self.cand_words) if self.cand_words else None

    @property
    def iou_share(self) -> Optional[float]:
        return (self.iou_hits / self.ref_words) if self.ref_words else None


@dataclass
class DocCandidateStats:
    """A candidate's word-level stats for one document, aggregated over its pages."""

    doc_id: str
    candidate: str
    pages: list[PageStats] = field(default_factory=list)

    @property
    def ref_words(self) -> int:
        return sum(p.ref_words for p in self.pages)

    @property
    def cand_words(self) -> int:
        return sum(p.cand_words for p in self.pages)

    @property
    def matched(self) -> int:
        return sum(p.matched for p in self.pages)

    @property
    def iou_hits(self) -> int:
        return sum(p.iou_hits for p in self.pages)

    @property
    def recall(self) -> Optional[float]:
        return (self.matched / self.ref_words) if self.ref_words else None

    @property
    def precision(self) -> Optional[float]:
        return (self.matched / self.cand_words) if self.cand_words else None

    @property
    def iou_share(self) -> Optional[float]:
        return (self.iou_hits / self.ref_words) if self.ref_words else None


@dataclass
class ProbeResult:
    """The outcome of the total-label probe on one document, for one candidate."""

    outcome: str  # "yes" | "no" | "no label found" | "not probed"
    occurrences: int
    bound_confirmed: int


# --------------------------------------------------------------------------------------------
# Loading
# --------------------------------------------------------------------------------------------


def load_doc(path: Path) -> Doc:
    """Reads one extraction file in the schema of design §2."""
    raw = json.loads(path.read_text(encoding="utf-8"))
    pages: list[Page] = []
    for raw_page in raw.get("pages", []):
        words = tuple(
            Word(
                text=str(w["text"]),
                x0=float(w["x0"]),
                x1=float(w["x1"]),
                top=float(w["top"]),
                bottom=float(w["bottom"]),
            )
            for w in raw_page.get("words", [])
        )
        pages.append(
            Page(
                index=int(raw_page["index"]),
                width=float(raw_page.get("width", 0.0)),
                height=float(raw_page.get("height", 0.0)),
                words=words,
            )
        )
    ms_per_page = tuple(float(x) for x in raw.get("ms_per_page", []))
    return Doc(
        doc_id=str(raw.get("doc_id", path.stem)),
        tool=str(raw.get("tool", "")),
        sha256=str(raw.get("sha256", "")),
        sha256_after=str(raw.get("sha256_after", "")),
        ms_per_page=ms_per_page,
        pages=tuple(pages),
    )


def discover_doc_ids(directory: Path) -> list[str]:
    """Every `doc_id` that has a reference file in `directory`, sorted."""
    suffix = f".{REFERENCE_SUFFIX}.json"
    ids = sorted(
        p.name[: -len(suffix)] for p in directory.glob(f"*{suffix}") if p.name.endswith(suffix)
    )
    return ids


def candidate_path(directory: Path, doc_id: str, candidate: str) -> Path:
    return directory / f"{doc_id}.{candidate}-words.json"


def reference_path(directory: Path, doc_id: str) -> Path:
    return directory / f"{doc_id}.{REFERENCE_SUFFIX}.json"


# --------------------------------------------------------------------------------------------
# Geometry
# --------------------------------------------------------------------------------------------


def iou(a: Word, b: Word) -> float:
    """Intersection-over-union of two boxes. Zero when they do not overlap or either is empty."""
    ix0 = max(a.x0, b.x0)
    iy0 = max(a.top, b.top)
    ix1 = min(a.x1, b.x1)
    iy1 = min(a.bottom, b.bottom)
    iw = max(0.0, ix1 - ix0)
    ih = max(0.0, iy1 - iy0)
    inter = iw * ih
    area_a = max(0.0, a.width) * max(0.0, a.height)
    area_b = max(0.0, b.width) * max(0.0, b.height)
    union = area_a + area_b - inter
    if union <= 0:
        return 0.0
    return inter / union


def _centre_distance(a: Word, b: Word) -> float:
    return ((a.cx - b.cx) ** 2 + (a.cy - b.cy) ** 2) ** 0.5


def _vertical_overlap_ratio(a: Word, b: Word) -> float:
    """Vertical overlap of `a` and `b`, as a share of the shorter of the two heights."""
    overlap = max(0.0, min(a.bottom, b.bottom) - max(a.top, b.top))
    shorter = min(a.height, b.height)
    if shorter <= 0:
        return 0.0
    return overlap / shorter


def match_words(ref_words: Iterable[Word], cand_words: Iterable[Word]) -> list[tuple[int, int]]:
    """Greedy one-to-one matching by identical `text`, nearest box centre first (design §2).

    Returns `(ref_index, cand_index)` pairs. A word of the reference or the candidate matches at
    most once.
    """
    ref_list = list(ref_words)
    cand_list = list(cand_words)
    ref_by_text: dict[str, list[int]] = defaultdict(list)
    for i, w in enumerate(ref_list):
        ref_by_text[w.text].append(i)
    cand_by_text: dict[str, list[int]] = defaultdict(list)
    for j, w in enumerate(cand_list):
        cand_by_text[w.text].append(j)

    candidates: list[tuple[float, int, int]] = []
    for text, ref_idxs in ref_by_text.items():
        cand_idxs = cand_by_text.get(text)
        if not cand_idxs:
            continue
        for i in ref_idxs:
            for j in cand_idxs:
                candidates.append((_centre_distance(ref_list[i], cand_list[j]), i, j))
    candidates.sort(key=lambda t: (t[0], t[1], t[2]))

    used_ref: set[int] = set()
    used_cand: set[int] = set()
    pairs: list[tuple[int, int]] = []
    for _, i, j in candidates:
        if i in used_ref or j in used_cand:
            continue
        used_ref.add(i)
        used_cand.add(j)
        pairs.append((i, j))
    return pairs


def group_lines(words: Iterable[Word]) -> list[list[int]]:
    """Groups word indices into lines by mutual vertical overlap >= half the shorter height —
    the same criterion the total-label probe uses for "same line" (design §1.2). Each line is
    sorted left to right; the lines themselves are sorted top to bottom."""
    word_list = list(words)
    n = len(word_list)
    parent = list(range(n))

    def find(x: int) -> int:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a: int, b: int) -> None:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb

    for i in range(n):
        for j in range(i + 1, n):
            if _vertical_overlap_ratio(word_list[i], word_list[j]) >= 0.5:
                union(i, j)

    groups: dict[int, list[int]] = defaultdict(list)
    for i in range(n):
        groups[find(i)].append(i)
    lines = list(groups.values())
    for line in lines:
        line.sort(key=lambda i: word_list[i].x0)
    lines.sort(key=lambda line: sum(word_list[i].cy for i in line) / len(line))
    return lines


# --------------------------------------------------------------------------------------------
# Number parsing (totals file and page words)
# --------------------------------------------------------------------------------------------

_NUMBER_BODY = re.compile(r"-?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?|-?\d+(?:[.,]\d{1,2})?")
_LEADING_NON_NUMERIC = re.compile(r"^[^\d\-]+")
_TRAILING_NON_NUMERIC = re.compile(r"[^\d.,]+$")


def parse_amount_cents(token: str) -> Optional[int]:
    """Parses a number shaped like `1.234,56`, `1,234.56`, `1234,56` or `1234.56`, with an
    optional leading or trailing currency symbol or code, into an integer count of cents.

    Returns `None` for anything that is not a number this way. A bare `8.741`-shaped token is not
    rejected for looking like a registry volume: it is read as `8741.00`, exactly like any other
    thousands-grouped integer — the probe's job is to bind a number by layout, never to reject one
    by shape (design §1.2).
    """
    text = token.strip()
    if not text:
        return None
    cleaned = _LEADING_NON_NUMERIC.sub("", text)
    cleaned = _TRAILING_NON_NUMERIC.sub("", cleaned)
    cleaned = cleaned.strip()
    if not cleaned:
        return None
    match = _NUMBER_BODY.fullmatch(cleaned)
    if not match:
        return None

    negative = cleaned.startswith("-")
    body = cleaned[1:] if negative else cleaned
    last_dot = body.rfind(".")
    last_comma = body.rfind(",")
    last_sep = max(last_dot, last_comma)
    if last_sep == -1:
        integer_part = body
        decimal_part = "00"
    else:
        tail = body[last_sep + 1 :]
        if len(tail) in (1, 2):
            decimal_part = tail.ljust(2, "0")
            integer_part = body[:last_sep]
        else:
            decimal_part = "00"
            integer_part = body
        integer_part = integer_part.replace(".", "").replace(",", "")
    if integer_part == "":
        integer_part = "0"
    if not integer_part.isdigit() or not decimal_part.isdigit():
        return None
    cents = int(integer_part) * 100 + int(decimal_part)
    return -cents if negative else cents


def is_number_token(token: str) -> bool:
    return parse_amount_cents(token) is not None


# --------------------------------------------------------------------------------------------
# Total-label probe
# --------------------------------------------------------------------------------------------


def _normalize(text: str) -> str:
    """Case- and diacritic-insensitive form for label matching."""
    decomposed = unicodedata.normalize("NFKD", text)
    stripped = "".join(c for c in decomposed if not unicodedata.combining(c))
    return stripped.casefold()


def _label_word_lists() -> list[list[str]]:
    """Every total label, as a list of normalized words, longest term first so that
    `TOTAL A PAGAR` is matched before the shorter `TOTAL` or `A PAGAR` it contains."""
    seen: set[tuple[str, ...]] = set()
    lists: list[list[str]] = []
    for term in TOTAL_LABELS:
        words = _normalize(term).split()
        key = tuple(words)
        if key in seen:
            continue
        seen.add(key)
        lists.append(words)
    lists.sort(key=len, reverse=True)
    return lists


_LABEL_WORD_LISTS = _label_word_lists()


def _bbox_of(words: list[Word], idxs: Iterable[int]) -> Word:
    idxs = list(idxs)
    return Word(
        text="",
        x0=min(words[i].x0 for i in idxs),
        x1=max(words[i].x1 for i in idxs),
        top=min(words[i].top for i in idxs),
        bottom=max(words[i].bottom for i in idxs),
    )


def find_label_occurrences(words: list[Word]) -> list[list[int]]:
    """Every occurrence of a total label on the page, in reading order; a multi-word label only
    matches consecutive words on the same line (design §1.2). Returns each occurrence as the list
    of word indices it spans."""
    occurrences: list[list[int]] = []
    for line in group_lines(words):
        normalized = [_normalize(words[i].text) for i in line]
        used: set[int] = set()
        for label_words in _LABEL_WORD_LISTS:
            k = len(label_words)
            if k == 0 or k > len(line):
                continue
            for start in range(len(line) - k + 1):
                span = line[start : start + k]
                if any(i in used for i in span):
                    continue
                if normalized[start : start + k] == label_words:
                    used.update(span)
                    occurrences.append(span)
    return occurrences


def find_bound_word(
    words: list[Word], label_idxs: set[int], label_bbox: Word
) -> Optional[Word]:
    """Binds a total label to the nearest numeric word to its right on the same line, else the
    nearest numeric word on the next line below that overlaps it horizontally — by layout only,
    never by the words' order in the file (design §1.2)."""
    same_line: list[tuple[float, Word]] = []
    for i, w in enumerate(words):
        if i in label_idxs or not is_number_token(w.text):
            continue
        if _vertical_overlap_ratio(w, label_bbox) >= 0.5 and w.x0 >= label_bbox.x1:
            same_line.append((w.x0 - label_bbox.x1, w))
    if same_line:
        same_line.sort(key=lambda t: t[0])
        return same_line[0][1]

    below: list[tuple[float, float, Word]] = []
    for i, w in enumerate(words):
        if i in label_idxs or not is_number_token(w.text):
            continue
        if w.top >= label_bbox.bottom - 1e-6:
            h_overlap = max(0.0, min(w.x1, label_bbox.x1) - max(w.x0, label_bbox.x0))
            if h_overlap > 0:
                below.append((w.top - label_bbox.bottom, abs(w.cx - label_bbox.cx), w))
    if below:
        below.sort(key=lambda t: (t[0], t[1]))
        return below[0][2]
    return None


def total_probe(doc: Doc, confirmed_cents: Optional[int]) -> ProbeResult:
    """The total-label probe over every page of `doc`, against `confirmed_cents`."""
    if confirmed_cents is None:
        return ProbeResult(outcome="not probed", occurrences=0, bound_confirmed=0)

    occurrences = 0
    bound_confirmed = 0
    for page in doc.pages:
        words = list(page.words)
        for span in find_label_occurrences(words):
            occurrences += 1
            bbox = _bbox_of(words, span)
            bound = find_bound_word(words, set(span), bbox)
            if bound is not None:
                cents = parse_amount_cents(bound.text)
                if cents is not None and cents == confirmed_cents:
                    bound_confirmed += 1

    if occurrences == 0:
        outcome = "no label found"
    elif bound_confirmed > 0:
        outcome = "yes"
    else:
        outcome = "no"
    return ProbeResult(outcome=outcome, occurrences=occurrences, bound_confirmed=bound_confirmed)


# --------------------------------------------------------------------------------------------
# Totals CSV
# --------------------------------------------------------------------------------------------


def sniff_delimiter(sample: str) -> str:
    """Detects `;` or `,` as the delimiter; falls back to counting when sniffing fails (the
    totals file's delimiter is not fixed)."""
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=";,")
        return dialect.delimiter
    except csv.Error:
        semi = sample.count(";")
        comma = sample.count(",")
        return ";" if semi >= comma else ","


def load_totals(path: Path) -> dict[str, Optional[int]]:
    """Reads the totals CSV (BOM-tolerant, delimiter detected) into `doc_id -> confirmed cents`.

    The confirmed total is `total_propuesto_EUR` when `total_correcto_si_no` is `si`; otherwise it
    is read from the first non-empty column the PO filled in instead, among the columns the fixed
    four do not name. A document with no usable value anywhere is `None` (reported as "totals
    missing", never invented).
    """
    text = path.read_text(encoding="utf-8-sig")
    if not text.strip():
        return {}
    delimiter = sniff_delimiter(text[:4096])
    reader = csv.DictReader(io.StringIO(text), delimiter=delimiter)
    fieldnames = reader.fieldnames or []
    lower_to_actual = {name.strip().lower(): name for name in fieldnames}
    override_columns = [
        name for name in fieldnames if name.strip().lower() not in _FIXED_TOTALS_COLUMNS
    ]

    def col(row: dict[str, str], key: str) -> str:
        actual = lower_to_actual.get(key)
        if actual is None:
            return ""
        return (row.get(actual) or "").strip()

    totals: dict[str, Optional[int]] = {}
    for row in reader:
        doc_id = col(row, "doc_id")
        if not doc_id:
            continue
        confirmed_flag = col(row, "total_correcto_si_no").lower()
        cents: Optional[int] = None
        if confirmed_flag == "si":
            cents = parse_amount_cents(col(row, "total_propuesto_eur"))
        else:
            for column in override_columns:
                value = (row.get(column) or "").strip()
                if value:
                    cents = parse_amount_cents(value)
                    if cents is not None:
                        break
        totals[doc_id] = cents
    return totals


# --------------------------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------------------------


def _fmt_ratio(value: Optional[float]) -> str:
    return "—" if value is None else f"{value * 100:.1f}%"


def _fmt_ms(value: Optional[float]) -> str:
    return "—" if value is None else f"{value:.1f}"


def build_report(
    directory: Path, totals_path: Path, report_date: Optional[date] = None
) -> tuple[str, dict]:
    """Builds the Markdown report text and the equivalent JSON-serialisable data.

    `report_date` is overridable so a test can pin a deterministic date for a committed sample
    report; the default is today.
    """
    report_date = report_date or date.today()
    doc_ids = discover_doc_ids(directory)
    totals = load_totals(totals_path)

    tool_versions: dict[str, set[str]] = {c: set() for c in CANDIDATES}
    doc_candidate_stats: dict[str, dict[str, DocCandidateStats]] = {}
    probe_results: dict[str, dict[str, ProbeResult]] = {}
    read_only_ok: dict[str, dict[str, bool]] = {}
    ms_pooled: dict[str, list[float]] = {c: [] for c in CANDIDATES}
    missing_files: list[tuple[str, str]] = []
    totals_missing: list[str] = []

    for doc_id in doc_ids:
        ref_path = reference_path(directory, doc_id)
        ref_doc = load_doc(ref_path)
        ref_pages_by_index = {p.index: p for p in ref_doc.pages}

        confirmed_cents = totals.get(doc_id)
        if doc_id not in totals or confirmed_cents is None:
            totals_missing.append(doc_id)

        doc_candidate_stats[doc_id] = {}
        probe_results[doc_id] = {}
        read_only_ok[doc_id] = {}

        for candidate in CANDIDATES:
            cpath = candidate_path(directory, doc_id, candidate)
            if not cpath.exists():
                missing_files.append((doc_id, candidate))
                continue
            cand_doc = load_doc(cpath)
            if cand_doc.tool:
                tool_versions[candidate].add(cand_doc.tool)
            ms_pooled[candidate].extend(cand_doc.ms_per_page)
            read_only_ok[doc_id][candidate] = cand_doc.sha256 == cand_doc.sha256_after

            stats = DocCandidateStats(doc_id=doc_id, candidate=candidate)
            cand_pages_by_index = {p.index: p for p in cand_doc.pages}
            all_page_indices = sorted(set(ref_pages_by_index) | set(cand_pages_by_index))
            for index in all_page_indices:
                ref_page = ref_pages_by_index.get(index)
                cand_page = cand_pages_by_index.get(index)
                ref_words = list(ref_page.words) if ref_page else []
                cand_words = list(cand_page.words) if cand_page else []
                pairs = match_words(ref_words, cand_words)
                iou_hits = sum(1 for i, j in pairs if iou(ref_words[i], cand_words[j]) >= 0.5)
                stats.pages.append(
                    PageStats(
                        page_index=index,
                        ref_words=len(ref_words),
                        cand_words=len(cand_words),
                        matched=len(pairs),
                        iou_hits=iou_hits,
                    )
                )
            doc_candidate_stats[doc_id][candidate] = stats
            probe_results[doc_id][candidate] = total_probe(cand_doc, confirmed_cents)

    lines: list[str] = []
    lines.append(f"# ADR-011 comparison — {report_date.isoformat()}")
    lines.append("")
    lines.append(
        "Candidates segment words their own way (design §2): word counts differ by design. "
        "The IoU ≥ 0.5 share, not the word count, is the comparable figure."
    )
    lines.append("")
    lines.append(f"Documents compared: {len(doc_ids)}.")
    if missing_files:
        lines.append(f"Missing candidate files: {len(missing_files)}.")
    lines.append("")

    lines.append("## Tool versions")
    lines.append("")
    for candidate in CANDIDATES:
        versions = sorted(tool_versions[candidate])
        shown = ", ".join(versions) if versions else "—"
        lines.append(f"- `{candidate}`: {shown}")
    lines.append("")

    lines.append("## Per-page word-level fidelity")
    lines.append("")
    for candidate in CANDIDATES:
        lines.append(f"### {candidate}")
        lines.append("")
        lines.append("| doc_id | page | ref words | cand words | recall | precision | IoU≥0.5 share |")
        lines.append("| --- | --- | --- | --- | --- | --- | --- |")
        for doc_id in doc_ids:
            stats = doc_candidate_stats.get(doc_id, {}).get(candidate)
            if stats is None:
                continue
            for p in stats.pages:
                lines.append(
                    f"| {doc_id} | {p.page_index} | {p.ref_words} | {p.cand_words} | "
                    f"{_fmt_ratio(p.recall)} | {_fmt_ratio(p.precision)} | {_fmt_ratio(p.iou_share)} |"
                )
        lines.append("")

    lines.append("## Per-document totals")
    lines.append("")
    for candidate in CANDIDATES:
        lines.append(f"### {candidate}")
        lines.append("")
        lines.append("| doc_id | ref words | cand words | recall | precision | IoU≥0.5 share |")
        lines.append("| --- | --- | --- | --- | --- | --- |")
        for doc_id in doc_ids:
            stats = doc_candidate_stats.get(doc_id, {}).get(candidate)
            if stats is None:
                continue
            lines.append(
                f"| {doc_id} | {stats.ref_words} | {stats.cand_words} | "
                f"{_fmt_ratio(stats.recall)} | {_fmt_ratio(stats.precision)} | "
                f"{_fmt_ratio(stats.iou_share)} |"
            )
        lines.append("")

    lines.append("## Overall")
    lines.append("")
    lines.append("| candidate | ref words | cand words | recall | precision | IoU≥0.5 share |")
    lines.append("| --- | --- | --- | --- | --- | --- |")
    overall: dict[str, dict] = {}
    for candidate in CANDIDATES:
        ref_total = cand_total = matched_total = iou_total = 0
        for doc_id in doc_ids:
            stats = doc_candidate_stats.get(doc_id, {}).get(candidate)
            if stats is None:
                continue
            ref_total += stats.ref_words
            cand_total += stats.cand_words
            matched_total += stats.matched
            iou_total += stats.iou_hits
        recall = (matched_total / ref_total) if ref_total else None
        precision = (matched_total / cand_total) if cand_total else None
        iou_share = (iou_total / ref_total) if ref_total else None
        overall[candidate] = {
            "ref_words": ref_total,
            "cand_words": cand_total,
            "matched": matched_total,
            "iou_hits": iou_total,
            "recall": recall,
            "precision": precision,
            "iou_share": iou_share,
        }
        lines.append(
            f"| {candidate} | {ref_total} | {cand_total} | {_fmt_ratio(recall)} | "
            f"{_fmt_ratio(precision)} | {_fmt_ratio(iou_share)} |"
        )
    lines.append("")

    lines.append("## Total-label probe")
    lines.append("")
    lines.append("| doc_id | candidate | occurrences | bound confirmed total | outcome |")
    lines.append("| --- | --- | --- | --- | --- |")
    for doc_id in doc_ids:
        for candidate in CANDIDATES:
            result = probe_results.get(doc_id, {}).get(candidate)
            if result is None:
                continue
            lines.append(
                f"| {doc_id} | {candidate} | {result.occurrences} | "
                f"{result.bound_confirmed} | {result.outcome} |"
            )
    lines.append("")
    if totals_missing:
        lines.append(f"Documents with totals missing: {len(totals_missing)}.")
        lines.append("")

    lines.append("## Read-only check (sha256 == sha256_after)")
    lines.append("")
    lines.append("| doc_id | candidate | unchanged |")
    lines.append("| --- | --- | --- |")
    read_only_summary: dict[str, dict[str, bool]] = defaultdict(dict)
    for doc_id in doc_ids:
        for candidate in CANDIDATES:
            if candidate not in read_only_ok.get(doc_id, {}):
                continue
            ok = read_only_ok[doc_id][candidate]
            read_only_summary[candidate][doc_id] = ok
            lines.append(f"| {doc_id} | {candidate} | {'yes' if ok else 'no'} |")
    lines.append("")

    lines.append("## Timing (ms per page)")
    lines.append("")
    lines.append("| candidate | median | max | pages measured |")
    lines.append("| --- | --- | --- | --- |")
    timing: dict[str, dict] = {}
    for candidate in CANDIDATES:
        values = ms_pooled[candidate]
        median = statistics.median(values) if values else None
        maximum = max(values) if values else None
        timing[candidate] = {"median_ms": median, "max_ms": maximum, "pages": len(values)}
        lines.append(f"| {candidate} | {_fmt_ms(median)} | {_fmt_ms(maximum)} | {len(values)} |")
    lines.append("")

    report_text = "\n".join(lines) + "\n"

    data = {
        "date": report_date.isoformat(),
        "documents": len(doc_ids),
        "missing_candidate_files": len(missing_files),
        "tool_versions": {c: sorted(tool_versions[c]) for c in CANDIDATES},
        "overall": overall,
        "probe": {
            doc_id: {
                candidate: {
                    "outcome": result.outcome,
                    "occurrences": result.occurrences,
                    "bound_confirmed": result.bound_confirmed,
                }
                for candidate, result in by_candidate.items()
            }
            for doc_id, by_candidate in probe_results.items()
        },
        "totals_missing": len(totals_missing),
        "read_only_ok": {
            candidate: dict(read_only_summary[candidate]) for candidate in CANDIDATES
        },
        "timing": timing,
    }
    return report_text, data


# --------------------------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------------------------


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dir", required=True, help="folder holding the extraction JSONs")
    parser.add_argument("--totals", required=True, help="path to the totals CSV")
    parser.add_argument("--out", required=True, help="path to write the Markdown report")
    parser.add_argument("--json", default=None, help="optional path to write the same numbers as JSON")
    args = parser.parse_args(argv)

    report_text, data = build_report(Path(args.dir), Path(args.totals))
    Path(args.out).write_text(report_text, encoding="utf-8")
    if args.json:
        Path(args.json).write_text(json.dumps(data, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
