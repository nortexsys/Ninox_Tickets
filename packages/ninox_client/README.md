# ninox_client

The Ninox port of ADR-003 and its classic REST adapter. Pure Dart plus `package:http`.
Team and database are always explicit arguments, never read from the environment (`AGENTS.md` §1.4).

## The public API

One import, `package:ninox_client/ninox_client.dart`, gives:

| Name | What it is |
| --- | --- |
| `NinoxEndpoint` | The host. `NinoxEndpoint.parse(String)` accepts a bare host, a host with a port and an `https://` URL with no path, and returns `null` for anything else (`http://`, a path, a query, a fragment, user info, whitespace); `NinoxEndpoint.cloud` is the default (`api.ninox.com`), and it is the only place the vendor host appears in `lib/` (ADR-017, FR-DST-008). `baseUri`, `host`, `port`. |
| `NinoxCredentials` | The personal access token, and only it: `authorizationHeader` is `Bearer <token>`, and `toString()` prints `NinoxCredentials(***)` (BR-19). |
| `TableRef` | `teamId`, `databaseId`, `tableId` — all three required, never defaulted. |
| `RecordId` | A record identifier, a value type over `String` (`value`). |
| `NinoxTeam`, `NinoxDatabase` | `id` and `name`, as the enumeration endpoints return them. |
| `NinoxTable`, `NinoxField` | A table with **its fields in the same call**; each field is `id`, `name`, `type`. Formula fields are absent from that endpoint rather than marked, and the adapter reads only that endpoint, never `.../schema`. |
| `NinoxRecord` | `id`, `fields` (keyed by field name, verbatim) and, when the endpoint returns them, `createdAt`, `createdBy`, `modifiedAt`, `modifiedBy`, `sequence` — the evidence the reconciliation of an uncertain create runs on. |
| `NinoxFile` | `name`, `size`, `contentType`, as the record's files endpoint returns them. |
| `NinoxFailure` and its subtypes | `Unauthorized` (401/403), `NotFound` (404), `RateLimited` (429), `ServerError(status, …)` (5xx, **usually a field-name problem, not an outage**), `UnexpectedResponse` (any other status, or a 2xx whose body does not carry the documented shape), `TransportFailure` (no response), and `CreateOutcomeUncertain` — a `TransportFailure` subtype for a create whose response was lost, which is never blind-retried (ADR-013). |
| `NinoxPort` | The interface: `listTeams`, `listDatabases`, `listTables`, `createRecord`, `readRecord`, `updateRecord`, `uploadFile`, `listFiles`, `listRecords`. Every method returns `Future<T>` and throws only `NinoxFailure` subtypes. |
| `ClassicNinoxAdapter` | The classic implementation, built from an endpoint, credentials, a required `http.Client` and an optional `timeout` (default 30 s). |
| `SendPipeline` | The send itself (T1.11): create → attach → read back, the retry matrix, the reconciliation of an uncertain create, and the bounds of both. It is pure Dart over `NinoxPort` and takes an injected `SendJournal`, `Clock` and `Sleeper`, plus an optional `refreshSchema` callback. Its methods are `send`, `resume` (attachment-only retry), `adopt` (the record the user chose) and `createAnyway` (the user said *none of these*). |
| `SendRequest` | Where a send goes and what it carries: the `TableRef`, the payload already built under the destination's **current field names** (the pipeline decides no value and builds no mapping), the `docId` the journal is keyed by, and the document's name, bytes and content type. |
| `SendOutcome` and its five outcomes | `Sent` — with the **read-back** (`readBack`, `files`), which is what the UI shows, never what was sent; `Queued` — nothing left the device, so nothing is lost; `Uncertain(candidates)` — the app will not guess, the user chooses; `Incomplete(recordId, reason)` — a record exists without a confirmed document, and its attachment is retried alone; `Failed(kind, failure)` — terminal, with `SendFailureKind` saying what the user has to do (`auth`, `destinationGone`, `mapping`, `server`). |
| `SendJournal`, `SendStep`, `NoopSendJournal`, `InMemorySendJournal` | Where a send reports its transitions. The nine states a document's history carries are `document-history`'s (T1.14), which implements this interface over a local store; `InMemorySendJournal` is the one this package ships, for tests. |
| `Clock`, `Sleeper` | What the pipeline reads the time and the backoff from, both injected so that a test crosses a reconciliation window and asserts the backoff instead of waiting for it. |

`packageName` is exported too, so the workspace can prove the package resolves.

The JSON-reading helpers that live beside the value types (`lib/src/model.dart`) are deliberately
**not** exported: a response shape is the adapter's business, and a second implementation of the
port (ADR-003) reads its own generation's shapes rather than inheriting this one's.

## Provenance of the merge update

`updateRecord` is the primitive `ninox-send/updates-are-merges` (FR-SND-008) is built from: it sends
only the fields it is given, under a `fields` key, so every field not sent keeps its stored value
(ADR-004: *updates are merges*).

Its **verb, path and body come from vendor documentation**, not from a measurement:
`PUT /v1/teams/{teamid}/databases/{dbid}/tables/{tid}/records/{rid}` with
`{"fields": {"<field name>": <value>, ...}}` (Ninox community documentation, "API endpoints for
Public Cloud"). The `ninox` skill documents no update call at all, which is why the lane first
reported the primitive as **blocked** rather than guessing, and why its dartdoc marks it *verb and
path from vendor documentation; to be confirmed live in T1.9*. Nothing else in the port is in that
state: every other call is either verified in the skill's trace or covered by ADR-004.

A lost update response is a **plain `TransportFailure`**, never `CreateOutcomeUncertain`: an update
cannot create a record, and sending the same fields twice leaves the record as one update would.

## The send pipeline

`SendPipeline` is where the sequencing lives, because the expensive failures are sequencing
failures. Its behaviour is `ninox-send`'s, stated as a matrix, and each row is a test in
`test/send/`:

* **create → attach → read back, in that order**, and the outcome carries the **read-back**: fields
  carrying formulas or defaults silently override what was submitted, and the create response does
  not reveal it, so showing the user what was sent would be showing something the app cannot vouch
  for (FR-SND-001, `ninox-send/create-attach-read-back`).
* **A create whose response was lost is never retried.** It enters the reconciliation, which reads
  the destination's recent records, sorts and filters **locally** (`?order=`/`?desc=` are accepted
  by the API and unverified, GAP-023), and adopts the one record that is ours, inside the window,
  carrying what was sent — or asks the user, because the app never guesses (FR-SND-005, ADR-013).
* **An HTTP 500 is a mapping error, not an outage**: the schema is refreshed, the request is retried
  **exactly once**, and the second failure is reported as `SendFailureKind.mapping` (FR-SND-004).
* **A record created without its document is `Incomplete`, never `Sent`**: the attachment is retried
  alone by `resume`, and nothing else about the record is touched (FR-SND-003, FR-SND-008).
* **A 401 is not worth sleeping for**: `Failed(auth)`, no retry. A 404 is `Failed(destinationGone)`,
  no retry. A timeout on an attachment, a read-back or a listing backs off 1 s, 2 s, 4 s … up to
  `attachmentAttempts` (a **total**, not a number of retries) and then stops as `Incomplete`.
* **A connectivity failure before a request left, while no record exists yet, is `Queued`** — the
  offline queue is Mobile's; the pipeline hands it the outcome.

**One input the pipeline has to learn.** A candidate record is one whose `createdBy` is the token's
own user, and the port has no "who am I" call. The pipeline learns that audit key from the read-back
of a record it created itself; until it has read one back, it cannot apply the filter and asks the
user (`Uncertain`) instead of skipping the check. It is deliberately **not** learned from a record
the user chose through `adopt`, which may belong to somebody else.

**What is deliberately not here.** No connectivity detection, no offline queue and no state machine:
the pipeline receives a connectivity failure and returns `Queued`, emits transitions to a
`SendJournal`, and leaves the nine states of `document-history` to T1.14. And no deep link: the URL
structure of `deep-link-back-to-the-record` (FR-SND-006, ADR-008) is **not documented** in the
`ninox` skill or in the ADR — both state the components (*host, team, database, table identifier,
record identifier; the view segment is optional*) and that the structure was verified once, but
neither gives the layout — so the two link builders are **not** written here. Guessing a URL shape is
exactly what the change's design says to report instead of doing.

## What it never does

* **Reads no environment variable.** The target is explicit in every call (`AGENTS.md` §1.4,
  GAP-012); the production-database variable of that section is never named in this package.
* **Transmits one credential and nothing else** — the `Authorization` header, never a body, a
  query or a log line. Every failure this package raises is stringified in a test and searched for
  the token, including a transport error or an error body that quotes it.
* **Retries nothing.** A 500 is classified, not retried; a lost create is uncertain, not retried.
  The retry matrix's state machine is the send pipeline's (T1.11).

## Tests

`dart test` runs everything except what is tagged `live` (`dart_test.yaml`), on recorded,
sanitised bodies from `test/fixtures/classic/` — no test of this package reaches the network: the
adapter's `http.Client` is a required constructor argument, and every test passes a `MockClient`.

The send pipeline's tests (`test/send/`) never touch the adapter at all: they run on
`test/send/fake_ninox_port.dart`, a `NinoxPort` that answers from scripts — one entry per call, a
value or a typed failure — and keeps the order of the calls, plus an in-memory journal, a frozen
clock and a sleeper that records the backoff instead of waiting. That is what makes the matrix
assertable row by row: a timeout on the *second* upload is two scripted entries, and *no create
after an uncertain one* is a call log.

`test/live/order_desc_check_test.dart` is the GAP-023 read-only check. It is **written and never run
by the lane**: it issues GET requests only, and it refuses to run unless it is opted into explicitly
— `PAPERDROP_LIVE_NINOX=1` **and** a token in `NINOX_API_KEY`, both checked inside the test file,
not only in `dart_test.yaml`. A package's `dart_test.yaml` is not read when `dart test` is invoked
from the repository root with a path, and on the product owner's machine the token variable is
present, so the opt-in is what makes an accidental run impossible. The orchestrator runs it on that
machine once `--allow-ninox-token` is approved:

```
PAPERDROP_LIVE_NINOX=1 dart test packages/ninox_client --run-skipped -t live
```

(on Windows: `set PAPERDROP_LIVE_NINOX=1 && dart test packages/ninox_client --run-skipped -t live`).
Without the opt-in it skips from any directory, and `--run-skipped` does not override it.

`test/live/write_limits_test.dart` is T1.9's **write** run (tasks 2.3: *written, not run*). It is
under the same opt-in guard, and the lane that wrote it claims no measured result: the numbers are
produced by the machine that runs it, printed to stdout and written to
`test/live/out/t19_results.json`. It measures, in one pass:

1. create → read back → merge update → read back, on one record with invented values;
2. a small PDF uploaded and read back (name, size, content type), then a ladder of
   **1, 2, 5, 10, 15, 20 and 25 MiB**, stopping at the first failure, each step on a record of its
   own, recording the failure type, the status and the elapsed time;
3. a **multipage** PDF near the largest size that succeeded;
4. the timings of all of it (GAP-004) — the elapsed milliseconds and the MiB/s of every upload.

Its bounds are the approved scope of 2026-10-08: **one** disposable table of the test database and
nothing else — the team, database and table are literals in `test/live/write_limits_test.dart`, as
the live tests require, and are deliberately not repeated here — whose literals the run checks
against the listing before the first write; the ids that were in the table before the run are
recorded and never deleted, and only ids this run created may be deleted (with the test's own
`http.Client`, because the port has no delete); invented data and PDFs generated in-process only; and
hard caps enforced **before** each call by a counter that throws — at most 30 records created, 25 MiB
per attachment, 150 MiB in total. The pieces that must be right before the run — the cap counter, the
PDF builder, the failure classification, the delete-outcome rule and the lag-tolerant verification —
are proved without a token in `test/t19_support_test.dart`, which runs in CI.

The run states its own **30-minute timeout** (`@Timeout` in the file). That is not decoration: the
ladder takes minutes, `package:test`'s default is 30 seconds per test, and the runner abandons a
body that passes it — while the abandoned body keeps writing and `tearDownAll` starts cleaning up.
The 2026-10-08 run's results show exactly that, which is also why deletion is serialised, why a 404
on deleting an id this run created counts as already gone, and why the end-of-run verification
re-lists (bounded) before it calls a record left: a listing lags a delete.
