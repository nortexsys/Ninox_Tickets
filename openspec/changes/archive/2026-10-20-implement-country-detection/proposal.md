# Proposal: implement-country-detection

Requirements: `FR-CTR-001` (`countries-languages` · `deterministic-country-detection`), `FR-CTR-002`
(`universal-core`), `FR-CTR-005` (`format-inference`). Written by the orchestrator, 2026-10-13.

## Why

`extractDocument` (T2.1 part A) and `ExtractionService` (part B) need the country row that governs a
document, and nothing chooses it. The spec has already decided *who* chooses: the **document's own
evidence** (the issuer's tax identifier, currency, address, language). There is no user-facing
country setting, and neither the destination nor the device locale takes part. What is missing is
the code that reads that evidence. Without it the extraction step cannot be assembled on a device,
and T2.2 (review screen) has no document to show.

## What changes

* A pure function in `paperdrop_core` that takes a document's `TextPage`s and the `CountryTable`
  and answers with the row that applies, or says why it cannot.
* `ExtractionService` stops taking a fixed `country` and asks that function (Mobile lane,
  after the Core part is merged).

## Out of scope

* New country rows (AT, CH are R1); new check-digit algorithms (GAP-030 stays as the PO left it).
* A user-facing country setting: forbidden by the requirement.
* Reading the supplier's name or address as *fields*; this only uses them as evidence of country.
* Any accuracy threshold (GAP-003).

## Impact

`packages/paperdrop_core` (new `src/countries/detect_country.dart`, export, tests); then
`app/lib/features/extraction/extraction_service.dart`. No Ninox, no private corpus.
