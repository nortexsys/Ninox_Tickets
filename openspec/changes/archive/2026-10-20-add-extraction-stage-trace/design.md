# Design: add-extraction-stage-trace

## 1. Shape

`enum ExtractionStage` (closed list) and `abstract interface class ExtractionTrace { void record(String field, ExtractionStage stage); }` plus a collecting implementation `CollectingTrace` exposing `Map<String, List<ExtractionStage>>`. `extractDocument({..., ExtractionTrace? trace})`.
The field is the canonical field name (`gross_total`, `net_total`, `tax_total`, `supplier_name`, `doc_number`, `doc_date`, `currency`). **No value, text, word, coordinate or amount is ever passed to `record`**; a test greps the trace source to keep it so and a second test checks the collecting output holds only enum names.

## 2. Stages to record (one per place a candidate or a field is lost or lowered)

Name them from the code as it is; at least: no label of the kind found on the page; label found but no value bound to it; value bound but not parsed as an amount (format); candidate rejected by negative context; candidate kept but no arithmetic identity found; identity found but the legal-rate gate failed; value read in only some passes (no majority); value kept but confidence capped (single reading, unverified country, repair). Add finer stages where the code has them. Also record, once per document, whether the country was detected (`countryDetected` / `countryUndetected`) and which pass count was used.

## 3. Rules

Default null path executes no extra work and the existing 271 tests pass unchanged. New tests: a document where each stage fires (synthetic invoices 01/02 fixtures in `test/regressions/fixtures/`, plus small hand-made pages for the stages they do not cover), and the two privacy tests of §1.

## 4. Checks

`dart format`, `dart analyze --fatal-infos`, `dart test` in `packages/paperdrop_core`; `privacy_check.py`, `core_purity.py` 0 findings.
