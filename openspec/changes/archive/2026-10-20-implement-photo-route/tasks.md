# Tasks: implement-photo-route

Plan v0.2 M1, T1.16. A task is done when its check passes, not when its files exist. Checks run from
`app/` (Flutter 3.47.5): `flutter analyze --fatal-infos`, `dart format --set-exit-if-changed .`,
`flutter test`; from the repository root `python .github/scripts/privacy_check.py`. No file of the
private corpus is read, copied or committed by a lane. No write to Ninox.

## 1. Mobile — dispatch (design §1–§4)

- [x] 1.1 `OcrTextSource`, `OcrPass`, `OcrFailure` in `app/lib/adapters/ocr/`. *Done when* the types
      compile and are exercised by tests with a fake backend.
- [x] 1.2 ML Kit Latin implementation behind `TextRecognizerBackend`, pinned exactly in
      `app/pubspec.yaml`. *Done when* `flutter build apk --debug` is green.
- [x] 1.3 PDF page rendering via pdfrx, read-only, cache files always removed. *Done when* the
      hash-unchanged and cleanup tests pass.
- [x] 1.4 The four passes of design §3, ordered, injectable, failing pass dropped and recorded.
      *Done when* the order/id/drop tests pass.
- [x] 1.5 Pixel→milli-point conversion, tested with a known box. *Done when* exact integer
      expectations pass.
- [x] 1.6 Device harness `app/integration_test/ocr_eval_test.dart` (design §4) and the synthetic
      fixture with its generator. *Done when* it compiles and is skipped without `OCR_EVAL_DIR`.
- [x] 1.7 Size delta (bundled and unbundled, release arm64) and licence of the resolved artefact in
      the lane report.

## 2. Orchestrator and product owner

- [x] 2.1 Review the lane report and diff; README dependency row (orchestrator). (done: 052e2e0, 58c1097)
- [x] 2.2 Device run on the S22 over a synthetic scan, then over the photographed corpus (private);
      JSON pulled to the private corpus. (done: docs/Plan/diario/2026-10-17.md (S22 synthetic and 19 photographs))
- [x] 2.3 Merge with `--no-ff` after the PO's approval. ADR-010 stays *proposed* until T2.5. (done: 052e2e0, 58c1097)
