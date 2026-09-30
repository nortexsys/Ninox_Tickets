# Change: implement-android-capture-and-store

## Why

The MVP is one honest loop, and the loop starts with a document arriving and a document being
kept. Until the app can capture a paper receipt, receive a PDF from another application, store
either one byte for byte and hold its own state, there is nothing to extract, nothing to review
and nothing to send — which is why plan v0.2 §9 puts this change in week 1 alongside the core
contract and the Ninox client rather than after them.

Three things that look like plumbing are actually load-bearing, and each is a requirement rather
than a convenience. **Byte integrity**: a document the app was handed is someone else's file, and
re-saving a ZUGFeRD or Factur-X invoice destroys the legally authoritative XML embedded in it —
the pipeline would then fall back to text or OCR, produce a worse result and report nothing
wrong, so the acceptance condition is a hash comparison and not an inspection. **The state
machine**: `queued`, `uncertain` and `failed` are three different situations — waiting, genuinely
unknown, known to have failed — and collapsing them is exactly how a create whose response was
lost gets retried and duplicated in someone's accounting. **History as a first-class surface**:
mapping is optional, so a user who mapped nothing gets records in Ninox carrying an attachment
and nothing else, and if history did not survive the send nothing on the device would say which
records the app had been unsure about.

This change also lays the surface every later Mobile change stands on — the shell, the
navigation, externalised strings and semantic labels — because a screen written without
externalised strings and semantic labels is cheaper to rewrite than to retrofit, and NFR-ACC-001
is what device automation relies on as much as what an auditor checks.

## What Changes

An **implementation-only change** (`skip_specs: true`, plan §8.2). No requirement is added,
modified, removed or renamed, and no living spec is touched. All code goes in `app/`, in the
Mobile lane's own folders.

* **T1.12 — app shell, navigation, externalised strings, semantic labels** (plan §9 M1). The
  Flutter shell `setup-mvp-foundations` stubbed, the navigation the wizard (T1.10) and the review
  and history screens (T2.2–T2.3) plug into, and the string layer. Every
  user-facing string is externalised from the first screen, including error messages, with
  **English only** in the MVP (plan §4.8: the German interface is R1); the shell's current
  hardcoded title is the last hardcoded string this change removes. Every control carries a
  semantic label, colour states are paired with a non-colour cue, and large-type fields are the
  default.
* **T1.13 — scanner, file picker, Android share intent, byte-for-byte storage and hash** (plan
  §9 M1). Camera capture through the platform document scanner — ML Kit Document Scanner on
  Android — assembling the captured pages into one PDF that is what gets attached; the file
  picker and the Android share-intent filter, which needs no separate component (FR-CAP-008);
  and the intake store, where a received file is kept byte for byte and never re-saved,
  re-rendered, flattened or re-compressed, with its SHA-256 recorded so that the duplicate
  criteria have something to compare against (T2.3, below). Multi-page captures and multi-page
  PDFs are one record with one attachment, in page order.
* **T1.14 — local store and document state machine** (plan §9 M1). The persistent store of
  history entries and the nine-state machine of Funcional §6.2.3, with the transitions this
  change's own screens drive — `pending`, `extracting`, `reviewing` and, for a save performed
  offline, `queued` rather than `failed`. A capture that produces a history entry holds the
  thumbnail, the extracted values with their provenance, the destination, the state, the
  confidence, the document hash and, once sent, the Ninox record identifier. **The store
  serialises documents with `paperdrop_core`'s JSON** (BR-09): money as
  `{"minor": 1999, "currency": "EUR"}`, rates as integers, provenance by wire name, `Absent` and
  `NotInXml` as their states — one shape, shared with the core's own round-trip test, so the
  store is a reader of the contract and not a second author of it.

The requirement names below stop where the plan stops. **FR-CAP-009, FR-HIS-004, FR-HIS-005 and
FR-DUP-001 are all `MVP` (or `MVP◐`) in the cut but sit in M2's T2.3, not in T1.14** (plan §4.1,
§4.8, §9.2: "History, retry, file retention, duplicates … foreground queue (FR-CAP-009 part)") —
the queued send's drain, file retention, history as a surfaced uncertainty trace and
the duplicate criteria are realised by that task, on the store this change builds. They are named
under Deferred, not under Requirements implemented, and T1.14 implements only the store, the
machine and the fields that make them possible.

## Requirements implemented

Identifiers as the functional spells them; the requirement name is the one that owns the
behaviour in `openspec/specs/`. Each item states the part this change satisfies, because most of
these requirements have a half that belongs to a later change.

* **FR-CAP-001** — `capture-intake` · `one-entry-point-four-paths`: the three paths the MVP cut
  keeps — the platform document scanner, the file picker, and Android share-in — all delivering
  into the same pipeline. The requirement is written on four paths and the MVP cut keeps three,
  so the fourth is absent by cut and not by omission: the `.msg`/`.eml` path is R1 (plan §4.1),
  which is why FR-CAP-006 and FR-CAP-007 are not in this list.
* **FR-CAP-002** — `capture-intake` · `platform-document-scanner`: ML Kit Document Scanner,
  never a raw camera view, with edge detection, perspective correction, contrast enhancement and
  multi-page chaining from the platform. The prototype's pre-processing stage is not ported, and
  no perspective-correction or binarisation routine exists in the app's own code.
* **FR-CAP-003** — `capture-intake` · `multi-page-is-one-expense`: several pages become one
  record with one multi-page attachment, in page order. Extraction reading every page is T1.5's;
  this change guarantees the object that happens to.
* **FR-CAP-004** — `capture-intake` · `camera-captures-are-assembled`: the assembled PDF is what
  is attached, page order preserved.
* **FR-CAP-005** — `capture-intake` · `received-files-are-attached-byte-for-byte`: the
  requirement that makes a shared ZUGFeRD or Factur-X invoice survive, and BR-17 with it. The
  SHA-256 of the stored file equals that of the input, before and after any extraction has run,
  and reading for extraction is read-only by construction. This change stores and hashes; the
  attachment itself is sent by `implement-send-pipeline` (T1.11), which is why the hash is
  recorded now.
* **FR-HIS-001** — `document-history` · `content-of-a-history-entry`: all eight items, in the
  store this change builds and in the detail that reads it. Provenance is among them and never
  leaves the device, which is the point of the requirement.
* **FR-HIS-002** — `document-history` · `document-states`: exactly one of the nine states, with
  the transitions of Funcional §6.2.3. The transitions this change drives are its own screens'
  (`pending` → `extracting` → `reviewing` → `queued` for an offline save, which the store turns
  into `queued` rather than `failed`); `sending`, `uncertain`, `sent` and `failed` are driven by
  the send pipeline of T1.11 and are present in the machine now so that change transitions them
  rather than defining them. The history screen that surfaces the states to the user is T2.3's.
* **NFR-I18N-001** — `local-config-privacy` · `all-user-facing-strings-are-externalised`: every
  string externalised, error messages included, with no hardcoded user-facing text. The
  requirement's language half — that the interface ships in English **and German** — is
  `countries-languages`' `interface-languages` and is R1 by the MVP cut (plan §4.8, the
  FR-CTR-006 row); this change ships English only and ships it externalised, which is what makes
  the German half a later translation rather than a rewrite.
* **NFR-ACC-001** — `local-config-privacy` · `accessibility`: semantic labels on every control,
  colour paired with a non-colour cue, large-type fields by default. The read-region and
  confidence-state exposure to assistive technology comes with the review screen (T2.2), and the
  full auditor pass is R1 (plan §4.10).
* **BR-17** — `capture-intake` · `received-files-are-attached-byte-for-byte`: byte integrity of a
  received file, carried by FR-CAP-005 as the capability tree assigns it.
* **BR-09** — `product-invariants` · `money-as-integer-minor-units`: the local-store half. The
  store serialises with `paperdrop_core`'s JSON, so an amount stays an integer in its minor unit
  from the store to the payload, and never becomes a JSON number with a fraction. The core and
  the payload halves are `implement-core-model-and-countries`' and `implement-ninox-client`'.

## Gaps and decisions this change acts on

* **GAP-007** (open, `NO BLOQUEANTE`) — the iOS Share Extension's native work is budgeted as
  FASE 3 and may need a native bridge to Vision. This change implements the Android half
  FR-CAP-008 names — a share-intent filter, no separate component — and none of the iOS half; the
  gap stays open against iOS, which is R2.
* **GAP-004** (open, `NO BLOQUEANTE`) — the maximum attachment size is still unmeasured, which a
  multi-page document near that limit runs into. This change produces the multi-page attachments
  the measurement is taken on; the measurement itself is `implement-ninox-client`'s T1.9, and no
  threshold is stated here.
* **DEC-007** (product decisions register) — an edited amount does not re-expand the amounts
  block and the edited marker replaces the confidence colour. Not acted on by this change, since
  the amounts block is the review screen's (T2.2); it is named here because the `Edited` value
  this change stores and later displays carries no confidence colour by construction, so the
  store is already on the decided side of it.
* **BR-16 / BR-19** — no step of this change writes to Ninox or holds a credential. The store is
  local; the token reaches the app through `implement-setup-wizard` (T1.10) and the platform
  keystore, and this change's shell asks for no permission beyond camera and file access.

## Deferred

Design and tasks are the orchestrator's; the boundary below is stated so the next Mobile changes
do not have to renegotiate it.

* **T1.15 — ADR-011 and the PDF positional adapter** (`close-adr-011-pdf-text-route`, plan §8.3
  change 8, W2): the PDF text-extraction library, decided by 2026-10-06, with its word-position
  contract and its size measurement (NFR-SIZ-001, GAP-002). This change stores and hashes the
  PDF and does not read its text layer.
* **T1.16 — the OCR adapter** (`implement-photo-route`, plan §8.3 change 9, W2–W3): ML Kit text
  recognition behind the ADR-010 port, the multi-pass strategy and the ADR-010 screening. This
  change hands the scanner's PDF over; it recognises nothing.
* **T2.2 / T2.3 — review, history surfaces, retry and duplicates' notice** (plan §9 M2): the
  review screen with its confidence colours and the amounts block of DEC-007; and, on the store
  this change builds, **the queued send's drain when connectivity returns while the app is open**
  (FR-CAP-009 · `capture-without-connectivity`), **file retention** (FR-HIS-004 ·
  `file-retention`), **history as the surfaced uncertainty trace** (FR-HIS-005 ·
  `history-is-the-uncertainty-trace`) and **the duplicate criteria** (FR-DUP-001 ·
  `duplicate-criteria`, whose hash arm this change supplies) — all four `MVP` in the cut and
  assigned to T2.3 rather than to T1.14. Background delivery and the background queue are R1.
* **R1** — the `.msg`/`.eml` path with `mail-containers-ingest-attachments-only` and
  `attachment-selection-rule` (FR-CAP-006, FR-CAP-007), the German interface
  (`interface-languages`), correction and re-send (FR-HIS-003), the background queue, and the
  clearing action that empties this store (`local-data-clearing`, FR-CFG-003).
* **The read region and confidence exposure to assistive technology** arrives with the review
  screen, and the full accessibility audit with R1 (plan §4.10).

## Impact

`app/` only — the shell and navigation of `app/lib/app/`, the capture, intake and store code in
the Mobile lane's own feature folders, and their widget and integration tests. `packages/`
change: this change consumes `paperdrop_core`'s published JSON contract and adds no dependency to
it. No living spec changes; no functional change; no new decision is taken, so nothing is
recorded in `openspec/product-decisions.md`. `openspec validate
implement-android-capture-and-store --strict` passes with zero deltas.

Nothing this change does writes to Ninox or needs an approval to do so: capture, storage and the
state machine are entirely local, and the first request the app makes is `implement-setup-wizard`'s
(T1.10). No step uses `NINOX_DB_ID` (`AGENTS.md` §1.4).
