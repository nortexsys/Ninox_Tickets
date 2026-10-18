# Design: update-extraction-service-expectations

In `app/test/features/extraction/extraction_service_test.dart` change the expected confidence of the
12100 EUR `gross_total` from `ConfidenceState.amber` to `ConfidenceState.green` in exactly the three
failing tests (document-states; multi-page-consolidation; universal-core "an Undetected document is not a
failure"). Change nothing else. Do not edit production code. Confirm with `flutter test` in `app/`
(all green), `dart format`, `flutter analyze --fatal-infos`.
