# Recorded classic-API responses

Every body in this directory is **sanitised**: synthetic team, database, table, field and record
names, synthetic values, and no credential of any kind. **No live value, identifier, name or
timestamp was copied into any of them.** What was compared against the live test workspace on
2026-10-08 was the **structure** — the keys each endpoint returns and their types — and the status
column says which fixture that covers. None of them carries a person's data, which is why the
contract tests can run in CI where no token exists (plan v0.2 §7.2).

## Provenance

| Fixture | Answers | Shape taken from | Status |
| --- | --- | --- | --- |
| `teams.json` | `GET /v1/teams` | `ninox` skill, `references/rest-api.md`: `200`, a list of `{id, name}` (VERIFIED) | shape confirmed live 2026-10-08 (structure only) |
| `databases.json` | `GET /v1/teams/{team}/databases` | `ninox` skill, `references/rest-api.md`: `200`, a list of `{id, name}` (VERIFIED) | shape confirmed live 2026-10-08 (structure only) |
| `tables.json` | `GET /v1/teams/{team}/databases/{db}/tables` | `ninox` skill, `references/rest-api.md` and `references/schema-and-fields.md`: `200`, a list of `{id, name, fields}`, each field `{id, name, type}` plus `choices` on a choice field and the relation keys on `ref`/`rev` (VERIFIED across 1,416 fields); `docs/Plan/SPIKE_GAP-022_schema_formula_fields.md` §2 A3 confirms the same key set | shape confirmed live 2026-10-08 (structure only) |
| `record.json` | `GET .../records/{id}` | `ninox` skill, `references/rest-api.md`: `200`, `{id, fields}`; the live comparison added the audit keys the listing endpoint is documented with | single-record endpoint returns the audit keys on the test tenant; the parser still tolerates their absence. Structure confirmed live 2026-10-08 |
| `records.json` | `GET .../tables/{table}/records` | `ninox` skill, `references/rest-api.md`: `200`, a **list** of `{id, fields, createdAt, createdBy, modifiedAt, modifiedBy, sequence}` (VERIFIED) | shape confirmed live 2026-10-08 (structure only) |
| `create-response.json` | `POST .../records` | `ninox` skill, `references/rest-api.md` (`200`, the new record's identifier) and `scripts/ninox_client.py`, whose `create()` reads the identifier off an object keyed `id` | exercised by T1.9 live writes (the create returned an identifier the port parsed); not re-recorded, because re-recording it needs a write. Whether the identifier is a JSON string or a number stays **unsettled**, and the adapter accepts both |
| `files.json` | `GET .../records/{id}/files` | `corpus_test/REPORT.md` §3, read live on 2026-09-21: `200`, `name`, `size`, `contentType` | shape proved by T1.9's live read-back (name, size and content type matched an uploaded attachment); the 2026-10-08 listing was empty, so there was nothing to re-record |
| `error-404.json` | any 404 | `ninox` skill, `references/rest-api.md`: a small JSON object with a `message`, e.g. `{"message":"Team Not Found"}` (VERIFIED) | shape confirmed live 2026-10-08 (structure only) |
| `error-500.json` | a create with a field Ninox will not accept | `ninox` skill, `references/errors-and-retries.md`: Ninox answers an invalid, formula or read-only field name with HTTP 500, not a 4xx | not re-recorded: provoking one needs a write, and T1.9's writes did not meet one |

"Structure only" means exactly that: keys and types were compared with the live response and agree;
every value in the fixture is invented here, and no live value was copied.

## What this directory deliberately does not contain

* **No credential.** Not a token, not a fragment of one, not a header.
* **No identifier of the test environment.** The live tests name the test team, database and table
  as literals in their own source; no fixture here repeats them, and neither does this file — not in
  a table cell, not in an example, not in a comment.
* **No live value of any kind.** The field names, dates, amounts, identifiers and timestamps in these
  bodies are invented. The 2026-10-08 comparison was of structure, and the response bodies
  themselves were never copied here.
* **No real business or personal data.** The field names are invented; the receipts behind them do
  not exist. `AGENTS.md` §1.4's forbidden variable is never consulted, in this directory or
  anywhere else in the package.

## Why the bodies are here rather than inline in the tests

A contract test that asserts a method, a path, a query, an `Authorization` header and a decoded
shape is only as good as the body it decodes. Keeping the bodies in files, one per endpoint, is what
made the 2026-10-08 comparison a diff of this directory against the live workspace — and it is what
makes the next one the same, which is the review step the change's design §8 names as the mitigation
for a wrong fixture.
