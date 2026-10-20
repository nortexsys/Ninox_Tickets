# Design: add-extraction-device-harness

`app/integration_test/extraction_eval_test.dart`, modelled on `ocr_eval_test.dart` and
`pdf_text_eval_test.dart` (skips without `EXTRACTION_EVAL_DIR`; same `ocr_eval_json`-style writer helpers).
For each file: copy into a temp store through `DocumentIntake`, run `ExtractionService.extract`, record.

Summary per document (`<doc_id>.extraction-summary.json`), **no text, no values**:
`route`, `recognitionEngine` (engine names only), entry state after, document SHA-256 before/after
and equal-flag, elapsed ms, `needsReview`, per canonical core field only the **confidence state and
provenance tag** (`green|amber|red|absent|edited`, tag name), country-detection kind
(`row`/`undetected` + reason kind), and, if refused, the `ExtractionFailureCode`.
A pure helper `extraction_eval_json.dart` builds the JSON and has a host unit test that proves no
string field can carry a document value (allow-list of keys and enum values).
`flutter analyze --fatal-infos`, `dart format`, `flutter test` (host) green; the device run is the
orchestrator's, with `--timeout 20m --no-uninstall`. No Ninox call, no token.
