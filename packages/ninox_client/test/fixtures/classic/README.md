# Recorded classic-API responses

Every body in this directory is **sanitised**: synthetic team, database, table, field and record
names, synthetic values, and no credential of any kind. None of them was recorded against a live
workspace — see the status column below — and none carries a person's data, which is why the
contract tests can run in CI where no token exists (plan v0.2 §7.2).

## Provenance

| Fixture | Answers | Shape taken from | Status |
| --- | --- | --- | --- |
| `teams.json` | `GET /v1/teams` | `ninox` skill, `references/rest-api.md`: `200`, a list of `{id, name}` (VERIFIED) | shape from documentation — to be re-recorded live in §6 |
| `databases.json` | `GET /v1/teams/{team}/databases` | `ninox` skill, `references/rest-api.md`: `200`, a list of `{id, name}` (VERIFIED) | shape from documentation — to be re-recorded live in §6 |
| `tables.json` | `GET /v1/teams/{team}/databases/{db}/tables` | `ninox` skill, `references/rest-api.md` and `references/schema-and-fields.md`: `200`, a list of `{id, name, fields}`, each field `{id, name, type}` plus `choices` on a choice field and the relation keys on `ref`/`rev` (VERIFIED across 1,416 fields); `docs/Plan/SPIKE_GAP-022_schema_formula_fields.md` §2 A3 confirms the same key set | shape from documentation — to be re-recorded live in §6 |
| `record.json` | `GET .../records/{id}` | `ninox` skill, `references/rest-api.md`: `200`, `{id, fields}` (VERIFIED); the single-record endpoint is the one that may omit the audit keys | shape from documentation — to be re-recorded live in §6 |
| `records.json` | `GET .../tables/{table}/records` | `ninox` skill, `references/rest-api.md`: `200`, a **list** of `{id, fields, createdAt, createdBy, modifiedAt, modifiedBy, sequence}` (VERIFIED) | shape from documentation — to be re-recorded live in §6 |
| `create-response.json` | `POST .../records` | `ninox` skill, `references/rest-api.md` (`200`, the new record's identifier) and `scripts/ninox_client.py`, whose `create()` reads the identifier off an object keyed `id` | shape from documentation — to be re-recorded live in §6. Whether the identifier is a JSON string or a number is **not settled** by the trace; the adapter accepts both | 
| `files.json` | `GET .../records/{id}/files` | `corpus_test/REPORT.md` §3, read live on 2026-09-21: `200`, `name`, `size`, `contentType` | shape from a live read; the values here are synthetic |
| `error-404.json` | any 404 | `ninox` skill, `references/rest-api.md`: a small JSON object with a `message`, e.g. `{"message":"Team Not Found"}` (VERIFIED) | shape from documentation — to be re-recorded live in §6 |
| `error-500.json` | a create with a field Ninox will not accept | `ninox` skill, `references/errors-and-retries.md`: Ninox answers an invalid, formula or read-only field name with HTTP 500, not a 4xx | shape from documentation — to be re-recorded live in §6 |

## What this directory deliberately does not contain

* **No credential.** Not a token, not a fragment of one, not a header.
* **No identifier of the test environment.** The live check of GAP-023 names the test team, database
  and table as literals in its own source, and no fixture here repeats them.
* **No real business or personal data.** The field names are invented; the receipts behind them do
  not exist. `AGENTS.md` §1.4's forbidden variable is never consulted, in this directory or
  anywhere else in the package.

## Why the bodies are here rather than inline in the tests

A contract test that asserts a method, a path, a query, an `Authorization` header and a decoded
shape is only as good as the body it decodes. Keeping the bodies in files, one per endpoint, makes
the §6 re-recording a diff of this directory against the live test base — which is the review step
the change's design §8 names as the mitigation for a wrong fixture.
