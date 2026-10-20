# Design: fix-ci-pdfium-runner

## 1. Question

How does pdfrx find PDFium under `flutter test`, and what does a GitHub `ubuntu-latest` runner need so that
it finds it? The two paths in the error are the answer's two candidates:

1. the default module `<flutter>/bin/cache/artifacts/engine/linux-x64/lib/libpdfium.so`, part of the Flutter
   SDK cache for the host platform (a Flutter SDK artifact that may only be fetched by a precache step);
2. the bundled native asset, produced by pdfrx's build hook, which "Native assets file not found" says did
   not run or was not found under `flutter test`.

## 2. Method (read, then change)

* Read the pdfrx version pinned in `pubspec.lock` in the pub cache (`~/.pub-cache` or
  `%LOCALAPPDATA%\Pub\Cache`), its README on tests and on loading PDFium, and the Flutter 3.47.5 behaviour of
  `flutter test` with native assets / build hooks. Quote what you read in the report with file and line.
* Prefer, in this order, the smallest change that makes the module present:
  (a) a CI step before the test step, such as `flutter precache --linux` (or the specific flag the SDK
  documents for the PDFium artifact), if the artifact is a Flutter SDK download;
  (b) enabling what the build hook needs under `flutter test`, if that is the missing piece;
  (c) installing PDFium on the runner and pointing pdfrx at it through the setting pdfrx documents.
* The change is in `.github/workflows/ci.yml` only, unless the pdfrx documentation requires a test-side
  initialisation call. In that case it goes in the test file's `setUpAll` and nowhere else.

## 3. Limits of what this lane can prove

The lane runs on Windows and cannot reproduce the Linux runner. It therefore proves: the YAML is valid, the
four tests and the whole `app` suite still pass on Windows, and every claim about pdfrx and Flutter is
quoted from a source it read. It does **not** claim the runner is fixed. The orchestrator verifies that on
GitHub (a CI run) after the PO approves a push; the report lists which of (a), (b), (c) it chose and the
fallback if that one fails.

## 4. Non-goals

No test is skipped, tagged or deleted. No change to `app/lib`, `packages/`, `pubspec.yaml`, `pubspec.lock`
or any dependency version. No secrets. No change to the other CI jobs.
