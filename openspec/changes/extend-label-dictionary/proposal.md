# Change: extend-label-dictionary

## Why

The ADR-011 evaluation and the setup wizard's matcher exposed coverage gaps in real terms: `IMPORTE
LIQUIDO` is the total label of an invoice in the private corpus and is absent from Annex C, so the
total-label probe found no label there; and `Belegdatum`, `Betrag`, `Supplier` and `Tax` are ordinary
column names that the `setup-wizard` scenario *a German table receives its proposals* expects to be
recognised, which the dictionary could not do (the Ninox lane met it with compound-matching rules in the
score and reported the gap). The product owner decided on 2026-10-07 to add terms; **DEC-014** records
it, because it extends Annex C, which the functional keeps read-only.

## What Changes

An **implementation-only change** (`skip_specs: true`). No requirement is added, modified, removed or
renamed. All code goes in `packages/paperdrop_core/`.

* **Extraction labels, a separate extension list.** `IMPORTE LIQUIDO` (total, `es`) and `Belegdatum`
  (date, `de`), in a new list beside `labelTerms` and consulted by the same lookup. The Annex C seeds
  and the test that pins them to Annex C term by term are **not edited**.
* **Column names for the wizard, a new list that extraction never reads.** `columnNameTerms`: `Betrag`
  (total), `Supplier` (supplier), `Tax` (tax), plus the two terms above. `Betrag` and `Tax` stay out of
  extraction on purpose (DEC-014): `Betrag` labels every amount line and `Tax` opens labels such as
  *Tax Invoice*.
* **No term for `supplier_tax_id` or `currency`**: no `LabelKind` exists for them and creating one
  would change the model.

## Requirements implemented

* **FR-EXT-014** — `extraction-pipeline` · `multilingual-label-dictionaries`: the extension of the
  content the application half consults. **FR-WIZ-006** — `setup-wizard` ·
  `two-stage-matching-with-a-strict-threshold`: the synonym source for the German-table scenario.

## Impact

`packages/paperdrop_core/lib/src/dictionaries/` and its tests. The wizard's matcher consuming
`columnNameTerms` is a **separate, later Ninox dispatch** (it needs this merged first). No living spec
changes, no functional change; DEC-014 is the recorded decision. `openspec validate extend-label-dictionary
--strict` passes with zero deltas.
