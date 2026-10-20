# Design: implement-history-retry-duplicates

## 1. Retention

A `RetentionPolicy` function of the entry **state only**: `sent` → delete original (via
`HistoryStore.deleteOriginal`, already present), keep thumbnail and the entry; every other state keeps
the file. It is called after the pipeline reports `Sent` and when an entry is loaded, so a crash between
`sent` and the delete is repaired. Idempotent: deleting an absent file is not an error.

## 2. Duplicates

`DuplicateChecker.check(candidate) -> DuplicateMatch?` reads `HistoryStore.list()` (unreadable entries
are skipped, never fatal). A match is: same `documentHash` as an entry in `sent` state (hash), **or**
equal normalised supplier, equal date and equal total in the candidate's currency (content). Different
total on the same day does not match. The result names the matched `docId` and which criterion hit.
Supplier normalisation: case-folded, whitespace collapsed; no fuzzy matching in this change.
`markDuplicate(docId)` writes `duplicateFlagged = true` with the same `state` and a bumped `revision`.
Nothing is written to Ninox and no marker field is assumed (ADR-013).

## 3. Retry and correction

`RetryService` maps entry state to the pipeline call: `failed` with no record id → `send`; `failed` or
`uncertain` with a record id → `resume`; `queued` → `send`. `uncertain` is never blindly re-sent
(ninox-send reconciliation): the service hands back the pipeline's `Uncertain` outcome for the review
UI. A correction on a `sent` entry builds an update through the port against `ninoxRecordId`; if the
id is absent the correction is refused with a typed failure, never a create.
After every outcome the entry is updated (state, record id, failure reason) and confidence/values are
untouched, so the uncertainty trace survives with nothing mapped.

## 4. Foreground queue

`SendQueue.drain()` takes `queued` entries oldest first, one at a time, via `RetryService`; stops at the
first `Uncertain` or at connectivity loss; reentrant calls are ignored while a drain runs. Triggered by
an injected `Connectivity` stream and by an explicit call on app resume. No isolates, no
`workmanager`.

## 5. Checks

`flutter analyze --fatal-infos`, `dart format`, `flutter test` (host; no device), `privacy_check` and
`core_purity` 0 findings. Tests use `FakeNinoxPort`/fake pipeline and temp directories. The lane makes
no Ninox call and has no token.
