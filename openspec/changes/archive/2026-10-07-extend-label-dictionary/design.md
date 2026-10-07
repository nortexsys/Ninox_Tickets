# Design: extend-label-dictionary

Owner: Core lane. Written by the orchestrator on 2026-10-07.

* `packages/paperdrop_core/lib/` stays pure Dart, no `double` (the no-float scan is not edited), no new
  dependency. Tests are tagged `[capability/requirement-name] scenario title`; fixtures are invented.
* **The Annex C test is not touched.** `test/dictionaries/labels_test.dart` pins `labelTerms` to Annex C
  term by term and must still pass unedited. The extension therefore lives in **its own list**, for
  example `labelTermsExtension` in `lib/src/dictionaries/labels.dart` or a new file beside it, with a doc
  comment citing DEC-014, and the lookup (`findTerms`) consults `labelTerms` followed by the extension.
* **Extension terms:** `IMPORTE LIQUIDO` (kind total, language `es`) and `Belegdatum` (kind date,
  language `de`). Normalisation (case, diacritics) is the lookup's, so `IMPORTE LÍQUIDO` must match too;
  prove it with a test.
* **`columnNameTerms`**, a new exported list of the same shape, used by no extraction code: `Betrag`
  (total, `de`), `Supplier` (supplier, `en`), `Tax` (tax, `en`), and the two extension terms. A test
  proves `findTerms` over extraction input **does not** return `Betrag`, `Supplier` or `Tax` (so
  *Tax Invoice* binds nothing), and another proves `columnNameTerms` holds every extension term.
* Nothing is added for `supplier_tax_id` or `currency`.
* Conflict check: no extension term may collide with a negative-context term; a test enumerates both
  lists and fails on a collision.
