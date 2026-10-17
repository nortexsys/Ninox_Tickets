# Design: verify-live-send-pipeline

## 1. Scope and bounds (same contract as `write_limits_test.dart`, approved 2026-10-08)

* Team `qCq3JS7q7ptoap8Yg`, database `jd1m8n8l4j7i`, table `EF` are **literals** in the test, never
  read from the environment. The test resolves them with GET requests before the first write and
  refuses to run if any fails to resolve. `NINOX_DB_ID` is never used (`AGENTS.md` §1.4).
* Opt-in guard identical to the existing live tests: `PAPERDROP_LIVE_NINOX=1` **and** a token in
  `NINOX_API_KEY`, checked in each test's `skip:` and again in its body. Token never printed.
* Caps enforced before each call: **at most 3 records created**, one attachment of **at most 1 MiB**.
* Records that existed before the run are recorded by id and never touched. The run deletes only
  ids it created, in a `finally` and again in `tearDownAll`; at the end it lists the table and
  reports any pre-existing id missing and any own id still present.
* Invented values and a PDF built in-process (`syntheticPdf` from `t19_support.dart`). No corpus
  file, no real document, no value that identifies a person.

## 2. What it runs

1. Resolve the schema of `EF`; build `fieldsByName` **only** from fields that exist, by current
   name, amounts as minor-unit integers, dates `YYYY-MM-DD` (ADR-004). Formula fields are skipped
   (`fn` marker, SPIKE_GAP-022).
2. `SendPipeline.send` → expect `Sent`; the read-back carries the record id, the file name, size and
   content type, and the written field values match what was sent.
3. A second send of an identical request with a different `docId` is **not** run: duplicate
   handling is T2.3.
4. Cleanup (§1). Results go to `test/live/out/send_pipeline_results.json` (ignored by git) and
   stdout: counts, statuses and timings only, no field values.

## 3. Fixture re-recording

`create-response` and `error-500` are re-recorded from the real responses, **structure only**:
keys and types kept, every value replaced by a synthetic one, then the existing fixture tests run.
`error-500` is only recorded if the run meets a real 500; it is not provoked.

## 4. Checks

`dart analyze`, `dart format`, `dart test` of the package with the live tests skipped (green), `privacy_check` and `core_purity` at
0 findings. The live run itself is executed by the orchestrator on the PO's machine, not by the
lane (the lane has no token).
