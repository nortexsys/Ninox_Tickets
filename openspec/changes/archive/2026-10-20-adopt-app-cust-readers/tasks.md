# Tasks: adopt-app-cust-readers

## 1. Spec lane
- [x] 1.1 DEC entry (country is an input; detection no longer decides the photo route) and the delta
      specs it forces (`extraction-pipeline`, `country-detection` if it exists, `review-screen`, settings). (done: c33b0ee)
- [x] 1.2 Close or amend the gaps this touches in `gaps-register.md` (GAP-034). (done: c33b0ee)

## 2. Core lane
- [x] 2.1 Port `receipt.dart`, `receipt_arithmetic.dart` and the row rebuilding; port the synthetic tests. (done: bd1b1c4)
- [x] 2.2 Parametrise by `CountryRow`; Spain-equivalence test against the prototype's expectations. (done: bd1b1c4)
- [x] 2.3 Wire into `extractDocument` for photo passes; keep trace stages. (done: bd1b1c4)

## 3. Mobile lane
- [x] 3.1 Country in settings (initial from phone region) and on the review screen; service takes it. (done: 2f8f92e)
- [x] 3.2 "Re-read" action for the second read. (done: 2f8f92e)

## 4. Orchestrator and PO
- [x] 4.1 Review; re-measure 19 photographs on the host; PO approves; merge `--no-ff`; S22 run. (done: bd1b1c4, 2f8f92e, S22 run 2026-10-20 in docs/Plan/diario/2026-10-17.md)
