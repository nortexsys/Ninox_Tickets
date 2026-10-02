# Tasks: close-adr-011-pdf-text-route

Plan v0.2 M1, T1.15; decision **Tue 6 Oct 2026**. A task is done when its check passes, not when its
files exist. Flutter checks run from `app/` on Flutter 3.47.5: `flutter analyze --fatal-infos`,
`dart format --set-exit-if-changed .`, `flutter test`; from the repository root:
`python .github/scripts/privacy_check.py`. No file of the private corpus is ever read, copied or
committed by a lane.

## 1. Mobile — first dispatch: the evaluation harness (design §1–§2)

- [ ] 1.1 **Candidate A — PdfBox-Android** behind a platform channel (`app/android/`, Kotlin) that
      returns, per page, the library's words with boxes in points, top-left origin. *Done when*
      `flutter build apk --debug` is green and a unit test of the Dart side parses a channel reply.
- [ ] 1.2 **Candidate B — `pdfrx`**: the same output from the plugin's page text API. *Done when* the
      debug build is green with both candidates present.
- [ ] 1.3 **Harness** `app/integration_test/pdf_text_eval_test.dart`: reads `PDF_EVAL_DIR`, skips
      without it, writes one JSON per document and candidate in the schema of design §2, with
      SHA-256 before and after and ms per page. *Done when* the JSON writer has a unit test and
      `flutter test` stays green without a device.
- [ ] 1.4 **Synthetic regression PDF** and its generator (design §5), committed under
      `app/test/fixtures/pdf/`; no real document's content in it. *Done when* both candidates read it
      in a host-side or channel-mocked test where possible, and the lane report says which assertion
      could only run on a device.
- [ ] 1.5 **Size**: release arm64 APK sizes for baseline, A only, B only (design §1.3), and each
      resolved artefact's licence (for `pdfrx`, the PDFium binary's). *Done when* the numbers and
      licences are in the lane report.

## 2. QA — the comparison script (design §2)

- [ ] 2.1 `validation/adr011_compare.py` with tests in `validation/tests/` on synthetic JSONs: recall,
      precision, IoU ≥ 0.5 share per page, and the total-label probe per invoice against a totals file
      passed by path. *Done when* the tests pass and the report it writes holds numbers only
      (`python .github/scripts/privacy_check.py` green on a sample report).

## 3. Orchestrator and product owner — run and decision

- [ ] 3.1 Product owner confirms the six expected totals (private ground truth), by Mon 5 Oct.
- [ ] 3.2 Device run on the Galaxy S22; 16 JSONs pulled to the private corpus; review written to
      `validation/reviews/adr-011-2026-10-05.md`.
- [ ] 3.3 **Decision by the product owner, Tue 6 Oct**; ADR-011's status written by the PO.

## 4. Mobile — second dispatch: the adapter (design §3, §5)

- [ ] 4.1 `PdfTextSource` over `paperdrop_core`'s `TextPage` / `PositionedWord`; the winner implements
      it; the loser and its dependency removed. *Done when* tests green and read-only verified against
      the intake hash.
- [ ] 4.2 Root README dependency row (orchestrator) and the runner-up recorded as evaluated and
      excluded.
- [ ] 4.3 Merge with `--no-ff` after the product owner's approval; GAP-002 closed by Spec afterwards.
