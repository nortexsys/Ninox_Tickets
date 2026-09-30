# Design: implement-ninox-client

Owner: Ninox lane. Written by the orchestrator on 2026-09-30. §1–§5 (T1.8) are detailed for dispatch
now and need **no token**; §6 (T1.9, live tests) is detailed before its own dispatch, which needs the
product owner's approval of `--allow-ninox-token`.

## 1. Rules that bind every file of this change

* `packages/ninox_client/lib/` depends on `paperdrop_core`, `package:http` and the Dart SDK only. No
  new dependency without the orchestrator. No `dart:io` in `lib/`: the adapter talks through an
  injected `http.Client`, so tests use `package:http/testing.dart`'s `MockClient` and no test in CI
  reaches the network.
* **No environment variable is read anywhere in `lib/`** — not the token, not a team, not a database,
  not a host (`AGENTS.md` §1.3–§1.4). Team and database are arguments of every call. The
  production-database variable of `AGENTS.md` §1.4 is never named in this package (the
  `no-ninox-db-id` CI job enforces it).
* **The token never leaves the `Authorization` header.** It is not in any `toString`, exception
  message, log line or test failure output. A test proves it: every error the adapter can raise, and
  the credentials object itself, is stringified and searched for the token.
* No write reaches Ninox in this change's tests. Write methods are implemented and tested against
  `MockClient` only; live writes are §6, under the product owner's approval (`AGENTS.md` §1.5).
* Everything immutable, value equality, dartdoc on every public member citing the requirement or ADR
  it serves. Tests tagged per plan §11.1; a partial proof is untagged and names the scenario in a
  comment.

## 2. Host and credentials (FR-DST-008, ADR-017)

```
lib/src/endpoint.dart      NinoxEndpoint
lib/src/credentials.dart   NinoxCredentials
```

**`NinoxEndpoint`** — `NinoxEndpoint.parse(String host)` accepts a bare host (`api.ninox.com`,
`ninox.example.de`), a host with a port, or an `https://` URL whose path is empty or `/`; it
normalises to lower case and yields `Uri baseUri` = `https://<host>/v1`. It **rejects** (`null` or a
typed error — pick one and document it) an `http://` URL (the token would travel in clear), any path
beyond `/`, a query, a fragment, user info, whitespace, and an empty string. `NinoxEndpoint.cloud`
is the default, `api.ninox.com`, and is the only place that host string exists in `lib/`: nothing
else may build a Ninox URL from a literal host (*a private-cloud customer needs no fork*). That the
private-cloud API sits under the same `/v1` path is the vendor's documented layout and is not yet
verified on a private host — recorded here as a risk (§8), not as a gap.

**`NinoxCredentials`** — wraps the personal access token; `toString()` prints `NinoxCredentials(***)`.
The header is `Authorization: Bearer <token>`. Where the token comes from (keystore, paste) is the
wizard's and the app's (FR-CFG-004, T1.10); this package only receives it.

## 3. The port (ADR-003, ADR-004)

```
lib/src/port.dart          NinoxPort (abstract interface), TableRef
lib/src/model.dart         NinoxTeam, NinoxDatabase, NinoxTable, NinoxField, NinoxRecord, NinoxFile, RecordId
lib/src/errors.dart        NinoxFailure (sealed)
```

`TableRef(teamId, databaseId, tableId)` — all three explicit, never defaulted. The port:

| Method | Classic call | Notes |
| --- | --- | --- |
| `listTeams()` | `GET /teams` | id, name |
| `listDatabases(teamId)` | `GET /teams/{t}/databases` | id, name |
| `listTables(teamId, databaseId)` | `GET /teams/{t}/databases/{d}/tables` | tables **with their fields** in one call; formula fields are absent from this endpoint (DEC-005, plan §6.1) — the adapter adds no filtering of its own and no call to `.../schema` |
| `createRecord(TableRef, Map<String, Object?> fieldsByName)` | `POST .../tables/{tb}/records` | body `{"fields": {...}}` (ADR-004 payload shape); returns the new `RecordId`. An empty map sends `{"fields": {}}` — see *no mapping means no field keys* |
| `updateRecord(TableRef, RecordId, Map<String, Object?> fieldsByName)` | `PUT .../records/{id}` | a **merge**: only the fields given are sent, fields not sent are preserved (ADR-004 *updates are merges*; FR-SND-008's primitive). The exact verb and body are taken from the `ninox` skill's reference; if the skill does not settle them, the lane reports it as blocked rather than guessing |
| `readRecord(TableRef, RecordId)` | `GET .../records/{id}` | fields as returned, plus `createdAt`/`createdBy` when present |
| `uploadFile(TableRef, RecordId, {filename, bytes, contentType})` | `POST .../records/{id}/files` | `multipart/form-data`; the bytes are sent as given, never re-encoded (BR-17 is the caller's, but the adapter must not transform them) |
| `listFiles(TableRef, RecordId)` | `GET .../records/{id}/files` | name, size, content type |
| `listRecords(TableRef, {page, perPage, order, desc})` | `GET .../records?...` | `perPage`/`page` verified (plan §6.2); `order`/`desc` are **passed through untested** until the read-only check of §5 (GAP-023) |

Field payloads are keyed by **field name** (ADR-004: payloads by name, schema by id); resolving the
current name from a stored id is the send pipeline's (T1.11), not the adapter's.

The proposal lists FR-SND-001 (`create-attach-read-back`): this change provides the three calls as
separate primitives; composing them into one send, in order, with its failure handling, is the send
pipeline's (T1.11), because the retry matrix acts between the steps.

Out of this change: the retry policy (on a 500,
refresh schema once and retry once — T1.11), reconciliation (ADR-013 — T1.11), deep links (ADR-008).

## 4. Failures — typed, never a bare exception

`sealed class NinoxFailure` with: `Unauthorized` (401/403), `NotFound` (404), `ServerError` (5xx,
with status; ADR-004: a 500 is how Ninox reports an invalid or read-only field name, so the adapter
does **not** interpret it — the pipeline does), `RateLimited` (429, if seen), `UnexpectedResponse`
(2xx with a body that does not parse, or any other status), `TransportFailure` (no response: DNS,
connection, TLS, timeout).

**`createRecord` distinguishes an uncertain outcome.** A timeout or a connection lost *after the
request was sent* surfaces as `CreateOutcomeUncertain` (a `TransportFailure` subtype), because
Ninox may have created the record (ADR-013). The adapter never retries anything itself, and never a
create. A failure before the request left (DNS, refused connection) is a plain `TransportFailure`.
Where `package:http` cannot tell the two apart, the adapter must say `CreateOutcomeUncertain`
(the safe side) and the dartdoc says so.

Timeouts are a constructor parameter of the adapter (default 30 s, per request); the send pipeline
may choose another.

The methods return `Future<T>` and throw only `NinoxFailure` subtypes (documented per method); no
`http.ClientException`, `FormatException` or `TimeoutException` escapes.

## 5. Contract tests on recorded responses, and the GAP-023 check

```
lib/src/classic_adapter.dart          ClassicNinoxAdapter implements NinoxPort
test/fixtures/classic/*.json          sanitised response bodies
test/fixtures/classic/README.md       provenance of each fixture
test/classic_adapter_test.dart        contract tests (MockClient)
test/live/order_desc_check_test.dart  GAP-023, tagged `live`, skipped unless run explicitly
```

**Fixtures.** No live call is made in this dispatch. The fixtures are written from the vendored
`ninox` skill's reference shapes and from `docs/Plan/SPIKE_GAP-022_schema_formula_fields.md`, and
`README.md` names the source of each one and marks it **"shape from documentation — to be re-recorded
live in §6"**. They contain no personal data and no real business data: synthetic table and field
names, synthetic values. The test environment's team and database ids of `AGENTS.md` §1.4 may appear
(they are already public); no other id may.

**Contract tests** prove, per method: method and path built on the configured endpoint (a test with a
private host proves no request goes to `api.ninox.com`); the `Authorization` header; the create body
nested under `fields`; an empty mapping sends no field keys (tag
`[destinations-mapping/never-write-an-unmapped-field] no mapping means no field keys` — the payload
half only: untagged if the scenario's "record carries only the attachment" is not proved here);
multipart upload with the bytes unchanged (compare the bytes received by the `MockClient`); each
status code to its `NinoxFailure`; a timeout on create to `CreateOutcomeUncertain`; the token absent
from every failure's string.

**The GAP-023 read-only check** (`order`/`desc`) is written now and **not run**: a test tagged `live`
(`dart_test.yaml` excludes `live` by default) that lists the records of one table of the **test
environment** (team `qCq3JS7q7ptoap8Yg`, database `jd1m8n8l4j7i`, both as literals in the test, never
from the environment) with `order` on a date or number field, both `desc: true` and `false`, and
asserts the returned order. It reads the token from `NINOX_API_KEY` and, if the variable is absent,
the test is skipped with a message — it never fails CI. It performs **GET only**. It is run by the
orchestrator on the product owner's machine after the product owner approves it (§6).

## 6. T1.9 — live tests (next dispatch, needs the product owner)

To be detailed before dispatch: re-record every fixture against the test base (GET only), run the
GAP-023 check, then the write tests within D-10's bounds (plan §6.4) and the attachment size and
timing measurements from Spain (GAP-004). Needs `--allow-ninox-token`, approved by the product owner
for that run.

## 7. What this change does not do

No wizard (T1.10), no send pipeline, retry matrix or reconciliation (T1.11), no keystore, no Flutter.

## 8. Risks

* **The fixtures are documentation-shaped until §6.** A contract test green on a wrong fixture proves
  nothing about Ninox. Mitigation: §6 re-records them and a diff against these is part of its review.
* **Private-cloud path layout** assumed identical (`/v1`), unverified.
* **Uncertain-create detection** depends on what `package:http` exposes; erring to "uncertain" costs
  one reconciliation read, erring the other way costs a duplicate record.
