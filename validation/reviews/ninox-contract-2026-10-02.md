# Ninox contract tests against ADR-004 — review

Change: `implement-ninox-client`, task 3.1. QA does not edit `lib/`; this document reports what
`packages/ninox_client/test/` can and cannot prove, and adds two tests for rules that are provable
at this layer and were not proved by name. No `live`-tagged test was run, `PAPERDROP_LIVE_NINOX` was
never set, and `NINOX_API_KEY` was never read.

**Sources read:** ADR-004 (`docs/Fase 1. Discover/Paperdrop_ADR_v0.2_EN.md`), the `ninox` skill
(`agents/skills/ninox/`), `openspec/changes/implement-ninox-client/design.md`, and every file under
`packages/ninox_client/test/`.

**What this layer is.** Contract tests against `MockClient` and recorded, documentation-shaped
fixtures (`test/fixtures/classic/README.md`: every fixture is marked "shape from documentation — to
be re-recorded live in §6"). A test here proves what the adapter *builds* and how it *classifies* a
response; it cannot prove what Ninox itself does with a request, because nothing here ever reaches
Ninox. Where ADR-004 states a measured fact about the live API, that fact was established once by a
real trace and the 16-document test (ADR-004's own text) — reproducing it is T1.9's, not this
layer's.

## ADR-004's table, rule by rule

| # | Rule (ADR-004) | Provable here? | Proof | Notes |
| --- | --- | --- | --- | --- |
| 1 | Payload shape — records written as a nested object under a `fields` key | Yes | `classic_adapter_test.dart`: *"createRecord: POST .../records, body nested under fields, JSON"*; *"updateRecord: PUT .../records/{id}, body with only the fields given"* | Both writes assert the exact body string |
| 2 | Create response — HTTP 200 with the new record's identifier, which the attachment call and the deep link both need | Partly | `classic_adapter_test.dart`: *"createRecord: POST .../records, body nested under fields, JSON"* (the id is parsed and returned); `model_test.dart`: *"the create response gives the new record identifier"*; `failure_mapping_test.dart`: *"a create that answers 200 without an identifier is an UnexpectedResponse"*. **Added in this review:** *"the identifier a create returns is what a following attachment and read-back are built on"* | The parsing half and the "an id-less 200 is an error" half were already proved. That the id *works as input* to a following call was not proved by name until the test added here. What stays out of reach: the staged **sequencing** of create → attach → read-back and the deep link itself are T1.11's/T1.8's own scope note (`design §3`: "the deep link... needs no API call and costs this change nothing") |
| 3 | Updates are merges — fields not sent are preserved | Yes (the primitive) | `classic_adapter_test.dart`: *"updateRecord: PUT .../records/{id}, body with only the fields given"* (asserts the body omits a field the caller did not send); *"an update with an empty mapping also sends no field keys"* | The **consequences** named in the rule — "a correction sends only what changed", "a failed attachment can be retried without touching the record" — are the correction flow's (R1) and the send pipeline's (T1.11); the test comments already say so |
| 4 | Choice fields — accept either the option identifier or the option text; reads always return the text; text matching no option is unverified | Partly | **Added in this review:** *"a field value crosses the boundary unchanged, whether it looks like a choice option's identifier or its text"* | This proves the adapter imposes **no shape** on a field's value — it serialises whatever is given, id-shaped or text-shaped, unchanged. It does **not** prove Ninox accepts both (that needs a live write), and it does not touch "reads always return the text" (nothing here discriminates a choice field from any other on read; `NinoxField`'s `choices` key is explicitly unmodelled — `model_test.dart`: *"NinoxTable reads the second table, with a rev field"* and the `D` field assertion both note this). "Text matching no option" stays ADR-004's own **still open** item and the skill's `known-unknowns.md` — T1.9's |
| 5 | Dates — a `YYYY-MM-DD` string is stored verbatim | Partly | `classic_adapter_test.dart`: *"a date and an amount cross the boundary untransformed"* | Proves the client's half: the literal string is sent unre-encoded (`isNot(contains('1999.0'))` etc. for the amount alongside it). That Ninox **stores** it verbatim is a live fact this layer cannot observe |
| 6 | Names versus identifiers — payloads keyed by name; the schema carries the stable identifier; a destination resolves the current name from a cached schema at send time | Partly | Payload-by-name half: every write test (`createRecord`/`updateRecord`) keys the body by the literal name given. Both-keys-surfaced half: `model_test.dart`: *"NinoxTable, with every field of the one tables call"* (`NinoxField(id: 'A', name: 'Issued on', type: 'date')`) | The **resolution** — a destination storing the id and looking up the current name at send time, refreshed when the app opens — is `destinations-mapping`'s, the wizard's (T1.10); nothing in this package resolves an id to a name, by design (the port only hands back what the endpoint returned) |
| 7 | Formula and read-only fields — excluded from mapping candidates; writing one returns HTTP 500; a formula total is a post-write check only | Partly | No-second-schema-call half: `classic_adapter_test.dart`: *"GET .../tables, and the fields come back with the tables, and .../tables/{table}/fields does not exist (ADR-004)"* (asserts `hasLength(1)`, i.e. no `.../schema` call); *"are the eight calls of the port..."* (asserts `isNot(contains('/schema'))` for every call the adapter can make). The-500 half: `failure_mapping_test.dart`: *"a 500 is a server error and is not retried, refreshed or reinterpreted here"* | "Excluded from the mapping candidates the wizard proposes" and "used as a post-write contrast" are the wizard's and the destinations-mapping parser's (T1.10/R1); this package reads `.../tables` (which simply omits formula fields) and adds no filtering of its own, which is what is proved — not that a *real* formula field 500s, since the 500 fixture is synthetic (`error-500.json`, message "Unknown field: Amount paid") |
| 8 | Error shape — an invalid or read-only field name returns HTTP 500, not a 4xx | Partly | `failure_mapping_test.dart`: *"a 500 is a server error and is not retried, refreshed or reinterpreted here"*; *"a 500 on an update is a ServerError as well, and is not retried here"*; the whole status matrix of *"every status of the matrix that this layer can see maps to its condition"* | Proves the adapter never reinterprets a 500 as anything else and never treats it as success. That *this specific status* is how Ninox reports a bad field name (rather than a real outage) is ADR-004's own measured claim, not reproducible without a live call |
| 9 | Retry policy — never retried blindly; a 500 refreshes the schema once and retries once, a second failure is a mapping error; a lost create is never blind-retried (ADR-013) | Partly | Never-retried-here half: every failure test in `failure_mapping_test.dart` asserts `seen, hasLength(1)` (e.g. *"a 500 is a server error and is not retried, refreshed or reinterpreted here"*, *"a timeout on create is CreateOutcomeUncertain, and nothing is retried"*). The comments are explicit: *"the client never retries; the pipeline retries once"* | "Refresh the schema once and retry once" and "report a mapping error" are the send pipeline's own state machine (T1.11); this package deliberately stops at classification, which is what every test above proves by counting requests |
| 10 | Read after create — the record is always read back, because formulas/defaults silently override submitted values and the create response does not reveal it | No | — | This is a **caller discipline**, not a structural property of the port: `createRecord` does not invoke a read, and nothing in this package forces one. The design itself puts the staged sequencing in T1.11 (`design §3`: *"a create is one call; the attachment and the read-back are separate primitives (T1.11 composes them into a send)"*). What this layer proves instead is that `readRecord` correctly parses a record when called (`classic_adapter_test.dart`: *"GET .../records/{id}, and the record is parsed"*) — necessary for the rule, not sufficient to prove it |
| 11 | Attachment upload — one multipart POST, HTTP 200; the files endpoint returns name, size, content type; verified live with a disposable record and 16 real uploads | Partly | `classic_adapter_test.dart`: *"uploadFile: one multipart POST to the record files endpoint, bytes unchanged"* (method, path, boundary, bytes verbatim — compared byte-for-byte against the `MockClient`'s received body); *"the upload answers 200 and nothing else is read from it"*; *"GET .../records/{id}/files, with name, size and content type"* | The mechanics (one call, the right path, the bytes untouched, the three read-back keys parsed) are fully proved against the fixture. The **live verification** ADR-004 cites (a disposable record, then 16 real uploads, all HTTP 200) is a fact about a past, separate measurement; this layer's fixture (`files.json`) is itself sourced from that live read (`test/fixtures/classic/README.md`: *"shape from a live read; the values here are synthetic"*), which is as close to it as a `MockClient` test can get |

## Findings for the Ninox lane

1. **Two rules were provable here and not proved by name; both are now covered.** Added to
   `packages/ninox_client/test/classic_adapter_test.dart`, group *"the writes, against a MockClient
   only"*:
   * *"a field value crosses the boundary unchanged, whether it looks like a choice option's
     identifier or its text"* (rule 4, the shape half).
   * *"the identifier a create returns is what a following attachment and read-back are built on"*
     (rule 2, the "what the attachment call... needs" half).

   Both pass. Neither needed a change to `lib/`: the adapter already imposes no shape on a field's
   value and already builds every path from its `RecordId` argument: the gap was in the test suite's
   coverage, not in the adapter.

2. **No test added failed.** There was no finding of the kind the task anticipates reporting as a
   `skip: 'QA finding: …'`.

3. **Rule 10 ("read after create") cannot be proved at this layer, structurally, and that is by
   design.** `createRecord` and `readRecord` are independent primitives; the rule that a caller
   *always* chains them is the send pipeline's. A reviewer looking for this proof in
   `packages/ninox_client/test/` will not find it there, and should not expect to: it belongs in
   `implement-send-pipeline`'s (T1.11) test suite instead.

4. **Rule 6's resolution half and rule 7's "excluded from mapping candidates" half belong to the
   wizard (T1.10) for the same structural reason** — the port hands back what the endpoint returned
   (both a field's id and its name; a table's fields with formula fields simply absent) and leaves
   the *use* of that data to the caller that has to make a mapping decision.

5. **The `updateRecord` primitive itself still carries documentation-shaped provenance, not this
   layer's to close.** Its dartdoc and the package `README.md` already say so (*"verb and path from
   vendor documentation; to be confirmed live in T1.9"*); the contract tests prove the shape this
   package commits to, not that Ninox honours it.

## Checks run

* `dart test` (from `packages/ninox_client/`): 153 tests, 1 skipped (`live`, excluded by
  `dart_test.yaml`), 0 failed.
* `dart analyze --fatal-infos` (from `packages/ninox_client/`): no issues.
* `dart format --set-exit-if-changed .` (from `packages/ninox_client/`): clean after formatting the
  edited file.
* No `live`-tagged test was run; `PAPERDROP_LIVE_NINOX` was not set; `NINOX_API_KEY` was not read.
