# Proposal: implement-photo-route

Plan v0.2 §8.3 change 9; task **T1.16** (M1, Mobile lane). Requirements served: `FR-EXT-006`
(consensus input), `FR-EXT-015` (photo-route recognition quality, measured later by T2.5). Written by
the orchestrator on 2026-10-12.

## Why

The photo route has no recognition yet. `close-adr-011-pdf-text-route` gave the invoice route its
port (`PdfTextSource`) and Core's `TextPage` / `PositionedWord`; the scanner (T1.13) produces a PDF
of images. Between the two there is nothing that turns a scanned page into positioned words, so
Core's layout reasoning (T1.5) and consensus (`consensus-by-majority`) have no photo-route input.
ADR-010 is *proposed*: the approach (platform engine behind a port) is decided, the engine is
confirmed by the T2.5 screening on the photographed corpus.

## What changes

* A port `OcrTextSource` in `app/lib/adapters/ocr/`, the photo-route twin of `PdfTextSource`: it
  returns pages of Core's `TextPage` in integer thousandths of a point, top-left origin — the same
  input, so a later engine swap changes one file and not the rule that binds a label to a value.
* The ML Kit Latin text-recognition implementation of that port.
* A **multi-pass strategy**: the same page is recognised several times under controlled variations,
  and each pass is returned separately as an `OcrPass` (`passId`, pages). Passes are never merged,
  averaged or maximised here: choosing a value across passes is Core's consensus (T1.5/T2.1).
* Rendering of a scanned PDF's pages to images for recognition, read-only (ADR-015).

## Out of scope (stated so it is not renegotiated)

* Choosing a field value across passes: Core's `consensus`. Wiring route selection and the
  fall-through from `PdfTextSource`: T2.1.
* The ADR-010 decision and any accuracy threshold: T2.5 and GAP-003. The numbers are reported; the
  PO decides. No threshold is invented here.
* iOS (R2). Handwriting. Any non-Latin script.
* Pre-processing of the image beyond what the passes in design §3 list: the prototype's
  pre-processing stage is not ported (see `DocumentScanner`).

## Impact

`app/` only (Mobile lane): `app/lib/adapters/ocr/`, `app/pubspec.yaml` (one dependency), tests,
and one row in the README dependency table (orchestrator). New Android dependency → NFR-SIZ-001
size delta and NFR-LIC-001 licence are measured and reported.
