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

Its bounds are the approved scope of 2026-10-08: **only** table `EF` (`Paperdrop_test`) of
`jd1m8n8l4j7i`, whose literals it checks against the listing before the first write; the ids that
were in the table before the run are recorded and never deleted, and only ids this run created may
be deleted (with the test's own `http.Client`, because the port has no delete); invented data and
PDFs generated in-process only; and hard caps enforced **before** each call by a counter that throws
— at most 30 records created, 25 MiB per attachment, 150 MiB in total. The pieces that must be right
before the run — the cap counter, the PDF builder, the failure classification and the read-back
comparison — are proved without a token in `test/t19_support_test.dart`, which runs in CI.
