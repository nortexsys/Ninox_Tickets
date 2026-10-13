# Tasks: implement-country-detection

A task is done when its check passes. Core checks from `packages/paperdrop_core/` (`dart analyze
--fatal-infos`, `dart format --set-exit-if-changed .`, `dart test`); app checks from `app/`; from the
root `python .github/scripts/privacy_check.py` and `core_purity.py`.

## 1. Core — dispatch A (design §2–§5)

- [ ] 1.1 `CountryDetection`, `Detected`, `Undetected`, `CountryEvidenceKind`, `UndetectedReason`.
      *Done when* the types are exported and carry no document text.
- [ ] 1.2 `detectCountry` with rules 1–4 of design §3 over `classifyTaxId`, a closed country-name
      list per row, dictionary language, currency exclusion. *Done when* the cases of design §5 pass.
- [ ] 1.3 Order independence and pass agreement: shuffled words give the same answer; passes that
      disagree give `conflictingEvidence`. *Done when* both tests pass.
- [ ] 1.4 *(after the PO answers design §4)* `extractDocument` with a nullable country: the
      universal core only, row-dependent values `unverified`, `needsReview`. *Done when* a
      no-row document extracts amounts and dates and never applies a rate gate.
- [ ] 1.5 The circularity case: date and amount formats do not change the detection.

## 2. Mobile — dispatch B (after A is merged)

- [ ] 2.1 `ExtractionService` takes the detection instead of a fixed `country`; the reason of an
      `Undetected` goes into the stored engine metadata, not into a failure.
- [ ] 2.2 Tests with fakes for Detected and each Undetected reason.

## 3. Orchestrator and product owner

- [ ] 3.1 PO answers design §4 (an undetected document: universal core + review, or fail).
- [ ] 3.2 Merge with `--no-ff` after the PO's approval.
