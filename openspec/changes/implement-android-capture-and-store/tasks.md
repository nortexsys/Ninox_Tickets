# Tasks: implement-android-capture-and-store

Plan v0.2 M1, Mobile lane. A task is done when its check passes, not when its files exist. Every
check is run from the repository root on Flutter 3.47.5 / Dart 3.13.4:
`flutter analyze --fatal-infos app` (from `app/`: `flutter analyze --fatal-infos`),
`dart format --set-exit-if-changed app`, `flutter test` (from `app/`),
`python .github/scripts/privacy_check.py`.

## 1. Mobile — first dispatch: shell and capture (T1.12–T1.13)

- [ ] 1.1 **Localisation and shell** (design §2): `flutter gen-l10n` with `app_en.arb`, router with
      `/capture` and `/intake/:docId`, theme. *Done when* the app starts on the capture screen in a
      widget test, and every string on it comes from `AppLocalizations`.
- [ ] 1.2 **Accessibility baseline and string scan** (design §2). *Done when* the guideline test
      passes on the capture screen and the hardcoded-string scan passes on `app/lib/` (and fails on a
      planted literal, proved inside the test without touching `app/lib/`).
- [ ] 1.3 **`DocumentIntake`** (design §3): byte-stream copy, double SHA-256, content-free `docId`
      and path, media-type check, no partial file on error. *Done when* the tests of design §3 pass.
- [ ] 1.4 **Picker and share-in** (design §3): interfaces, implementations, manifest `ACTION_SEND` and
      `ACTION_SEND_MULTIPLE` for PDF and images, both feeding `DocumentIntake`. *Done when* fake-backed
      tests prove both land on `/intake/:docId` with the same `IntakeResult` shape, several shared
      files are refused with an externalised message and nothing stored, and
      `flutter build apk --debug` succeeds.
- [ ] 1.5 **Scanner** (design §3): `DocumentScanner` + ML Kit implementation in PDF mode, feeding
      `DocumentIntake` with the scanner's PDF unchanged; the no-image-processing scan test. *Done
      when* the fake-backed test passes and `flutter build apk --debug` succeeds.
- [ ] 1.6 **Dependencies declared**: each new package with version and licence in the lane report and
      in the README's dependency declaration. *Done when* none is AGPL/GPL.

## 2. Mobile — second dispatch: local store and state machine (T1.14)

Detailed in design §5 before dispatch. Runs after `close-adr-011-pdf-text-route` (design §6).

- [ ] 2.1 T1.14 — local store and document state machine (FR-HIS-001, FR-HIS-002).

## 3. Orchestrator and product owner

- [ ] 3.1 Review the lane's report, diff and dependencies; run the checks at the top of this file.
- [ ] 3.2 Device check of design §4 with the product owner.
- [ ] 3.3 Merge `change/implement-android-capture-and-store` with `--no-ff` after the product owner
      approves.
