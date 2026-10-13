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
| `google_mlkit_text_recognition` 0.17.1, with `google_mlkit_commons` 0.13.0 (wrapper only; the recogniser is Google ML Kit) | The photo route's recognition: ML Kit text recognition, Latin script (`implement-photo-route`, FR-EXT-015; ADR-010 is **proposed**) | MIT for the Dart wrapper (its own `LICENSE`); ML Kit Terms of Service for every Google component it links (each resolved artefact's POM says so) | **Yes** (the Google components) |
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

**The photo route's engine took that row's place** (`implement-photo-route`): ML Kit text recognition is in the build, and the row above says so with the version this application resolves and the licence read from the artefacts. ADR-010 itself stays **proposed** — the approach is decided, and the engine is confirmed by the screening of T2.5 on the photographed corpus, which no lane has run yet. The size numbers the choice is made on are in the section below; the accuracy is not measured here at all.

### ADR-010 (proposed) — the photo route's engine, `implement-photo-route`

The port is `OcrTextSource` (`app/lib/adapters/ocr/`), the photo-route twin of
`PdfTextSource`: pages of Core's `TextPage` in integer thousandths of a point, top-left
origin, so the rule that binds a label to its value is written once. The implementation is
`MlKitOcrTextSource` over ML Kit's **Latin** script recogniser, and it reads the same page
several times — `p1-native` at 150 dpi, `p2-hi` at 200, `p3-lo` at 100 and `p4-contrast` at
150 with the levels stretched. The passes are returned separately and never merged here:
choosing a value across them is Core's consensus (T1.5/T2.1, FR-EXT-006). PDF pages are
rendered with the PDFium this project already links for the invoice route (`pdfrx`).

**The packaged form is measured, not chosen** (design §2, NFR-SIZ-001). The plugin's default
form is the one that bundles the Latin model; the other form was built by substituting
`com.google.mlkit:text-recognition` with `com.google.android.gms:play-services-mlkit-text-recognition:19.0.1`
in `android/app/build.gradle.kts` for the length of one measurement and taking the
substitution out again. Three release arm64 APKs of the same commit, built with
`flutter build apk --release --split-per-abi` on Flutter 3.47.5, `compileSdk` 36, signed with
the debug key this project already configures for release, each measured as the byte size of
`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`:

| Build | arm64 release APK, bytes | Delta vs baseline |
| --- | --- | --- |
| Baseline, without the text recognition dependency | 25,688,040 | — |
| **Bundled** (the plugin's default) | 38,239,844 | **+12,551,804** |
| **Unbundled** (the Play-services form) | 25,787,439 | **+99,399** |

The bundled delta is the model and its pipeline: `lib/arm64-v8a/libmlkit_google_ocr_pipeline.so`
is **11,064,544** bytes, stored uncompressed, the twenty-one files under
`assets/mlkit-google-ocr-models/` come to **1,486,803** bytes, and `classes.dex` grows by
**510,008**. The unbundled delta is that same client in `classes.dex` (**+239,068**) and the
three `.properties` markers of the Play-services modules, with no model and no pipeline
library: the model is downloaded by Google Play services at run time instead, which is why
that form is small and why it needs Play services on the device. Neither number is a
decision: the product owner chooses, and the accuracy those two forms reach is what T2.5
measures.

**Licence, read from the artefacts the build resolved** (NFR-LIC-001). The Dart wrapper
`google_mlkit_text_recognition` 0.17.1 states **MIT** in its own `LICENSE`. Every Google
component under it states **ML Kit Terms of Service** in its own POM
(`com.google.mlkit:text-recognition:16.0.1`, `text-recognition-bundled-common:17.0.0`,
`vision-common:17.3.0`, `vision-interfaces:16.3.0`, `com.google.mlkit:common:18.11.0`, and the
`com.google.android.gms` family of the unbundled form), and the Google Play services
foundations declare the Android Software Development Kit Licence. **No AGPL and no GPL
component is introduced**, and no licence notice ships inside the APK with the model: the
Google components are proprietary, as the table above says.

**R8 needs eight rules, and they are in the repository.** ML Kit's plugin builds a recogniser
for five scripts and declares four of them — Chinese, Devanagari, Japanese, Korean —
`compileOnly`: its `TextRecognizer.initialize` names their option classes and no artefact
carries them, so the release build failed on eight missing classes until
`android/app/proguard-rules.pro` suppressed them, one line each, alongside the same eight
lines the Android Gradle plugin generates for itself. The application uses the Latin
recogniser only, and the file says so. Its `proguardFiles` lines are the application's, in
`android/app/build.gradle.kts`.

### ADR-011 — closed on candidate B, `pdfrx`

The product owner closed ADR-011 on **2026-10-07** in favour of candidate B, PDFium through `pdfrx`
(GAP-002 closed; evidence in `validation/reviews/adr-011-2026-10-07.md`: word-level fidelity 91.1%
recall against the reference where candidate A reached 5.2%, and every confirmed total bound where
candidate A found no label at all). Candidate A, PdfBox-Android, left the build with its code, its
Gradle line and the R8 rule its optional JPEG 2000 codec needed (design §5); its measurements stay in
the review file and in the size table below.

| Dependency | Used for | Licence | Proprietary |
| --- | --- | --- | --- |
| `pdfrx` 2.6.5, with `pdfrx_engine` 0.6.1, `pdfium_dart` 0.3.1, `pdfium_flutter` 0.3.1 and the `url_launcher` 6.3.2 family they pull in | Word boxes with positions from PDFium, the engine Chrome renders PDFs with — the text-layer half of the invoice route (FR-EXT-004, ADR-011, ADR-014) | MIT (each of the four packages states MIT in its own `LICENSE`; the design's table said BSD-3, and the artefact resolved says MIT) | No |
| The **PDFium binary** `pdfium_dart`'s build hook downloads and links (`lib/libpdfium.so`), with the nineteen licence notices its distribution carries | The engine itself: this project does not build it, and those notices ship with it under `app/assets/licenses/pdfium/` | MIT (the `pdfium-binaries` packaging), BSD-3-Clause (PDFium), plus the bundled third-party notices | No |

Candidate B ships **a native binary this project does not build**: `pdfium_dart`'s build hook downloads a
prebuilt PDFium at build time, from
`https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F7811/pdfium-android-arm64.tgz`,
and bundles `lib/libpdfium.so` from it as a native asset. What that binary's licence covers is what its
own distribution says, not what the package's `LICENSE` says. That distribution — read out of the archive
the build actually resolved, whose Windows library is byte-identical to the one the resolved build
produced, the Android one being what the APK carries — is:

* its own `LICENSE` is **MIT** (`pdfium-binaries`, Copyright 2014-2025 Benoit Blanchon);
* `licenses/pdfium.txt` is **BSD-3-Clause** (Copyright 2014 The PDFium Authors) — PDFium itself;
* it bundles eighteen third-party licence files (abseil, agg23, catapult, cpu_features, fast_float,
  freetype, icu, lcms, libjpeg-turbo, libopenjpeg, libpng, libtiff, libunwind, llvm-libc, simdutf and
  zlib among them), and `VERSION` says PDFium 149.0.7811.0;
* **no AGPL** appears in any of them, and no GPL obligation applies: the GPL text in `icu.txt` covers
  the Autoconf helper scripts of ICU's source tree, which are not part of the `.so`, and the GPL
  mentions in `libunwind.txt`/`llvm-libc.txt` are the Apache-2.0-with-LLVM-exception clauses. FreeType
  is dual-licensed and the FreeType License option is the one in the archive;
* **they ship.** The archive's `LICENSE`, its `VERSION` and its whole `licenses/` directory are copied
  byte for byte into `app/assets/licenses/pdfium/`, declared as assets in `pubspec.yaml`, and registered
  with Flutter's licence page from `main()`: nineteen notices under the package name `PDFium`, each
  headed with the path it has inside the distribution. `NOTICES` alone would not have carried them — it
  covers Dart packages, and the build hook extracts the `.so` and nothing else. One of the notices,
  `licenses/freetype.txt`, is not valid UTF-8 in the distribution itself; it is read with its malformed
  bytes replaced rather than rewritten, and every other file is shipped as it is.

### ADR-011 — the size measurement (task 1.5, NFR-SIZ-001)

The number reported is the **release arm64 APK** (design §1.3: a debug APK carries the Dart VM and every
ABI and hides the delta that ships). Method: `flutter build apk --release --split-per-abi` on Flutter
3.47.5, `compileSdk` 36, signing with the debug key this project already configures for release; each
variant measured as the file size in bytes of `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
The variants were made by taking the candidate's dependency **temporarily out** — the `pdfrx` line in
`pubspec.yaml` with the Dart file that imports it, and, for candidate A, its Gradle line, its Kotlin
channel and the registration of that channel. The table is the record of the comparison the product
owner decided on; the branch itself now carries candidate B only.

| Build | arm64 release APK, bytes | Delta vs baseline |
| --- | --- | --- |
| Baseline, neither candidate | 18,027,766 | — |
| Candidate A only (PdfBox-Android, removed 2026-10-07) | 24,065,306 | +6,037,540 |
| Candidate B only (`pdfrx`/PDFium, chosen) | 24,454,472 | +6,426,706 |
| Both, the state the comparison was run from | 30,492,012 | +12,464,246 |

Candidate B's delta is its native library almost exactly: `lib/arm64-v8a/libpdfium.so` is 6,386,696
bytes, stored uncompressed in the APK. Candidate A's delta was its Java classes and the ~4 MB of AFM,
cmap and glyph-list assets the AAR ships. The debug APK's delta is not reported: it is the number
design §1.3 reasons away from, and neither candidate's debug size is a figure to decide on.

**R8 needed one rule for candidate A, and it went with it** — the file
`android/app/proguard-rules.pro` is gone. R8 refused a release build while
`com.gemalto.jp2.JP2Decoder` was referenced from PdfBox's `JPXFilter` and absent; that codec is
optional and JPEG 2000 never ran on this route, so the reference was declared expected rather than
adding the codec. It is recorded here because the cost was real and candidate A's evaluation could not
have been run without it.

Development only, not shipped: `flutter_lints`, `flutter_test` (both BSD-3-Clause).
