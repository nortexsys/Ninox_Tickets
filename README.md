# Paperdrop for Ninox

A free, open-source Android and iOS application by Nortex Systems. It reads receipts and supplier
invoices **on the device** and writes one record per document into the user's own Ninox database,
with the original document attached. There is no backend, no Paperdrop account and no call to a
hosted model.

What distinguishes it is the deterministic layer above reading: check digits, arithmetic over
independently read values, legal-rate checks and negative-context suppression confirm or correct
a reading instead of trusting it.

**Status:** MVP build (plan `docs/Plan/Paperdrop_MVP_Plan_v0.2_EN.md`), Android only.
Behaviour is specified in `openspec/`; how to work in this repository is in `AGENTS.md`.

## Layout

| Path | What it is |
| --- | --- |
| `packages/paperdrop_core/` | Everything that decides a value. Pure Dart: no Flutter, no `dart:io`, no network |
| `packages/ninox_client/` | The Ninox port (ADR-003) and its classic REST adapter. Pure Dart + `http` |
| `app/` | The Flutter application: screens, local store, platform adapters |
| `openspec/` | Specifications: the source of truth for behaviour |
| `agents/` | The agent team that builds the product (`agents/README.md`) |
| `docs/` | Approved source documents and the delivery plan. Read-only |

The three Dart packages form one pub workspace (`pubspec.yaml`).

## Build and test

Flutter **3.47.5** stable (Dart 3.13.4), pinned in CI.

```powershell
flutter pub get                                   # the whole workspace
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed packages app/lib app/test
cd packages/paperdrop_core; dart test; cd ../..
cd packages/ninox_client;   dart test; cd ../..
cd app; flutter test; cd ..
cd app; flutter build apk --debug                  # needs the Android SDK
```

## Dependencies

Every dependency of the shipped application, with its licence (NFR-LIC-001). No AGPL component
ships in the app: PyMuPDF is used only by the 16-document test harness and iText is excluded.

| Dependency | Used by | Licence | Proprietary |
| --- | --- | --- | --- |
| Flutter SDK (framework, engine, Android embedding) | `app` | BSD-3-Clause | No |
| `http` | `ninox_client` | BSD-3-Clause | No |
| AndroidX and Kotlin standard library (through the Flutter Android embedding) | `app` | Apache-2.0 | No |
| `flutter_localizations` (from the Flutter SDK) | `app` | BSD-3-Clause | No |
| `go_router` 16.3.0 | `app` — routes | BSD-3-Clause | No |
| `intl` 0.20.3 | `app` — generated localisations | BSD-3-Clause | No |
| `crypto` 3.0.7 | `app` — SHA-256 of the originals (FR-CAP-005) | BSD-3-Clause | No |
| `path` 1.9.1 | `app` — storage paths | BSD-3-Clause | No |
| `path_provider` 2.1.6 | `app` — the application's documents directory | BSD-3-Clause | No |
| `file_picker` 10.3.10 | `app` — the file-picker path (FR-CAP-001) | MIT | No |
| `share_handler` 0.0.25 (with `share_handler_platform_interface` 0.0.6, `share_handler_android` 0.0.11) | `app` — Android share-in | MIT | No |
| `google_mlkit_document_scanner` 0.6.0 — wrapper only; the scanner is Google Play services | `app` — the platform document scanner (FR-CAP-002, ADR-006) | MIT (wrapper); ML Kit Terms of Service (Google component) | **Yes** (the Google component) |

Development only, not shipped: `lints`, `flutter_lints`, `test`, `flutter_test` (all BSD-3-Clause).

**Planned, not yet in the build** — listed so this table is never behind the code:

| Dependency | For | Licence | Proprietary |
| --- | --- | --- | --- |
| Google ML Kit text recognition | Photo route (ADR-010, proposed) | ML Kit Terms of Service | **Yes** |
| PDF text extraction with word positions | Invoice route (ADR-011, open) | To be decided — must not be AGPL | — |

Third-party material vendored for the agent team, not shipped, is listed in `THIRD-PARTY-NOTICES.md`.
