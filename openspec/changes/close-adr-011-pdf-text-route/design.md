# Design: close-adr-011-pdf-text-route

Owner: Mobile lane (evaluation harness and adapter), QA (comparison script), product owner (decision).
Written by the orchestrator on 2026-09-30, completed on 2026-10-02. Decision date: **Tue 6 Oct**
(plan §9, T1.15).

## 1. What is decided, and by what

ADR-011 closes on three measurements over the PDF half of the private corpus (8 documents, 9 pages,
in the corpus's inbox), for two candidates fixed by the product owner on 2026-09-25
(GAP-002, D-5):

| Candidate | Binding | Licence |
| --- | --- | --- |
| **A — PdfBox-Android** (`com.tom-roush:pdfbox-android`) | a platform channel from `app/lib/adapters/pdf_text/` to Kotlin in `app/android/` | Apache-2.0 |
| **B — PDFium** through `pdfrx` | the Flutter plugin's own API (page text with character rectangles) | plugin BSD-3; PDFium BSD-3/Apache-2.0 |

1. **Positional fidelity** (the hard criterion of ADR-011): every word with its bounding box, in PDF
   points with a top-left origin, compared with the reference extraction already prepared by the
   orchestrator (`Paperdrop_corpus\out\<doc_id>.ref-pdfplumber-words.json`, pdfplumber). Measured:
   word recall and precision by text, and the share of matched words whose box overlaps the
   reference's with IoU ≥ 0.5. Reported per document and per page, never only as an average.
2. **Label–value association**, the failure ADR-011 exists for: on each invoice, the value nearest the
   total label in the visual layout (same line, to the right; else the line below) must be the total.
   Expected totals come from the product owner (six numbers, one per real invoice), not from either
   candidate. The rule is a deliberately simple probe, not T1.5's layout reasoning.
3. **Cost**: release APK size delta per ABI (`flutter build apk --release --split-per-abi`, arm64)
   against the build without the candidate (NFR-SIZ-001). The proposal says `--debug`; a debug APK
   carries the Dart VM and every ABI and hides the delta that ships, so the release arm64 split is the
   number reported, with the debug delta alongside for continuity. Extraction time per page on the
   Galaxy S22; licence confirmed from the artefact actually resolved (NFR-LIC-001) — for `pdfrx`, the
   licence of the PDFium binary it downloads at build time, read from that binary's distribution.

Also recorded, not decisive: behaviour on the two-page document, on a PDF with no text layer (none in
the corpus yet — the scanned PDF due Fri 9 Oct), on `pdf-invoice-03` (its text layer yields digits
only: a custom font encoding), and whether opening the file ever writes to it
(`received-files-are-attached-byte-for-byte` · *reading never writes*: SHA-256 before and after).
ADR-014's embedded-file extraction is probed on the synthetic ZUGFeRD-shaped PDF if one candidate
exposes it, and recorded as a property for R1.

## 2. Harness

An Android integration test (`app/integration_test/pdf_text_eval_test.dart`), run on the S22 by the
orchestrator, never in CI. The PDFs are pushed to the app's private storage with `adb`, never
committed; the test reads a directory given by `--dart-define=PDF_EVAL_DIR=...` and is skipped when it
is not given. For each PDF and each candidate it writes one JSON next to the input, pulled back to
`Paperdrop_corpus\out\<doc_id>.<candidate>-words.json`, in **the reference's schema** so the
comparison reads three files of one shape:

```json
{"doc_id": "...", "tool": "pdfbox-android 2.0.27.0 | pdfrx x.y.z", "sha256": "<of the input, before>",
 "sha256_after": "<of the input, after>", "ms_per_page": [..],
 "pages": [{"index": 0, "width": 595.8, "height": 842.4,
            "words": [{"text": "...", "x0": 0.0, "x1": 0.0, "top": 0.0, "bottom": 0.0}]}]}
```

Units are PDF points, origin top-left, as pdfplumber's. Each candidate's words are the library's own
segmentation — no merging or splitting by the harness, because what a *word* is per library is part
of what is compared.

The comparison script (`validation/adr011_compare.py`, QA) reads the three JSONs per document plus the
product owner's confirmed totals (a path given on the command line, in the private corpus) and writes
`validation/reviews/adr-011-<date>.md` with **numbers only**: per page word counts, recall,
precision, IoU ≥ 0.5 share; per invoice whether the probe bound the confirmed total (yes / no / no
label found), never the total itself or any text. Unit-tested on synthetic JSONs in
`validation/tests/`.

## 3. The port, and who owns its types

T1.15 and T1.5 run concurrently, and both need the same shape: a page of positioned words. Under
plan §7.2's shared-contract rule it belongs to `paperdrop_core`, because the core's layout reasoning
is its consumer and no rule that decides a value lives in `app/`.

* **Core publishes** `PositionedWord` (`text`, `x0`, `x1`, `top`, `bottom`, in points, top-left
  origin) and `TextPage` (`index`, `width`, `height`, `words`, and `hasTextLayer`) as the **first
  commit** of `implement-validation-and-extraction-core`, before any layout logic, exactly as T1.1–T1.2
  were published first. The field names are pdfplumber's so the reference, the harness and the model
  agree without a mapping.
* **The harness does not need them**: it writes JSON (§2). So the evaluation is not blocked by Core.
* **The adapter does**: after the decision, `app/lib/adapters/pdf_text/` defines
  `abstract interface class PdfTextSource { Future<List<TextPage>> read(String path); }` over Core's
  types, and the winner implements it. `hasTextLayer` is false on a page that yields no word, which is
  what T2.1's fall-through to OCR needs; the decision to fall through is T2.1's.

## 4. Sequence and dispatches

| Step | Who | When | Done when |
| --- | --- | --- | --- |
| Harness with both candidates; synthetic regression PDF | Mobile | Fri 2 – Sat 3 Oct | `flutter build apk --debug` green with both; unit tests green on the harness's JSON writer (no device) |
| Comparison script | QA | Fri 2 – Mon 5 Oct | unit tests green on synthetic JSONs |
| Size builds (three release arm64 APKs: baseline on `main`, with A only, with B only) | Mobile | with the harness | numbers in the lane report |
| Device run on the S22 | Orchestrator + PO | Mon 5 Oct, after the totals are confirmed | 16 JSONs pulled (8 docs × 2) |
| Report and recommendation | Orchestrator | Mon 5 Oct | `validation/reviews/adr-011-2026-10-05.md` |
| **Decision** | PO | **Tue 6 Oct** | ADR-011 status written by the PO |
| Adapter of the winner behind the port; loser removed; README row | Mobile (+ orchestrator for README) | Tue 6 – Wed 7 Oct | §5 |

## 5. Output of the change

The winning candidate becomes `app/lib/adapters/pdf_text/` behind `PdfTextSource`; the loser's code
and dependency are removed before merge, and its numbers stay in the review file. Extraction is
read-only (ADR-015), verified against the intake hash of `implement-android-capture-and-store`. The
synthetic regression — a label and its value on different lines, with a `Tomo n.nnn` registry
volume nearer the label in extraction order — is generated by a script committed beside it
(`app/test/fixtures/pdf/make_tomo_regression.py`, reportlab or hand-written PDF operators, whichever
the lane finds already available; no AGPL tool) and asserted at the adapter level: the words are
returned with positions that put the total, not the volume, on the label's line. The binding itself is
asserted again in Core once T1.5 lands. ADR-011 is moved to Accepted in the ADR by the product owner.
