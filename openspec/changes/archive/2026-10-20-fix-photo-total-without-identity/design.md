# Design: fix-photo-total-without-identity

## 1. Method

Use `CollectingTrace` (merged) on **synthetic** pages built from the masked shapes above: a single
`TOTAL 12,50 EUR` line with no breakdown; the same with `TOTAL: 12,50`; `BASE`/`IVA 10%`/`TOTAL` lines;
tendered/change lines that must be suppressed; one pass vs four passes where one pass misreads a digit;
dates `28/09/2026` (day > 12), `05/06/2026` (ambiguous) with `country: null`. Each case is a failing test
first, naming the stage; fix at that stage. Use the app's real labels: `ExtractionPass(passId: 'p1-native',
routeLabel: 'photo-ocr/google_mlkit_text_recognition 0.17.1')`, and run each case both with `country: null`
and with `CountryTable.es`.

## 2. Rules

Tolerant reading, same trust: a total with no identity is `read` + amber, never green; a derived value
never confirms (PRE-008, BR-05); suppression of change/tendered/tip stays. Read the existing tests that
encode "absent when no identity" and report any that contradict the spec instead of editing them silently.

## 3. Checks

`dart format`, `dart analyze --fatal-infos`, `dart test` in `packages/paperdrop_core` (296 on `main` is not
the number: `main` has 287), `privacy_check.py`, `core_purity.py`. The orchestrator then re-measures the 19
photographs (counts only) and compares with main (gross 1 of 19, date 4 of 19 with four passes).
