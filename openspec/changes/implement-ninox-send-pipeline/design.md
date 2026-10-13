# Design: implement-ninox-send-pipeline

Owner: Ninox lane. Written by the orchestrator on 2026-10-10.

## 1. Rules

* Writes only `packages/ninox_client/**` and `app/lib/features/send/**`, `app/test/features/send/**`.
  No Ninox write of any kind from tests; no `NINOX_DB_ID`; no token in a file (AGENTS.md §1.3–1.5).
* The pipeline never decides a value and never builds a mapping: it receives `fieldsByName` already
  built (`ninox-send/payload-shape`: keys are current field names).
* Every public type has dartdoc. Money is minor-unit integers; no `double` at any boundary.

## 2. Shape

```dart
final class SendRequest {
  TableRef ref; Map<String, Object?> fieldsByName;
  String filename; Uint8List bytes; String contentType; String docId;
}

sealed class SendOutcome
  Sent(recordId, readBack: NinoxRecord, files: List<NinoxFile>)   // the read-back is what is shown
  Queued()                                                        // no connectivity
  Uncertain(candidates: List<NinoxRecord>)                        // ambiguity: the user chooses
  Incomplete(recordId, reason)                                    // created, attachment not confirmed
  Failed(kind: auth | destinationGone | mapping | server, failure)

abstract interface class SendJournal {
  Future<void> record(String docId, SendStep step, {RecordId? recordId});
}

final class SendPipeline {
  SendPipeline(NinoxPort port, {SendJournal journal, Clock clock,
      Future<void> Function(Duration) sleep, Future<void> Function()? refreshSchema,
      Duration reconcileWindow = const Duration(minutes: 2), int attachmentAttempts = 4});
  Future<SendOutcome> send(SendRequest r);
  Future<SendOutcome> resume(SendRequest r, RecordId created);  // attachment-only retry
  Future<SendOutcome> adopt(SendRequest r, RecordId chosen);    // the user picked a candidate
  Future<SendOutcome> createAnyway(SendRequest r);              // the user said "none of these"
}

Uri recordLink(NinoxEndpoint e, TableRef ref, RecordId id);     // no API call (FR-SND-006)
Uri databaseLink(NinoxEndpoint e, TableRef ref);                // the degraded form
```

The link shape is read from the `ninox` skill / ADR-008; if it is not documented there, the lane
reports it as blocked instead of guessing.

## 3. The matrix as code (FR-SND-004)

| Condition | Behaviour |
| --- | --- |
| Connectivity lost before the request left | `Queued`; journal `queued` |
| `CreateOutcomeUncertain` on create | journal `uncertain`; **reconcile**; never a blind re-POST |
| Timeout on `uploadFile`, `listFiles` or `readRecord` | exponential backoff (1 s, 2 s, 4 s…), bounded by `attachmentAttempts`, then `Incomplete` |
| `Unauthorized` | `Failed(auth)`, no retry |
| `NotFound` | `Failed(destinationGone)`, no retry |
| `ServerError` on create | `refreshSchema()`, **one** retry, then `Failed(mapping)` — never reported as an outage |
| Created, attachment failed | `Incomplete(recordId)`; `resume()` retries the attachment only |

`ServerError` on upload or read-back gets the same single retry and then `Failed(server)`: those
are not mapping errors. `RateLimited` backs off on the safe steps; on create it is `Failed(server)`
without retry, because a rate-limited create may have landed.

## 4. Reconciliation (FR-SND-005)

`listRecords(ref, perPage: 50)`, **sorted and filtered locally** (GAP-023 is not settled). A
candidate has `createdAt` within `reconcileWindow` of the attempt, `createdBy` equal to the token's
user, and every mapped field equal to what was sent.

* Zero candidates → create, once. A second uncertain create ends in `Uncertain` with no candidates,
  not in another loop.
* One → adopt it and continue to the attachment.
* Several, or fewer than two mapped fields to compare against → `Uncertain(candidates)`.
* With nothing mapped, `createdAt` and `createdBy` alone narrow the candidates. No marker field is
  ever written. If `createdBy` cannot be determined, the result is `Uncertain`, not a skipped check.

## 5. Read-back

After a confirmed attachment the pipeline calls `readRecord` and `listFiles`; the attachment must
match name, size and content type. `Sent.readBack` is what the UI shows. The pipeline never returns
what it sent.

## 6. Tests

All on a `FakeNinoxPort` that scripts failures per call and keeps a call log. One test per matrix
row; the four reconciliation scenarios; order of calls (create, upload, read); no `createRecord`
after `uncertain` unless reconciliation found nothing; `resume` calls nothing but file operations;
deep link built with zero port calls and degrading to the database link. Tags per plan §11.1.
Checks, in `packages/ninox_client`: `dart analyze --fatal-infos`, `dart format --set-exit-if-changed .`,
`dart test`; from the root: `python .github/scripts/privacy_check.py`.
