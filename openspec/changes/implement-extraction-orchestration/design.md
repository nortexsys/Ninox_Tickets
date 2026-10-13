# Design: implement-extraction-orchestration

Plan v0.2 M2, **T2.1** (orchestrator-owned): route selection and multi-page consolidation wired end to
end. Requirements: `FR-EXT-001` (pipeline order), `FR-EXT-002` (route priority), `FR-EXT-012`
(multi-page consolidation), `FR-EXT-006` (consensus across passes). Written by the orchestrator,
2026-10-13. No Ninox write, no private corpus.

## 1. What exists, what does not

| Piece | State |
| --- | --- |
| `PdfTextSource` (pdfrx) → `List<TextPage>` | Done (T1.15), on `main` |
| `OcrTextSource` (ML Kit) → `List<OcrPass>`, four passes, never merged | Done (T1.16), on `main` |
| Core: `bindLabel`, `solveAmounts(pages: Iterable<TextPage>)`, `resolve` over `Reading`s, `finalize` | Done (T1.5–T1.7) |
| `CanonicalDocument.recognitionEngine` (String) | Exists: the place the route is recorded |
| **Nothing connects them.** No function turns pages (or passes) into a `CanonicalDocument`; nothing chooses the route | This change |

`solveAmounts` already takes pages as an `Iterable`, so a total that continues on page 2 is solved
over all pages at once. Multi-page consolidation for amounts therefore needs no new rule; what is
new is that *other* fields (date, number, supplier) are read from every page and one value per field
survives, with the contributing page kept internally (`multi-page-consolidation` scenario).

## 2. Split by layer (plan §7.2: no rule that decides a value lives in `app/`)

**Core (pure Dart, no Flutter, no I/O)** — `extractDocument`:

```dart
CanonicalDocument extractDocument({
  required List<ExtractionPass> passes,   // passId + pages (+ route label)
  required CountryRow country,
  required CountryTable table,
  required String sourceHash,
});
```

1. For each pass: read every field from all its pages (`bindLabel` per field kind; `solveAmounts`
   over all pages of the pass). A field found on several pages of one pass is a conflict inside that
   pass: the first by page order wins **only if no other page holds a different value**; a
   disagreement yields no reading from that pass for that field (never a guess).
2. Across passes: `Reading`s per field → `resolve` (majority; `Single` for one reader). Amounts
   follow `read-all-printed-quantities-before-deriving`: operands pass consensus **before** the
   solver derives anything (`pipeline-order-is-fixed`).
3. `finalize` → confidence; `needsReview` as the confidence rules set it.
4. `recognitionEngine` is set from the route label of the passes (§3).

A single pass (the text-layer route) is legal: its values are `Single`, which confidence caps below
green exactly as `consensus.dart` already documents. **This is a product consequence, not a
detail**: a text-layer invoice would never be green. Task 1.1 asks Core to report whether the rule
as built does this; the orchestrator brings the answer to the PO rather than choosing.

**App** — `ExtractionRouter` (`app/lib/features/extraction/` or `adapters/`): takes the intake
document and returns passes.

| Input | Route | Passes |
| --- | --- | --- |
| PDF, every page has a text layer | `pdf-text` | one pass `text`, from `PdfTextSource` |
| PDF, no page has a text layer | `pdf-ocr` | the four OCR passes |
| PDF, some pages with and some without | `pdf-mixed` | per page: text layer where it exists, OCR pages otherwise; OCR pages contribute their four passes, text pages repeat their one pass in each so page counts agree. **Open point 2** |
| Image / photo | `photo-ocr` | the four OCR passes |

The XML step of `invoice-route-priority` (step 1) is R1; a ZUGFeRD PDF has a text layer and goes
through `pdf-text`, as plan §4 row `FR-EXT-002` says. The route string is stored in
`recognitionEngine` as `<route>/<engine+version>`.

Reading is read-only everywhere (ADR-015): the router hashes the source before and after in a test.
Failure: `PdfTextReadFailure` and `OcrFailure` are caught by the router and become one
`ExtractionFailure` the capture feature turns into text (T2.2/T2.3 own the wording).

## 3. Open points (not decided here)

1. Whether a text-layer-only invoice can ever be green (see §2). Needs the PO.
2. The mixed-PDF rule above is a proposal; the corpus has no such document yet.
3. `needsReview` on pages the router could not read at all.

## 4. Dispatches

| Step | Lane | Needs |
| --- | --- | --- |
| A. `extractDocument`, tests on synthetic pages (Annex D cases that already exist as fixtures) | Core | Nothing else; can start now |
| B. `ExtractionRouter` and wiring to the store | Mobile | A merged, and **T1.14 on `main`** (it is not yet: it lives on the housekeeping branch) |
| C. Device run on the S22: synthetic PDF with text, synthetic scan, one photo | Orchestrator + PO | B, phone linked |

## 5. Not in this change

Review screen (T2.2), history/retry/duplicates (T2.3), the ADR-010 screening (T2.5), XML (R1), any
accuracy threshold (GAP-003).
