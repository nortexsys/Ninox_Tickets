# Tasks: implement-core-model-and-countries

Plan v0.2 M1, Core lane. A task is done when its check passes, not when its files exist. Every check
is run from the repository root on Flutter 3.47.5 / Dart 3.13.4:
`dart analyze --fatal-infos packages/paperdrop_core`, `dart format --set-exit-if-changed packages/paperdrop_core`,
`dart test packages/paperdrop_core`, `python .github/scripts/core_purity.py`.

## 1. Core — first dispatch: the shared contract (T1.1–T1.2)

- [ ] 1.1 **`CurrencyCode` and the ISO 4217 table** (design §2). *Done when* the vectors of design
      §2 pass, an unknown code returns `null`, and no code path yields a default exponent.
- [ ] 1.2 **`Money`** (design §2): exact parse of the canonical decimal form, arithmetic, currency
      mismatch error, range bound, canonical `toDecimalString`. *Done when* the examples of design §2
      pass, including every rejection.
- [ ] 1.3 **`RateBp` and the exact product** (design §2). *Done when* `21`, `5.5`, `2.75` parse to
      2100, 550, 275, `5.555` and `100.01` are rejected, and `timesRate` compares exactly with no
      rounding function in the public API.
- [ ] 1.4 **Canonical model** (design §3): `Provenance`, `ValueSource`, `ConfidenceState`,
      `FieldValue` (`Present`, `Absent`, `NotInXml`), `CalendarDate`, `CanonicalDocument` with
      `TaxSlot` and `Surcharge`, JSON round-trip. The three fields deferred to R1 (design §3, GAP-027) are **not** present.
      *Done when*:
      * a test named `[extraction-pipeline/provenance-on-every-value] every value is tagged` builds a
        fully populated document and proves every `Present` value carries one of the four tags;
      * `Absent`, `NotInXml` and `Present(0)` are three unequal values, and none converts to another;
      * `cardMasked` refuses five or more digits;
      * a document with `currency: EUR` and a USD amount cannot be constructed;
      * the JSON round-trip of a fully populated document is lossless and every amount is a JSON
        integer.
- [ ] 1.5 **No float in `lib/`** (design §1): a test scans `packages/paperdrop_core/lib/` and fails on
      `double`, `num `, `toDouble` or `double.parse`. *Done when* it passes, and fails on a planted
      `double` (proved inside the test with a temporary file under the system temp directory, not
      under `lib/`).
- [ ] 1.6 **Public API** exported from `lib/paperdrop_core.dart`, dartdoc on every public member.
      *Done when* the four checks at the top of this file are green, and the lane report lists the
      public API (type names and constructors) for the orchestrator's review.

- [ ] 1.7 **The `Edited` case** (design §3, PO decision 2026-09-28), replacing `copyWithEdit` and the
      `user` source and `edited` flag on `Present`. *Done when* `FieldValue.edit` turns each of
      `Present`, `Absent` and `NotInXml` into an `Edited` holding only the value; `Present` refuses
      `source: user`; an `Edited` has no provenance and no confidence and its JSON has neither key;
      and the round-trip test covers it.

- [ ] 1.8 **Remove `docType`** from `CanonicalDocument`, its JSON and its tests (design §3, GAP-029,
      PO decision 2026-09-28). *Done when* no `docType` / `doc_type` remains in
      `packages/paperdrop_core/` and the checks at the top of this file are green.

## 2. Core — second dispatch (T1.3–T1.4)

Detailed in design §4–§5 before dispatch, after the product owner has reviewed §1's public API.

- [ ] 2.1 T1.3 — country table ES + DE; check digits EAN-13, IBAN, `ES_NIF`, `ES_NIE`, `ES_CIF`,
      `DE_USTID` with standard vectors.
- [ ] 2.2 T1.4 — format inference; label and negative-context dictionaries EN/DE/ES.

## 3. QA

- [ ] 3.1 Review the ISO 4217 table against the published list (design §7) and report any
      difference as a finding; QA does not edit `lib/`.

## 4. Orchestrator

- [ ] 4.1 Review the lane's report and diff; run the checks at the top of this file and
      `python .github/scripts/scenario_coverage.py`; present the public API of §1 to the product
      owner before Ninox and Mobile are dispatched against it.
- [ ] 4.2 Merge `change/implement-core-model-and-countries` with `--no-ff` after the product owner
      approves; archive the change when §1–§3 are done.
