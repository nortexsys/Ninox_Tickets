# paperdrop (app)

The Flutter application of Paperdrop for Ninox. Android only in the MVP.
See the root `README.md` for building and testing, and `AGENTS.md` for how to work in this
repository.

## Dependencies

Every dependency of the shipped application, with its licence (NFR-LIC-001, plan v0.2 §9 of the
`setup-mvp-foundations` change). No AGPL or GPL component ships in the app.

The same table belongs in the root `README.md`'s **Dependencies** section; it is repeated here —
with the exact versions this application resolves — for the rows the Mobile lane adds, because the
root file is outside the lane's write bounds.

| Dependency | Used for | Licence | Proprietary |
| --- | --- | --- | --- |
| `flutter` — the SDK's framework, engine and Android embedding | The application itself | BSD-3-Clause | No |
| `flutter_localizations` (from the Flutter SDK) | Material, widget and Cupertino localisations | BSD-3-Clause | No |
| `go_router` 16.3.0 | The shell's routes (design §2) | BSD-3-Clause | No |
| `intl` 0.20.3 | Plural and number formatting in the generated localisations | BSD-3-Clause | No |
| `crypto` 3.0.7 | SHA-256 over the input and over the stored copy (FR-CAP-005) | BSD-3-Clause | No |
| `path` 1.9.1 | Building `<documents>/originals/<docId>/original.<ext>` | BSD-3-Clause | No |
| `path_provider` 2.1.6 | The application's documents directory | BSD-3-Clause | No |
| `file_picker` 10.3.10 | The file-picker path of FR-CAP-001 | MIT | No |
| `flutter_secure_storage` 10.3.4 | The Ninox token in the Android Keystore (FR-CFG-004, `implement-setup-wizard` §4) | BSD-3-Clause | No |
| `url_launcher` 6.3.3 | Opens the Ninox settings page in the platform's system browser, never a WebView (FR-WIZ-003) | BSD-3-Clause | No |
| `http` 1.6.0 | The one composition that builds the real Ninox adapter (`implement-setup-wizard` §3) | BSD-3-Clause | No |
| `share_handler` 0.0.25, with `share_handler_platform_interface` 0.0.6 and `share_handler_android` 0.0.11 | Android share-in (FR-CAP-008): `ACTION_SEND` and `ACTION_SEND_MULTIPLE` | MIT | No |
| `google_mlkit_document_scanner` 0.6.0 (wrapper only; the scanner itself is Google Play services) | The platform's document scanner, FR-CAP-002 (ADR-006) | MIT for the wrapper; ML Kit Terms of Service for the Google component | **Yes** (the Google component) |
| AndroidX and the Kotlin standard library (through the Flutter Android embedding) | Platform integration | Apache-2.0 | No |

Transitive packages of the dependencies above — platform interfaces, `cross_file`,
`plugin_platform_interface`, `flutter_plugin_android_lifecycle`, and the desktop implementations of
`path_provider` and `file_picker` — are BSD-3-Clause or Apache-2.0, and none of them is a separate
component of the Android build.

**Share-in: chosen and rejected** (`implement-android-capture-and-store`, design §1). The lane chose
between `share_handler` and `receive_sharing_intent` by which one builds on Flutter 3.47.5 with
`minSdk` 24 and `compileSdk` 36:

* `receive_sharing_intent` **1.9.0 — rejected**: it compiles against Android SDK 37, and
  `flutter build apk --debug` fails on `:app:checkDebugAarMetadata` ("Dependency
  ':receive_sharing_intent' requires libraries and applications that depend on it to compile
  against version 37 or later of the Android APIs"). Raising `compileSdk` to 37 was not an option:
  it is pinned to 36 by `setup-mvp-foundations` §4.
* `share_handler` **0.0.25 — chosen**: its Android package compiles against SDK 34, and the debug
  build succeeds unchanged.

**Planned, not yet in the build** — listed so this table is never behind the code:

| Dependency | For | Licence | Proprietary |
| --- | --- | --- | --- |
| Google ML Kit text recognition | Photo route (ADR-010, proposed) | ML Kit Terms of Service | **Yes** |

### ADR-011 candidates — in the build for the evaluation, until Tue 6 Oct

ADR-011 is not closed: the product owner fixed two candidates on 2026-09-25 (D-5) and decides on
Tue 6 Oct, on the evaluation of `close-adr-011-pdf-text-route`. **Both are in the build until then,
and the losing one leaves with its code and its dependency after the decision** (design §5, task
4.2), so the record holds the comparison rather than one side of it. The candidate lines below are
the ones that actually resolve; the size each of them adds is measured in the lane report of that
change (NFR-SIZ-001, `application-size`) and never assumed.

| Dependency | Used for | Licence | Proprietary |
| --- | --- | --- | --- |
| `com.tom-roush:pdfbox-android` 2.0.27.0 (Maven Central), with `org.bouncycastle:bcprov-jdk15to18`, `bcpkix-jdk15to18` and `bcutil-jdk15to18` 1.72 | Candidate A of ADR-011: word boxes with positions, through the Kotlin channel in `android/app/src/main/kotlin/com/nortexsys/paperdrop/pdftext/` | Apache-2.0 (PdfBox-Android); the Bouncy Castle Licence, an MIT-style licence (Bouncy Castle) | No |
| `pdfrx` 2.6.5, with `pdfrx_engine` 0.6.1, `pdfium_dart` 0.3.1, `pdfium_flutter` 0.3.1 and the `url_launcher` 6.3.2 family they pull in | Candidate B of ADR-011: word boxes with positions from PDFium, the engine Chrome renders PDFs with | MIT (each of the four packages states MIT in its own `LICENSE`; the design's table said BSD-3, and the artefact resolved says MIT) | No |

Candidate A ships its library and the Bouncy Castle classes it needs: the release mapping
(`build/app/outputs/mapping/release/mapping.txt`) renames them but keeps them, so Bouncy Castle 1.72
is part of the shipped application. `com.gemalto.jp2.JP2Decoder` is the other case: R8 finds it
referenced and nowhere defined, and it is not in the APK at all.

Candidate B ships **a native binary this project does not build**: `pdfium_dart`'s build hook downloads a
prebuilt PDFium at build time, from
`https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F7811/pdfium-android-arm64.tgz`,
and bundles `lib/libpdfium.so` from it as a native asset. What that binary's licence covers is what its
own distribution says, not what the package's `LICENSE` says. That distribution, read from the archive
the build actually resolved, is:

* its own `LICENSE` is **MIT** (`pdfium-binaries`, Copyright 2014-2025 Benoit Blanchon);
* `licenses/pdfium.txt` is **BSD-3-Clause** (Copyright 2014 The PDFium Authors) — PDFium itself;
* it bundles nineteen third-party licence files (abseil, agg23, catapult, cpu_features, fast_float,
  freetype, icu, lcms, libjpeg-turbo, libopenjpeg, libpng, libtiff, libunwind, llvm-libc, simdutf and
  zlib among them), and `VERSION` says PDFium 149.0.7811.0;
* **no AGPL** appears in any of them, and no GPL obligation applies: the GPL text in `icu.txt` covers
  the Autoconf helper scripts of ICU's source tree, which are not part of the `.so`, and the GPL
  mentions in `libunwind.txt`/`llvm-libc.txt` are the Apache-2.0-with-LLVM-exception clauses. FreeType
  is dual-licensed and the FreeType License option is the one in the archive;
* the archive's licence files do **not** ship inside the APK: the build hook extracts `lib/libpdfium.so`
  and nothing else, and Flutter's `NOTICES` covers Dart packages only. The binary is redistributed
  without its notices, and that gap belongs to whoever takes the decision on Tue 6 Oct.

### ADR-011 candidates — the size measurement (task 1.5, NFR-SIZ-001)

The number reported is the **release arm64 APK** (design §1.3: a debug APK carries the Dart VM and every
ABI and hides the delta that ships). Method: `flutter build apk --release --split-per-abi` on Flutter
3.47.5, `compileSdk` 36, signing with the debug key this project already configures for release; each
variant measured as the file size in bytes of `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
The variants were made by taking the candidates' dependencies **temporarily out** — the Gradle
`implementation("com.tom-roush:pdfbox-android:2.0.27.0")` line, the Kotlin channel and its registration
in `MainActivity`, and the `pdfrx` line in `pubspec.yaml` with the Dart file that imports it — and the
branch was left with both candidates in.

| Build | arm64 release APK, bytes | Delta vs baseline |
| --- | --- | --- |
| Baseline, neither candidate | 18,027,766 | — |
| Candidate A only (PdfBox-Android) | 24,065,306 | +6,037,540 |
| Candidate B only (`pdfrx`/PDFium) | 24,454,472 | +6,426,706 |
| Both (state of the branch) | 30,492,012 | +12,464,246 |

Candidate B's delta is its native library almost exactly: `lib/arm64-v8a/libpdfium.so` is 6,386,696
bytes, stored uncompressed in the APK. Candidate A's delta is its Java classes and the ~4 MB of AFM,
cmap and glyph-list assets the AAR ships. The debug APK's delta is not reported: it is the number
design §1.3 reasons away from, and neither candidate's debug size is a figure to decide on.

**R8 needs one rule for candidate A** — `android/app/proguard-rules.pro`. R8 refuses a release build
while `com.gemalto.jp2.JP2Decoder` is referenced from PdfBox's `JPXFilter` and absent; that codec is
optional and JPEG 2000 never runs on this route, so the reference is declared expected rather than
adding the codec. The rule, the Gradle line and the Kotlin channel are one unit: they leave with
candidate A if candidate B wins.

Development only, not shipped: `flutter_lints`, `flutter_test` (both BSD-3-Clause).
