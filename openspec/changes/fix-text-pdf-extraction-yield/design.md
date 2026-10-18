# Design: fix-text-pdf-extraction-yield

## 1. Evidence

`evidence/synthetic_invoice_0{1,2}.words.json`: the words `pdfrx` reads from the two synthetic invoices
(`{"width","height","words":[[text,x0,x1,top,bottom], ...]}`, integer thousandths of a point, page
top-left origin, exactly `PositionedWord`'s fields). Both documents are fictitious ("DOCUMENTO FICTICIO",
`.test` addresses). They contain U+FFFD characters where `pdfrx` could not decode an accented letter or a
dash (`Nº`, `emisión`, `€`): that is part of the evidence, not noise to clean — decide whether the label
matching or the currency/number tokenising should tolerate it, and say so in the report.

## 2. Method

1. Copy the evidence into `packages/paperdrop_core/test/regressions/fixtures/` and build `TextPage`s from it.
2. Run `extractDocument` (country ES from the launch table, one `text` pass labelled `pdf-text/pdfrx 2.6.5`)
   and write down, per absent field, **which stage dropped it** (label binding, number parsing, amount
   solver, gate, suppression, confidence cap). One failing test per cause, named for the cause.
3. Fix each cause at its stage. Expected for invoice 01 (Annex D, tip case): `gross_total` 121,00 EUR from
   TOTAL FACTURA confirmed by 100,00 + 21,00; the tip 15,00 captured as a surcharge, not added to the base;
   TOTAL A PAGAR not taken as `gross_total` unless Annex D says so (read it first). Invoice 02: derive the
   expected values from its own arithmetic, state them in the test, and flag any you cannot justify.
4. Never-green stays: a text-layer reading is deterministic (DEC-018) but a derived value never confirms
   anything; keep every existing test green.

## 3. Checks

`dart format`, `dart analyze --fatal-infos`, `dart test` in `packages/paperdrop_core` (run per package),
`python .github/scripts/privacy_check.py` and `core_purity.py` 0 findings. No Ninox call, no device.
