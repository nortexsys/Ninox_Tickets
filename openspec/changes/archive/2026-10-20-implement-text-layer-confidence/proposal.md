# Change: implement-text-layer-confidence

## Why

DEC-018, archived 2026-10-17 as `amend-text-layer-reading`, lets a PDF text-layer reading stand alone
and reach green when its operands were all read from the layer, none was derived, and at least one
arithmetic identity over them is checkable and holds. Core still caps every single-pass value at
amber (`extract_document.dart` `_finalizeConfidence`, `consensus.dart` `Single`).

## What Changes

An **implementation-only change** (`skip_specs: true`). Owner: Core lane, under
`packages/paperdrop_core/`. Tests in `packages/paperdrop_core/test/`.

* `extractDocument` learns whether a pass set is a **text-layer reading**: every pass has route label
  `pdf-text` (pages with a text layer; `pdf-mixed` pages without a layer are OCR and do not qualify).
* For a text-layer reading, `Single` is not capped when its confidence derives from a **holding,
  checkable identity** over operands all `Provenance.read`; otherwise the cap stays.
* OCR routes (`photo-ocr`, `pdf-ocr`, `pdf-mixed`) are unchanged.

## Out of scope

* App code, the review screen, the document-level `needsReview` rule (confirmed 2026-10-17: true when
  any present primary field is not green or none is present; absent optional fields do not count; only
  its inputs change here).
* Any change to the checks (`redundancy.dart`) or to derivation.
