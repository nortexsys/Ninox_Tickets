# Tasks: implement-extraction-orchestration

Plan v0.2 M2, T2.1. A task is done when its check passes. Core checks run from `packages/paperdrop_core/`
(`dart analyze --fatal-infos`, `dart format --set-exit-if-changed .`, `dart test`); app checks from
`app/`; from the root `python .github/scripts/privacy_check.py` and `core_purity.py`.

## 1. Core — dispatch A (design §2)

- [x] 1.1 Report, before coding: with one pass, does `finalize` ever return green? Put the answer
      (rule and test that shows it) at the top of the lane report. *Done when* it is stated.
- [x] 1.2 `ExtractionPass` and `extractDocument` over `bindLabel`, `solveAmounts`, `resolve`,
      `finalize`. *Done when* tests on synthetic pages pass for: one pass, four agreeing passes, three
      agreeing plus one outlier, a pass that reads nothing.
- [x] 1.3 Multi-page: total on page 2, date on page 1 → one model; a field with different values on
      two pages of one pass → no reading from that pass. *Done when* both tests pass.
- [x] 1.4 Order of stages pinned by a test (consensus before derivation).
      *Done when* a document whose tax fails consensus is not used by the solver.
- [x] 1.5 `recognitionEngine` carries the route label. *Done when* asserted per route.

## 2. Mobile — dispatch B (after A is merged and T1.14 is on `main`)

- [x] 2.1 `ExtractionRouter` with the four routes of design §2, over the two ports, fakes in tests.
- [x] 2.2 Read-only proven by hash before/after; failures become `ExtractionFailure`.
- [x] 2.3 Wired to the store's document state machine.

## 3. Orchestrator and product owner

- [ ] 3.1 Bring open points 1–3 of design §3 to the PO.
- [ ] 3.2 Device run (dispatch C).
- [ ] 3.3 Merge with `--no-ff` after the PO's approval.
