# Design: implement-review-screen

## 1. State, not widgets first

A `ReviewController` (plain Dart, host-testable) owns the screen state; widgets only render it.
Input: the stored `HistoryEntry` + its `CanonicalDocument` (from `ExtractionCompleted`, or reloaded from
the store), the `Destination` list (`DestinationStore.readAll`), a `DuplicateChecker`, a
`SendPipeline`/`RetryService` port, a `Clock`. Edits are held as `Edited<T>` over the canonical field
(`field_value.dart`); an `Edited` is what is sent, is never recomputed and never confirms anything.

## 2. Fields and confidence

Fixed order: `doc_date`, `supplier_name`, `supplier_tax_id`, `doc_number`, `gross_total`, `currency`.
Colour from `ConfidenceState`; `Edited` shows an *edited* mark and **no** colour, and the mark stays
until save or discard. Initial focus: first field that is `Absent` or red, else `doc_date`.
Text comes from `app_en.arb` (no literals), every control has a semantic label (NFR-ACC-001 part).
Unverified (no country row) is amber; no new state (PO, 2026-10-17).

## 3. Amounts block

Collapsed to one confirming line iff a redundancy check passed (green total from `base + tax = total`).
Expanded when the check fails, when there is no breakdown (total only), and when several tax slots are
occupied and the check does not pass: every occupied slot visible. Editing an amount after a passing
check leaves the block as the check left it (DEC-007); the amount is marked edited. Green values are
editable only after tapping their lock (`validation-confidence`).

## 4. Destination bar and daily acknowledgement

Bar shows team / database / table, always visible, tap opens destination selection and returns to the
same document (state kept in the controller). Pre-loaded with the last destination used. On the first
capture of a calendar day (by `Clock`, local date) the bar is highlighted and the save button is
disabled until acknowledged; the acknowledgement date is persisted in a small file beside
`destinations.json`. It is the **only** condition that may disable save.

## 5. Duplicate notice, save, discard

`DuplicateChecker.check` runs when the screen opens; a match shows a notice linking to the existing
entry and a "proceed anyway" action; proceeding sets `markDuplicate` and saves (second record on
purpose). Save is fixed at the bottom, labelled with the table name ("Save to <table>"), never disabled
by missing, unreadable or low-confidence data; an empty document saves with the attachment and no data.
Save builds the send request from the edited-or-extracted values and calls the pipeline; the outcome
moves to the confirmation screen (out of scope: a returned outcome is enough). Discard creates no record,
deletes the local capture and leaves no history entry (`HistoryStore` delete, whole folder).

## 6. Thumbnail

Show the stored thumbnail, tap for full screen. No box, no zoom (R1).

## 7. Checks

`flutter analyze --fatal-infos`, `dart format`, `flutter test` (host), widget tests for each scenario of
the cut requirements, `privacy_check`, `core_purity`, `no_ninox_db_id` 0 findings. Lane has no token and
no Ninox call; fixtures are synthetic.
