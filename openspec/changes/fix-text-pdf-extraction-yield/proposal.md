# Change: fix-text-pdf-extraction-yield

## Why

The first end-to-end run of `ExtractionService` on the Galaxy S22 (status 2026-10-17, section
"Extraction end to end", 2026-10-18) read 8 PDFs that have a text layer and found **`gross_total` in
none of them**, `supplier_name` in 2 and `doc_number` in none, **including the PO's two synthetic
invoices**, whose text is clean and whose Annex-D-style arithmetic is correct (invoice 01: Base 100,00 +
IVA 21% 21,00 = TOTAL FACTURA 121,00, plus a voluntary tip of 15,00 outside the base, TOTAL A PAGAR
136,00). The host reproduces it exactly (same words, same absent fields), so the cause is in Core's
extraction of a *text-layer* reading and not in the device, the harness or the document. Alpha (T2.6)
cannot ship a pipeline that finds no total on a clean invoice.

## What Changes

Implementation-only (`skip_specs: true`), Core lane, under `packages/paperdrop_core/`. Find, with a
failing regression test per cause, why the text-layer reading of these two documents yields no
`gross_total`, `supplier_name` or `doc_number`, and fix the cause inside the **existing** requirements
(FR-EXT-004, FR-EXT-006…010, FR-EXT-014; label dictionaries EN/DE/ES; Annex D).

## Out of scope

* Weakening any never-green rule, the arithmetic gate, or the negative-context suppression: the fix
  makes the solver *read* the amounts, it does not make it trust them more.
* Accuracy on the photographed corpus (T2.5), the app, the adapters, the specs and `docs/`.
* Anything the specs do not already decide: it is reported to the orchestrator, not decided by the lane.
