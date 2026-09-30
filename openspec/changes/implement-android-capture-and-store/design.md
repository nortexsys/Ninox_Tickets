# Design: implement-android-capture-and-store

Owner: Mobile lane. Written by the orchestrator on 2026-09-30. §1–§4 (T1.12–T1.13) are detailed for
dispatch now; §5 (T1.14, local store and state machine) is detailed before its own dispatch.

## 1. Rules that bind every file of this change

* Mobile writes `app/**` except the Ninox lane's folders (`app/lib/features/wizard/`,
  `app/lib/features/send/` and their tests — `agents/roles.yaml` `denies`).
* **Nothing that decides a value lives in `app/`** (plan §5). This change decides no value at all: it
  captures, stores and hashes files.
* **New dependencies** are listed in the lane report with their licence and version; none may be
  AGPL or GPL (NFR-LIC-001, `local-config-privacy` · `no-agpl-component-ships`), and the README's
  dependency declaration (setup-mvp-foundations §9) is updated in the same commit. The orchestrator
  reviews each before merge. Preferred, all permissive: `go_router` (routing), `flutter_localizations`
  + `intl` via `flutter gen-l10n` (strings), `google_mlkit_document_scanner` (FR-CAP-002),
  `file_picker` (picker), `crypto` (SHA-256), `path_provider` (app storage). For share-in, the lane
  chooses between `share_handler` and `receive_sharing_intent` — whichever builds cleanly on Flutter
  3.47.5 with `minSdk` 24 and `compileSdk` 36 — and reports why.
* **Every platform service sits behind a small interface** in `app/lib/adapters/`, so widget and unit
  tests run on the host with fakes, and no test needs a device. The device check is §4's, done by the
  orchestrator with the product owner.
* Tests tagged per plan §11.1; a partial proof is untagged and names the scenario in a comment.
* Every user-facing string is externalised from the first line (NFR-I18N-001); English only in the
  MVP (plan §4.8 — German UI is R1).

## 2. T1.12 — App shell (NFR-I18N-001, NFR-ACC-001 part)

```
app/lib/app/paperdrop_app.dart     MaterialApp.router, theme, localisation delegates
app/lib/app/router.dart            go_router: /capture (home), /intake/:docId (placeholder)
app/lib/l10n/app_en.arb            every string; `l10n.yaml` at app/
app/lib/features/capture/          the capture screen
```

* **One capture entry point** (`capture-intake` · `one-entry-point-four-paths`): the home screen has
  exactly two actions in the MVP — *Scan* (system scanner) and *Choose file* (picker) — and share-in
  lands on the same pipeline without a separate screen. `.msg`/`.eml` is R1 (plan §4.1), so it is not
  offered.
* Routing for the Ninox features is registered from `wizard_routes.dart` / `send_routes.dart` once
  they exist (setup-mvp-foundations §2); in this change the router has a single documented place
  where they will be added, and imports nothing from Ninox's folders.
* **Accessibility baseline**: every tappable control has a semantic label from the ARB file; touch
  targets ≥ 48 dp; text scales with the system setting (no fixed text scale). A widget test runs
  Flutter's accessibility guidelines (`meetsGuideline` for `androidTapTargetGuideline`,
  `labeledTapTargetGuideline`, `textContrastGuideline`) on the capture screen. The review- and
  history-screen scenarios of `accessibility` are not in this change: no tag.
* **No hardcoded user-facing string** (`all-user-facing-strings-are-externalised` · *no string is
  hardcoded*): a test scans `app/lib/` for string literals passed to `Text(`, `semanticsLabel:`,
  `tooltip:`, `label:` and `SnackBar(` and fails on any that is not from `AppLocalizations`. Keep it
  simple and document its limits in the test; the scenario is tagged only if the scan covers every
  user-facing constructor used in `app/lib/`.

## 3. T1.13 — Capture and intake (FR-CAP-001 … FR-CAP-005)

```
app/lib/adapters/scanner/     DocumentScanner (interface) + MlKitDocumentScanner
app/lib/adapters/intake/      FilePickerSource, ShareInSource (interfaces) + implementations
app/lib/intake/               DocumentIntake, IntakeResult, the byte-for-byte store of originals
```

**Scanner** (`platform-document-scanner`, `camera-captures-are-assembled`, `multi-page-is-one-expense`):
ML Kit Document Scanner in **PDF mode**, multi-page allowed, gallery import off. The scanner's own
PDF is the attachment: cropping, deskewing, enhancement and page assembly come from the platform, and
the app **adds no image processing** — no perspective correction, no binarisation, no re-encoding of
the scanner's output (*the app carries no pre-processing of its own*: a test scans `app/lib/` for
image-processing imports such as `package:image` and fails on any). If the scanner returns only JPEGs
(no PDF), that is a failure to report, not a reason to assemble a PDF in the app.

**Received files** (`received-files-are-attached-byte-for-byte`): from the picker and from share-in.
Accepted media types in the MVP: `application/pdf`, `image/jpeg`, `image/png`. The file is **copied
as a byte stream** into app storage — never decoded, re-rendered, re-saved or re-compressed — and the
SHA-256 is computed over the input stream while copying and again over the stored copy; they must be
equal or the intake fails with an externalised error and stores nothing.

**Share-in on Android**: `ACTION_SEND` and `ACTION_SEND_MULTIPLE` with `application/pdf` and `image/*`
in the manifest, content URIs read as streams. **Several files shared at once are refused in the MVP**
(product owner, 2026-09-30): nothing is stored, and the capture screen shows an externalised message
asking the user to share one document at a time. `ACTION_SEND_MULTIPLE` is declared only so the app
can say so instead of silently taking the first file. What several files should become is an R1
decision.

**`DocumentIntake`** — one entry for all paths, so every path lands in the same pipeline
(*every path lands on the same screen*): `Future<IntakeResult> intake(IntakeSource source, Stream<List<int>> bytes, {String? filename, String mediaType})`.
`IntakeResult`: `docId` (random, content-free — 128 bits from `Random.secure()`, hex), `source`
(`scanner`, `picker`, `shareIn`), `mediaType`, `byteLength`, `sha256` (hex), `storedPath`. Storage:
`<app documents>/originals/<docId>/original.<ext>` with the extension from the media type — the
original file name is **not** used in the path and not stored (it can carry an invoice number or a
person's name). After intake the app navigates to `/intake/:docId`, a placeholder screen showing the
media type, size and the first 12 hex digits of the hash, until extraction and review exist (M2).

Tests (host, no device): the intake over a fixture PDF proves hash equality and byte equality of the
stored copy (tag `[capture-intake/received-files-are-attached-byte-for-byte] the attachment is the
input` only for the "before" half — the "after extraction" half needs extraction: untagged); the
three sources produce the same `IntakeResult` shape and the same navigation; an unsupported media type
is refused with an externalised message; a stream error leaves no partial file. The fixture PDF is
synthetic, generated for the test (`corpus_test/src/make_demo_invoice.py` or a minimal hand-written
PDF) — **never** a file from `Paperdrop_corpus`.

## 4. Device check (orchestrator + product owner)

After the lane's tests are green: `flutter build apk --debug`, install on the product owner's Galaxy
S22 over wireless adb, and the product owner runs, once each: scan a two-page document; pick a PDF;
share a PDF from another app. The orchestrator compares the SHA-256 of the stored original with the
source for the picked and shared files (`adb shell run-as com.nortexsys.paperdrop sha256sum ...`).
Results go in the daily status.

## 5. T1.14 — Local store and document state machine

To be detailed before dispatch: `document-history` · `content-of-a-history-entry`, `document-states`
(Funcional §6.2.3); documents serialised with `paperdrop_core`'s JSON (BR-09); the store is local-only
(ADR-009) and declared (`both-local-stores-are-declared`).

## 6. Decisions of the product owner (2026-09-30)

1. **Several files shared at once are refused in the MVP** (§3).
2. **Lane order**: after T1.12–T1.13 the Mobile lane takes `close-adr-011-pdf-text-route` (T1.15),
   so ADR-011 is decided on Tue 6 Oct; T1.14 (§5) follows it.

## 7. What this change does not do

No extraction, OCR or PDF text (T1.15–T1.16), no review or history screens (M2), no Ninox, no
`.msg`/`.eml` (R1), no iOS (R2), no German UI (R1).

## 8. Risks

* **Scanner plugin maturity.** If `google_mlkit_document_scanner` does not build on Flutter 3.47.5 /
  `compileSdk` 36, the lane stops and reports; it does not substitute a raw camera view (FR-CAP-002
  forbids it).
* **Content-URI permissions** on share-in can expire when the sharing app finishes; the copy must be
  done immediately on receipt.
