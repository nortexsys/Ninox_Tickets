# Design: fix-photo-ocr-amount-parsing

## 1. Synthetic OCR-shaped cases (no real document)

Build from the committed synthetic invoices (`test/regressions/fixtures/`) and small hand-made pages. Each
case is a `TextPage` and a perturbation that mimics a recognition engine on a till receipt:

1. currency symbol glued to the number or detached (`12,50€`, `€12,50`, `12,50 €`, `EUR 12,50`);
2. decimals split by OCR into two tokens (`12 ,50`, `12, 50`, `12 . 50`) and thousands with a space;
3. separator confusion (`12.50` vs `12,50` on a document whose convention is the other one, `1,234.50`);
4. look-alike glyphs inside numbers (`O`/`0`, `l`/`1`, `S`/`5`, `B`/`8`) in amounts and dates;
5. dates with spaces or OCR dots/dashes (`28 / 09 / 2026`, `28.09.26`, `28-09-2026`, 2-digit years);
6. label and value on one line with the value far to the right; label split (`TO TAL`, `T0TAL`);
7. short ticket layout: `BASE`, `IVA 10%`, `TOTAL`, `ENTREGADO`, `CAMBIO` (change and tendered must
   be suppressed, not read as the total).

## 2. Method

Per case: first a failing test that names the stage (use `CollectingTrace`), then the smallest fix at that
stage. Repairs that change a character are `repaired` provenance and never green (repair never confirms,
FR-VAL repair rules); do not let a look-alike repair create a value that the arithmetic identity did not
independently support.

## 3. Trace coverage

Every canonical field that comes out `Absent` or capped must have at least one recorded stage. Add the
missing records (about a third of the absent `gross_total` cases had none) and a test that fails if a
field is absent with an empty trace on a set of synthetic pages.

## 4. Checks

`dart format`, `dart analyze --fatal-infos`, `dart test` in `packages/paperdrop_core` (all existing tests
unchanged: 287 today), `privacy_check.py`, `core_purity.py` 0 findings. After this change the orchestrator
re-runs the host measurement on the private photographs and reports counts only.
