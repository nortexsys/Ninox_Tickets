# Change: fix-photo-ocr-amount-parsing

## Why

The stage trace (status 2026-10-17, "Why photographs lose the total") over the 19 private photographs
shows that the photograph route loses `gross_total` mostly because **the value is not parsed as an
amount** (4 documents) and **no arithmetic identity is found** (3), and loses `doc_date` because **the
value is not parsed as a date** (12 of 19). The OCR words and amounts are there; the single-pass reading
fails too, so it is the parsing and binding of OCR-shaped tokens, not consensus. The photographs cannot
be shown to a lane (AGENTS.md §1.2, §6): the fix is built from **synthetic OCR-shaped cases**.

## What Changes

Implementation-only (`skip_specs: true`), Core lane, under `packages/paperdrop_core/`: make amount and
date parsing (and the label-to-value binding that feeds them) tolerate the forms ML Kit produces on a
receipt photograph, inside the existing requirements (FR-EXT-006…010, FR-VAL-*, FR-CTR-005), and make
the stage trace cover every path.

## Out of scope

* Weakening any never-green, arithmetic-gate or suppression rule: tolerant *reading*, same *trust*.
* Reading `supplier_name` without a label (needs a PO decision), country detection, the app, the specs.
