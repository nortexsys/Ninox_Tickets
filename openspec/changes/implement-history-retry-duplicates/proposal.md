# Change: implement-history-retry-duplicates

## Why

T2.3 completes the local side of the loop that T1.14 (store) and T1.11 (send pipeline) left open: what
the history does with a send's outcome, when it releases a file, how a failed or queued item is sent
again, and how a duplicate is detected. **No device is needed**: everything here is Dart over
`HistoryStore` and `NinoxPort`, proven with host tests (`flutter test`), fakes and temporary folders.

## What Changes

An **implementation-only change** (`skip_specs: true`); requirements are `document-history`
(`file-retention`, `history-is-the-uncertainty-trace`, `duplicate-criteria`, `correction-and-re-send`)
and the queued half of `capture-intake` · `capture-without-connectivity`. Owner: Mobile lane, under
`app/lib/history/` and `app/test/history/`.

* **Retention** (FR-HIS-004): on `sent` the document file is deleted and the thumbnail kept; `failed`,
  `queued`, `uncertain` keep the file; nothing is deleted by elapsed time.
* **Duplicate check** (FR-DUP-001): read-side, against local history, before a save: hash equal to an
  earlier *sent* entry, or supplier + date + total equal. Plus the setter T1.14 left for this change
  (DEC-016): sets `duplicateFlagged` without changing the state.
* **Retry and correction** (FR-HIS-003/005): re-send of `failed`/`queued` entries through
  `SendPipeline.resume`/`send`; a correction of a `sent` entry updates the record in its
  `ninoxRecordId`, never creates a second one. Confidence and provenance survive the send.
* **Foreground queue** (FR-CAP-009 part): a save with no connectivity stores `queued`; a foreground
  drain sends queued entries one at a time when connectivity is reported back. No background service.

## Out of scope

* The duplicate notice and the permission to proceed (review screen, T2.2).
* The review screen itself, supplier memory, any UI beyond what the tests need.
* Real connectivity detection on a device: the drain takes an injected `Connectivity` port.
* Writes to Ninox of any kind: the pipeline is faked.
