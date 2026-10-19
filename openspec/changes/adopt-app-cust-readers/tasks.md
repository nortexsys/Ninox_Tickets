# Tasks: adopt-app-cust-readers

## 1. Spec lane
- [ ] 1.1 DEC entry (country is an input; detection no longer decides the photo route) and the delta
      specs it forces (`extraction-pipeline`, `country-detection` if it exists, `review-screen`, settings).
- [ ] 1.2 Close or amend the gaps this touches in `gaps-register.md` (GAP-034).

## 2. Core lane
- [ ] 2.1 Port `receipt.dart`, `receipt_arithmetic.dart` and the row rebuilding; port the synthetic tests.
- [ ] 2.2 Parametrise by `CountryRow`; Spain-equivalence test against the prototype's expectations.
- [ ] 2.3 Wire into `extractDocument` for photo passes; keep trace stages.

## 3. Mobile lane
- [ ] 3.1 Country in settings (initial from phone region) and on the review screen; service takes it.
- [ ] 3.2 "Re-read" action for the second read.

## 4. Orchestrator and PO
- [ ] 4.1 Review; re-measure 19 photographs on the host; PO approves; merge `--no-ff`; S22 run.
