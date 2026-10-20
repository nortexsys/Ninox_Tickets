# Design: adopt-app-cust-readers

## 1. Source and landing

| App Cust | Product |
| --- | --- |
| `lib/ocr.dart` (geometry rows; imports ML Kit) | row rebuilding goes to Core (`layout/`) over `TextPage` words; the ML Kit import stays out of Core (core_purity) |
| `lib/receipt.dart` (pure Dart) | `packages/paperdrop_core/lib/src/photo/labelled_reader.dart` |
| `lib/receipt_arithmetic.dart` (pure Dart) | `.../photo/arithmetic_reader.dart` |
| `test/receipt_test.dart`, `ocr_test.dart` | ported as Core tests; every fixture checked for real data first |

Copy, then adapt only what the country parameters force. No refactor, no "improvement".

## 2. Country parameters

Replace constants by `CountryRow` fields: `decimalConvention` (parseAmount, kMoney), `dateOrder` and
`dateSeparator` (parseDate; keep the whitespace tolerance and the swap rule only when the order is
ambiguous under that country), `legalRates` (kLegalSpanishRates), `currency`. Label words come from the
existing dictionaries per country; Spain's list must contain every word the prototype uses.
Equivalence test: for Spain, the ported readers give the prototype's output on every ported test.

## 3. Country as input

`ExtractionService` receives the country from the caller (settings default, or the review-screen
value) and passes `CountryRow` to extraction; `detectCountryAcrossPasses` is no longer called for the
photo route. Settings gets a country field (initial from phone region); the review screen shows it.
Currency is read from the row and is no longer a stage that can fail.

## 4. Two reads

First read: both readers run, results combined as in the prototype (labelled first, arithmetic fills
gaps, derived values labelled derived and never green on their own: PRE-008/BR-05 stay).
Second read, on request: the other reader / the four passes consensus, as the prototype's toggle.
The trust rules of `validation-confidence` do not change.

## 5. Checks

`dart format`, `dart analyze --fatal-infos`, `dart test` (Core and app), `privacy_check.py`,
`core_purity.py`, `no_ninox_db_id`. Then the orchestrator re-measures the 19 photographs on the host
with country Spain (counts and per-photo read/not-read, no values) and compares with `main`
(gross 5 of 19; date about 9 of 19).
