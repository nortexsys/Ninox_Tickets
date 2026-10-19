# Change: fix-photo-total-without-identity

## Why

The first attempt, `fix-photo-ocr-amount-parsing` (branch kept, **not merged**), was built from synthetic
OCR-shaped cases and **did not move the real photographs**: on the 19 private photographs (four passes,
host) it read a total in 0 (main: 1 — it even lost the one total that is confirmed by an identity) and
changed no date. Its premise (token formats) was wrong. The measurements that point elsewhere, counts only:

* Dates, universal core vs Spain forced (same words): 4 vs 10 of 19 (four passes). The date order is not
  inferred when no country row applies (16 of 19 photographs have no country).
* `gross_total` with Spain forced and four passes is still absent in 16 of 19. Stages recorded by the
  trace: **no arithmetic identity 8**, passes disagree 5, value not parsed 4, no majority 1, negative
  context 1, label found but no value 1, no label 2.
* Masked line shapes of the photographs show clean lines (`total 99,99`, `TOTAL: 999,99 EUR`,
  `base 999,99 iva 99,99% 99,99`, dates `99/99/9999`): the tokens are fine. Many receipts print a total
  with **no breakdown**.

## What Changes

Implementation-only (`skip_specs: true`), Core lane, `packages/paperdrop_core/`. Read the specs first
(`extraction-pipeline`, `validation-confidence`, Funcional Annex D, `countries-languages`
`universal-core`) and decide nothing they do not decide:

1. **A printed total with no breakdown.** The spec cases (card-slip printing only a total; absent-not-zero;
   amber for an un-cross-checked reading) say what the field is when no identity exists. If the solver
   drops a labelled total because no identity was found, that is the bug: read it, amber, single reading.
2. **Passes that disagree on the total** (5 of 19): majority across the four passes (BR-06); look at why
   the pages disagree (a near-miss in one pass must not veto the others).
3. **Date order in the universal core**: infer it from the document's own dates when unambiguous (a day
   greater than 12); never guess when ambiguous (report it as an open question for the PO).
4. **No regression:** a receipt that main reads with an identity (net + tax = total, several rates) must
   still be read and confirmed; add a synthetic control for it.

## Out of scope

* Weakening never-green, the arithmetic gate, repair or suppression rules. `supplier_name`, country
  detection, the app, the specs (a spec gap is reported, not edited).
