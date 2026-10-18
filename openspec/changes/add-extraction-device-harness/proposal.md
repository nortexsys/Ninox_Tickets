# Change: add-extraction-device-harness

## Why

T2.1 dispatch C (task 3.2 of `implement-extraction-orchestration`): `ExtractionService` — router, country
detection, `extractDocument`, the history machine — has only been proven over fakes. This change adds the
device harness that runs it end to end on the Galaxy S22, as the OCR and PDF harnesses already do.

## What Changes

Implementation-only (`skip_specs: true`), Mobile lane, under `app/integration_test/` and `app/test/tool/`.
One Android integration test, run by the orchestrator and **never in CI**, that reads the documents in
`EXTRACTION_EVAL_DIR` (app private storage) through the real `ExtractionService` over a temporary
`FileHistoryStore`, and writes one **numbers-only** summary per document.

## Out of scope

* Any Ninox call (the harness never sends). Any value, supplier name or text from a document in an output.
* Thresholds or pass/fail on accuracy: accuracy needs ground truth (T2.5).
