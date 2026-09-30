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
| `NinoxPort` | The interface: `listTeams`, `listDatabases`, `listTables`, `createRecord`, `readRecord`, `uploadFile`, `listFiles`, `listRecords`. Every method returns `Future<T>` and throws only `NinoxFailure` subtypes. |
| `ClassicNinoxAdapter` | The classic implementation, built from an endpoint, credentials, a required `http.Client` and an optional `timeout` (default 30 s). |

`packageName` is exported too, so the workspace can prove the package resolves.

The JSON-reading helpers that live beside the value types (`lib/src/model.dart`) are deliberately
**not** exported: a response shape is the adapter's business, and a second implementation of the
port (ADR-003) reads its own generation's shapes rather than inheriting this one's.

## What the port does not have yet

**No update method.** `ninox-send/updates-are-merges` (FR-SND-008) needs a merge update, and the
change's design lists it as `updateRecord`. The `ninox` skill documents every other call of this
port — endpoint, verb and body — but nowhere the update: no path, no verb, no body. The lane
therefore **reported it as blocked rather than guessing a verb** (change design §3), and the
primitive lands in a follow-up once the skill or a live measurement settles its shape.

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
by the lane**: it issues GET requests only, needs `NINOX_API_KEY`, and is run by the orchestrator on
the product owner's machine once `--allow-ninox-token` is approved (`dart test --run-skipped -t
live`).
