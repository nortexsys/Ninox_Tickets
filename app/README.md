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
| PDF text extraction with word positions | Invoice route (ADR-011, open) | To be decided — must not be AGPL | — |

Development only, not shipped: `flutter_lints`, `flutter_test` (both BSD-3-Clause).
