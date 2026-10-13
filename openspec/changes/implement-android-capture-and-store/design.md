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

## 5. T1.14 — Local store and document state machine (FR-HIS-001, FR-HIS-002)

Detailed by the orchestrator on 2026-10-10. Mobile lane. Pure Dart plus `dart:io`; no new dependency.

**Decisions of the product owner (2026-10-10).** (a) `duplicate-flagged` is a separate flag, not a ninth
value of the state (DEC-016). (b) One JSON file per document, not SQLite.

### 5.1 Layout and store

```
app/lib/history/history_entry.dart      HistoryEntry, DocumentState (8 values), toJson/fromJson
app/lib/history/document_machine.dart   allowed transitions, `transition(entry, to, ...)`
app/lib/history/history_store.dart      HistoryStore interface + FileHistoryStore
app/test/history/                       one test file per file above
```

* `FileHistoryStore(Directory root)`: the entry of a document lives at `<root>/<docId>/entry.json`, next to the
  folder `DocumentIntake` already creates for that `docId`. Writes are atomic: write `entry.json.tmp`, flush,
  rename over `entry.json`. A `.tmp` left by a crash is ignored on read and removed on the next write.
* API: `create(entry)`, `get(docId)`, `update(docId, entry)` (rejects a stale `revision`), `list()` newest first.
  A corrupt `entry.json` is reported as a failure for that entry, never throws out of `list()`.
* Serialisation uses `paperdrop_core`'s JSON for every money, rate and provenance value (BR-09): the store is a
  reader of the contract, not a second author. It stores **no** value that `paperdrop_core` cannot round-trip.

### 5.2 The entry (`content-of-a-history-entry`)

`docId`, `revision`, `createdAt`, `state`, `duplicateFlagged`, `documentHash` (SHA-256 from intake),
`thumbnailPath` (nullable until one exists), `destination` (a `TableRef` as plain ids, nothing else),
`values` (extracted values with their provenance, `paperdrop_core` JSON, nullable until extraction), `confidence`
(nullable until validation), `ninoxRecordId` (nullable until created), `failureReason` (a code, never free text with
a value). `ninoxRecordId` is set when a create is confirmed and survives into `sent`.

### 5.3 States and transitions

Eight stored values: `pending`, `queued`, `extracting`, `reviewing`, `sending`, `uncertain`, `sent`, `failed`.
The functional's finer steps (`capturing`, `ingested`, `attaching`, `reading-back`, `reconciling`, `discarded`) are
**not** stored states: `capturing`/`ingested` are `pending`; `attaching`/`reading-back` are `sending`;
`reconciling` is `uncertain`; discarding deletes the entry and its folder. Allowed transitions, and no others:

```
pending -> extracting | failed
extracting -> reviewing | failed
reviewing -> queued | sending          (save online / offline); reviewing -> (deleted) on discard
queued -> sending
sending -> sent | uncertain | failed | queued
uncertain -> sending | sent | failed   (after reconciliation or the user's choice)
failed -> reviewing                    (corrected and re-sent)
sent -> reviewing                      (correction; see FR-HIS-003, an update of the same record)
```

An illegal transition throws a `StateError` named after both states and changes nothing on disk. `sent` requires
`ninoxRecordId`; `queued` is never reached by a failure (`queued` != `failed`; `uncertain` != `failed`).
`duplicateFlagged` can be set in any state and never blocks a transition.

### 5.4 The seam with the send pipeline (not in this change's code)

`ninox_client` (merged on the housekeeping branch, not yet on `main` when this was written) has `SendJournal` /
`SendStep`. The adapter `HistoryEntry` <-> `SendJournal` lives in `app/lib/features/send/` (the Ninox lane's
folder) and is a later task. This change must not import `SendJournal`. Mapping the pipeline wants, for the later
task: `queued -> queued`, `sending/created/attaching/attached -> sending`, `uncertain -> uncertain`, `sent -> sent`,
`failed -> failed`, `incomplete -> sending` with `failureReason = attachment_incomplete`.

### 5.5 Retention (`file-retention`, FR-HIS-004)

Not done here (it depends on a confirmed send). The store exposes `deleteOriginal(docId)` that removes the stored
document file only, leaving `entry.json`; it refuses unless the state is `sent`.

### 5.6 Done when

Tests tagged per plan §11.1: all eight stored values readable; every allowed transition passes and every other
pair throws with nothing changed on disk; `queued` and `uncertain` never read as `failed`; `sent` without a record
identifier is refused; a kill between tmp write and rename leaves the previous entry intact; a corrupt entry does not
break `list()`; round trip with money `{"minor": 1999, "currency": "EUR"}` and provenance by wire name; no two
states at once; `deleteOriginal` refuses outside `sent`. `flutter analyze --fatal-infos`, `dart format`, `flutter test`
from `app/`, `py -3 .github/scripts/privacy_check.py`. Strings, if any, externalised (NFR-I18N-001).

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
