# Change: update-extraction-service-expectations

`fix-text-pdf-extraction-yield` made Core read a text-layer total whose arithmetic identity is printed
(DEC-018): total 12100 EUR is now `read, green` where the app tests expected `read, amber` (the text-layer
flag never turned on in production, so the old expectation encoded the bug). Three tests in
`app/test/features/extraction/extraction_service_test.dart` carry that expectation. Implementation-only
(`skip_specs: true`), QA lane, tests only.
